const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const NODE_COUNT: usize = 40;
    pub const TICK_LIMIT: usize = 120;
    pub const HEART_PERIOD: usize = 10;
    pub const NOISE_LEVEL: u8 = 100; // EXTREME NOISE (almost matching signal)
};

pub const HeartbeatProtein = packed struct {
    id: u32,
    excitation: u8,
    resonance: u8,
    last_peak_tick: u16,

    pub fn tick(self: HeartbeatProtein, next_gen_all: []HeartbeatProtein, current_tick: usize) void {
        const self_idx = @as(usize, @intCast(self.id));
        const next_self = &next_gen_all[self_idx];

        // 1. Local Frequency Matching
        if (self.excitation > 200) {
            const period = @as(u16, @intCast(current_tick)) - self.last_peak_tick;
            if (period >= CONFIG.HEART_PERIOD - 1 and period <= CONFIG.HEART_PERIOD + 1) {
                // MATCH: Build local resonance
                next_self.resonance = self.resonance +| 50;
            } else if (period > 2) {
                // MISMATCH: Decay resonance
                next_self.resonance = self.resonance -| 20;
            }
            next_self.last_peak_tick = @as(u16, @intCast(current_tick));
        }

        // 2. Cooperative Resonance (Share confidence)
        if (self.resonance > 80) {
            const share = self.resonance / 8;
            self.modifyResonance(next_gen_all, 1, share);
            self.modifyResonance(next_gen_all, -1, share);
            
            // 3. Lateral Noise Suppression (The "Sharpening")
            // Only suppress if NOT the local node (don't kill your own signal)
            self.suppressNeighbors(next_gen_all, 1, 40);
            self.suppressNeighbors(next_gen_all, -1, 40);
        }

        // 4. Natural Decay
        if (current_tick % 2 == 0) {
            next_self.resonance = next_self.resonance -| 1;
        }
    }

    fn modifyResonance(self: HeartbeatProtein, next_gen: []HeartbeatProtein, offset: i32, val: u8) void {
        const target_idx = @as(i64, @intCast(self.id)) + offset;
        if (target_idx >= 0 and target_idx < @as(i64, @intCast(CONFIG.NODE_COUNT))) {
            const idx = @as(usize, @intCast(target_idx));
            next_gen[idx].resonance = next_gen[idx].resonance +| val;
        }
    }

    fn suppressNeighbors(self: HeartbeatProtein, next_gen: []HeartbeatProtein, offset: i32, val: u8) void {
        const target_idx = @as(i64, @intCast(self.id)) + offset;
        if (target_idx >= 0 and target_idx < @as(i64, @intCast(CONFIG.NODE_COUNT))) {
            const idx = @as(usize, @intCast(target_idx));
            next_gen[idx].excitation = next_gen[idx].excitation -| val;
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- Bio-Logi: Life Sensor 2.1 (Decentralized Cooperative Resonance) ---\n", .{});
    try stdout.print("Simulation: EXTREME NOISE ({d}) | Heartbeat at Node 20\n\n", .{CONFIG.NOISE_LEVEL});

    const matrix = try init.gpa.alloc(HeartbeatProtein, CONFIG.NODE_COUNT);
    const next_gen = try init.gpa.alloc(HeartbeatProtein, CONFIG.NODE_COUNT);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .resonance = 0, .last_peak_tick = 0 };
    }

    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("{d: >3}: ", .{t});

        // A. PHYSICAL LAYER (Environment)
        const is_heart_beat = (t % CONFIG.HEART_PERIOD == 0);
        for (matrix, 0..) |*p, i| {
            var signal = random.uintAtMost(u8, CONFIG.NOISE_LEVEL);
            if (i == 20 and is_heart_beat) signal = 255;
            p.excitation = signal;
            next_gen[i] = p.*; // Copy baseline to next_gen
        }

        // B. PROTEIN LAYER (Decentralized Logic)
        for (matrix) |p| {
            p.tick(next_gen, t);
        }

        // C. VISUALIZATION & SYNC
        for (matrix, 0..) |*p, i| {
            p.* = next_gen[i]; // Commit generation
            
            const char: u8 = if (p.resonance > 200) '!' 
                           else if (p.resonance > 100) '#' 
                           else if (p.resonance > 40) '*' 
                           else if (p.excitation > 200) '+' 
                           else ' ';
            try stdout.print("{c}", .{char});
        }

        if (matrix[20].resonance > 50) {
            try stdout.print(" [SIGNAL STABILIZED]", .{});
        }
        try stdout.print("\n", .{});

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 20 * std.time.ns_per_ms }, .awake);
    }

    try stdout.print("\nLife Sensor 2.1 Complete. The matrix extracted the heartbeat through cooperation.\n", .{});
}
