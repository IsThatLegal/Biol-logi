const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const NODE_COUNT: usize = 200;
    pub const TICK_LIMIT: usize = 400;
    pub const TRAINING_TICKS: usize = 250;
};

pub const AssociativeProtein = packed struct {
    id: u32,
    excitation_v: u8, 
    excitation_r: u8, 
    w_rf_to_v: u8, 
    last_fired_r: u16,
    last_fired_v: u16,
    padding: u176,

    pub fn tick(self: AssociativeProtein, next: *AssociativeProtein, current_tick: usize) void {
        // 1. INFERENCE (Intuition)
        // If RF is active, it predicts Visual based on weight
        const intuition = @divTrunc(@as(i32, @intCast(self.excitation_r)) * @as(i32, @intCast(self.w_rf_to_v)), 255);
        
        // 2. LEARNING (Hebbian)
        // Cells that fire together...
        if (self.excitation_v > 200) {
            const time_diff = @as(i16, @intCast(current_tick)) - @as(i16, @intCast(self.last_fired_r));
            if (time_diff > 0 and time_diff < 10) {
                next.w_rf_to_v = self.w_rf_to_v +| 15;
            }
            next.last_fired_v = @as(u16, @intCast(current_tick));
        }
        
        if (self.excitation_r > 200) {
            next.last_fired_r = @as(u16, @intCast(current_tick));
        }

        // 3. STATE UPDATE & DECAY
        // The final excitation is (Current + Intuition) - Decay
        const decayed_v = self.excitation_v -| 15;
        next.excitation_v = decayed_v +| @as(u8, @intCast(intuition));
        next.excitation_r = self.excitation_r -| 15;
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const matrix = try init.gpa.alloc(AssociativeProtein, CONFIG.NODE_COUNT);
    const next_gen = try init.gpa.alloc(AssociativeProtein, CONFIG.NODE_COUNT);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation_v = 0, .excitation_r = 0, .w_rf_to_v = 0, .last_fired_r = 0, .last_fired_v = 0, .padding = 0 };
    }

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- TRAINING THE SENTINEL: Associative Intuition ---\n", .{});
        
        const is_training = (t < CONFIG.TRAINING_TICKS);
        try stdout.print("Phase: {s} | Tick: {d}\n\n", .{ if (is_training) "TRAINING (RF -> Visual Pairing)" else "TESTING (RF only, Darkness)", t });

        // 1. INPUTS
        if (is_training) {
            if (t % 20 == 0) matrix[100].excitation_r = 255; // RF Pulse
            if (t % 20 == 3) matrix[100].excitation_v = 255; // Visual Flash (3 ticks later)
        } else {
            if (t % 20 == 0) matrix[100].excitation_r = 255; // RF Pulse only
        }

        // 2. LOGIC
        for (matrix, 0..) |p, i| {
            next_gen[i] = p;
            p.tick(&next_gen[i], t);
        }
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // 3. VISUALIZE
        const p = matrix[100];
        try stdout.print("RF Level:     [{d: >3}] {s}\n", .{ p.excitation_r, if (p.excitation_r > 200) "PULSE" else "" });
        try stdout.print("Visual Level: [{d: >3}] {s}\n", .{ p.excitation_v, if (p.excitation_v > 50) "INTUITION" else "" });
        try stdout.print("Learned Associative Weight: {d}/255\n\n", .{p.w_rf_to_v});

        try stdout.print("Memory Strength: ", .{});
        var b: usize = 0; while (b < 40) : (b += 1) {
            const char: u8 = if (p.w_rf_to_v > @as(u8, @intCast(b * 6))) '#' else '-';
            try stdout.print("{c}", .{char});
        }
        try stdout.print("\n", .{});

        if (!is_training and p.excitation_v > 100) {
            try stdout.print("\n>>> PREDICTION SUCCESS: SENTINEL 'SEES' TARGET VIA RF RESONANCE <<<\n", .{});
        } else if (!is_training) {
            try stdout.print("\nTracking heartbeats in darkness...\n", .{});
        } else {
            try stdout.print("\nAssociating multi-modal stimuli...\n", .{});
        }

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }
}
