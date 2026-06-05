const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 20;
    pub const HEIGHT: usize = 10;
    pub const TICK_LIMIT: usize = 200;
};

pub const ShadowProtein = packed struct {
    id: u32,
    excitation: u8,
    w_target: u8, // Memory of the path to target
    eligibility: u8,
    padding: u216,

    pub fn tick(self: *ShadowProtein, next_gen_all: []ShadowProtein, dopamine: u8) void {
        // 1. REWARD Logic
        if (dopamine > 100 and self.eligibility > 50) {
            self.w_target = self.w_target +| 50;
        }

        // 2. Propagation
        if (self.excitation > 50) {
            const signal = @as(i32, @intCast(self.excitation)) - 20;
            const weighted = @divTrunc(signal * @as(i32, @intCast(self.w_target)), 255);
            
            // Simplified: always spread east
            const target_idx = self.id + 1;
            if (target_idx < next_gen_all.len) {
                next_gen_all[target_idx].excitation = next_gen_all[target_idx].excitation +| @as(u8, @intCast(@max(0, weighted)));
            }
            self.eligibility = 255;
        }

        self.excitation = self.excitation -| 20;
        self.eligibility = self.eligibility -| 10;
        
        // Slight natural decay of memory
        if (self.w_target > 50) self.w_target -= 1;
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- RED TEAM: The Shadow Attack (Digital Overdose) ---\n", .{});
    try stdout.print("Goal: Erase legitimately learned paths by flooding with fake rewards.\n\n", .{});

    const matrix = try init.gpa.alloc(ShadowProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    const next_gen = try init.gpa.alloc(ShadowProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    for (matrix, 0..) |*p, i| p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .w_target = 50, .eligibility = 0, .padding = 0 };

    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H\x1B[2J", .{}); // Clear
        try stdout.print("Tick: {d} | Phase: {s}\n\n", .{ t, if (t < 100) "LEGITIMATE LEARNING" else "THE SHADOW ATTACK" });

        var global_dopamine: u8 = 0;

        if (t < 100) {
            // PERIOD 1: Normal Learning (Pulse at 0, Reward at 19)
            if (t % 15 == 0) matrix[5 * CONFIG.WIDTH + 0].excitation = 255;
            if (matrix[5 * CONFIG.WIDTH + 19].excitation > 100) global_dopamine = 255;
        } else {
            // PERIOD 2: THE SHADOW (Digital Overdose)
            // Constant maximum reward regardless of behavior!
            global_dopamine = 255;
            // No stimulus (darkness)
        }

        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix, 0..) |*p, i| {
             _ = i;
             p.tick(next_gen, global_dopamine);
        }
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // Draw Memory Strength (W = Strong)
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.w_target > 200) 'W' else if (p.w_target > 100) '+' else '.';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }

        if (t < 100) {
            try stdout.print("\nBuilding legitimate path memory...\n", .{});
        } else {
            try stdout.print("\nADVERSARIAL ATTACK: Flooding with fake dopamine. Watching memory rot...\n", .{});
        }

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }
}
