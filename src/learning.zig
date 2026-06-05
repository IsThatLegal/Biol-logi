const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 30;
    pub const HEIGHT: usize = 15;
    pub const TICK_LIMIT: usize = 300;
};

/// The Learning Sentinel Protein.
/// Implements Local Synaptic Plasticity using Hebbian rules.
pub const LearningProtein = packed struct {
    id: u32,
    excitation: u8,
    energy: u8,
    
    // --- Local Connection Weights (The "Learning" memory) ---
    // These represent the strength of the physical 'wires' to neighbors.
    w_north: u8,
    w_south: u8,
    w_east: u8,
    w_west: u8,

    // Timing Trace: When did this node last fire?
    last_fired: u16,

    padding: u64, // Still 256 bits total

    pub fn tick(self: LearningProtein, next_gen_all: []LearningProtein, matrix: []LearningProtein, current_tick: usize) void {
        const self_idx = @as(usize, @intCast(self.id));
        const next = &next_gen_all[self_idx];

        // 1. PROPAGATION (Weighted by local memory)
        if (self.excitation > 50) {
            const signal = @as(i32, @intCast(self.excitation)) - 10;
            const neighbors = [_][2]i32{ .{0,-1}, .{0,1}, .{1,0}, .{-1,0} }; // N, S, E, W
            const weights = [_]u8{ self.w_north, self.w_south, self.w_east, self.w_west };

            for (neighbors, 0..) |n, i| {
                // Modified Signal: Signal Strength * Connection Weight
                const weighted_signal = @divTrunc(signal * @as(i32, @intCast(weights[i])), 255);
                this.spread(next_gen_all, self.id, weighted_signal, n);
            }
            next.last_fired = @as(u16, @intCast(current_tick));
        }

        // 2. HEBBIAN LEARNING: "Cells that fire together, wire together."
        // If I fired, check if my neighbors also fired recently.
        if (self.excitation > 200) {
            this.updateWeights(next_gen_all, matrix, self.id, current_tick);
        }

        // 3. DECAY & FORGETTING
        next.excitation = self.excitation -| 15;
        // Natural weight decay (prevents permanent obsessions)
        if (current_tick % 50 == 0) {
            next.w_north = self.w_north -| 1;
            next.w_south = self.w_south -| 1;
            next.w_east = self.w_east -| 1;
            next.w_west = self.w_west -| 1;
        }
    }

    fn updateWeights(next_gen: []LearningProtein, matrix: []LearningProtein, id: u32, t: usize) void {
        const x = id % CONFIG.WIDTH;
        const y = id / CONFIG.WIDTH;
        const next_self = &next_gen[id];
        const neighbors = [_][2]i32{ .{0,-1}, .{0,1}, .{1,0}, .{-1,0} };
        
        for (neighbors, 0..) |n, i| {
            const nx = @as(i64, @intCast(x)) + n[0];
            const ny = @as(i64, @intCast(y)) + n[1];
            if (nx >= 0 and nx < CONFIG.WIDTH and ny >= 0 and ny < CONFIG.HEIGHT) {
                const target_idx = @as(usize, @intCast(ny * CONFIG.WIDTH + nx));
                const target = matrix[target_idx];
                
                // If neighbor fired in the last 2 ticks -> STRENGTHEN
                if (@as(usize, @intCast(t)) - target.last_fired <= 2) {
                    switch (i) {
                        0 => next_self.w_north = next_self.w_north +| 20,
                        1 => next_self.w_south = next_self.w_south +| 20,
                        2 => next_self.w_east = next_self.w_east +| 20,
                        3 => next_self.w_west = next_self.w_west +| 20,
                        else => {},
                    }
                }
            }
        }
    }

    fn spread(next_gen: []LearningProtein, id: u32, val: i32, n: [2]i32) void {
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

const this = LearningProtein;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const count = CONFIG.WIDTH * CONFIG.HEIGHT;
    const matrix = try init.gpa.alloc(LearningProtein, count);
    const next_gen = try init.gpa.alloc(LearningProtein, count);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    // Init: All weights start at 128 (Neutral)
    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .energy = 255, .w_north = 128, .w_south = 128, .w_east = 128, .w_west = 128, .last_fired = 0, .padding = 0 };
    }

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- LEARNING TEST: Synaptic Plasticity --- \n", .{});
        try stdout.print("Tick: {d: >3} | Method: Hebbian Path Reinforcement\n\n", .{t});

        // SIMULATION: Repeated stimulus at Node (10, 5) moving to (11, 5)
        // We want the system to "Learn" this specific path.
        if (t % 10 < 2) {
             matrix[5 * CONFIG.WIDTH + 10].excitation = 255;
             matrix[5 * CONFIG.WIDTH + 11].excitation = 255;
        }

        // Logic
        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix) |p| p.tick(next_gen, matrix, t);
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // Draw WEIGHT Map (W = Strong path, . = Neutral)
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.w_east > 200 or p.w_west > 200) 'W' // PATH LEARNED
                               else if (p.excitation > 100) '#' 
                               else '.';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }

        if (matrix[5 * CONFIG.WIDTH + 10].w_east > 200) {
            try stdout.print("\n>>> KNOWLEDGE ACQUIRED: Path Reinforcement Success <<<\n", .{});
        } else {
            try stdout.print("\nPracticing stimulus... (Weight Building)\n", .{});
        }

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }
}
