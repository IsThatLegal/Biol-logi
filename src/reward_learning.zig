const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 30;
    pub const HEIGHT: usize = 15;
    pub const TICK_LIMIT: usize = 400;
};

/// The Reward-Based Learning Protein.
/// Uses a "Digital Dopamine" wave to lock in successful paths.
pub const RewardProtein = packed struct {
    id: u32,
    excitation: u8,
    
    // Synaptic Weights
    w_north: u8,
    w_south: u8,
    w_east: u8,
    w_west: u8,

    // Eligibility Trace: Did this node fire recently?
    // In biology, this is the "tagging" of active synapses.
    eligibility_trace: u8,

    padding: u176,

    comptime {
        if (@bitSizeOf(RewardProtein) != 256) {
            @compileError("RewardProtein struct must be exactly 256 bits for FPGA alignment");
        }
    }

    pub fn tick(self: RewardProtein, next_gen_all: []RewardProtein, dopamine_wave: u8) void {
        const self_idx = @as(usize, @intCast(self.id));
        const next = &next_gen_all[self_idx];

        // 1. REWARD LOCK-IN: If Dopamine is high AND I was recently active, STRENGTHEN.
        if (dopamine_wave > 100 and self.eligibility_trace > 50) {
            next.w_north = self.w_north +| 30;
            next.w_south = self.w_south +| 30;
            next.w_east  = self.w_east  +| 30;
            next.w_west  = self.w_west  +| 30;
        }

        var final_trace = self.eligibility_trace;

        // 2. PROPAGATION (Weighted by local memory)
        if (self.excitation > 50) {
            const signal = @as(i32, @intCast(self.excitation)) - 15;
            const weights = [_]u8{ next.w_north, next.w_south, next.w_east, next.w_west };
            const neighbors = [_][2]i32{ .{0,-1}, .{0,1}, .{1,0}, .{-1,0} };

            for (neighbors, 0..) |n, i| {
                const weighted_val = @divTrunc(signal * @as(i32, @intCast(weights[i])), 255);
                this.spread(next_gen_all, self.id, weighted_val, n);
            }
            
            final_trace = 255; // Tag for reward
        }

        // 3. DECAY
        next.eligibility_trace = final_trace -| 10;
        next.excitation = (next.excitation -| self.excitation) +| (self.excitation -| 20);
        
        // Natural weight drift (Forgetting unused paths)
        if (next.w_north > 50) next.w_north -= 1;
        if (next.w_south > 50) next.w_south -= 1;
        if (next.w_east  > 50) next.w_east  -= 1;
        if (next.w_west  > 50) next.w_west  -= 1;
    }

    fn spread(next_gen: []RewardProtein, id: u32, val: i32, n: [2]i32) void {
        const x = id % CONFIG.WIDTH;
        const y = id / CONFIG.WIDTH;
        const nx = @as(i64, @intCast(x)) + n[0];
        const ny = @as(i64, @intCast(y)) + n[1];
        if (nx >= 0 and nx < CONFIG.WIDTH and ny >= 0 and ny < CONFIG.HEIGHT) {
            const target = @as(usize, @intCast(ny * CONFIG.WIDTH + nx));
            next_gen[target].excitation = next_gen[target].excitation +| @as(u8, @intCast(@max(0, val)));
        }
    }
};

const this = RewardProtein;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const count = CONFIG.WIDTH * CONFIG.HEIGHT;
    const matrix = try init.gpa.alloc(RewardProtein, count);
    const next_gen = try init.gpa.alloc(RewardProtein, count);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    // Init: All weights start low (Unlearned)
    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .w_north = 50, .w_south = 50, .w_east = 50, .w_west = 50, .eligibility_trace = 0, .padding = 0 };
    }

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    var global_dopamine: u8 = 0;

    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- MASTERY: Global Reward Waves (Digital Dopamine) ---\n", .{});
        try stdout.print("Tick: {d: >3} | Dopamine Level: {d: >3}%\n\n", .{ t, @as(u32, global_dopamine) * 100 / 255 });

        // 1. STIMULUS: Random firing at Source (0, 7)
        if (t % 15 < 3) matrix[7 * CONFIG.WIDTH + 0].excitation = 255;

        // 2. REWARD TRIGGER: If signal reaches Target (29, 7), flood with Dopamine!
        if (matrix[7 * CONFIG.WIDTH + 29].excitation > 100) {
            global_dopamine = 255;
        }

        // 3. LOGIC
        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix, 0..) |*p, i| {
            _ = i;
            p.tick(next_gen, global_dopamine);
        }
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // 4. DRAW WEIGHT MAP (W = Learned path)
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.w_east > 150) 'W' 
                               else if (p.excitation > 100) '#' 
                               else if (p.id == 7 * CONFIG.WIDTH + 29) 'X' // TARGET
                               else '.';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }

        if (matrix[7 * CONFIG.WIDTH + 15].w_east > 150) {
            try stdout.print("\n>>> BEHAVIOR MASTERED: ROBOT HAS 'WIRED' THE PATH TO THE GOAL <<<\n", .{});
        } else {
            try stdout.print("\nExploring possible paths to target 'X'...\n", .{});
        }

        global_dopamine = global_dopamine -| 20; // Dopamine fades quickly
        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }
}
