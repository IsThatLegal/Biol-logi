const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const NODE_COUNT: usize = 40;
    pub const TICK_LIMIT: usize = 150;
    pub const TARGET_PERIOD: usize = 10;
};

pub const MimicProtein = packed struct {
    id: u32,
    excitation: u8,
    resonance: u8,
    last_peak_tick: u16,

    pub fn tick(self: *MimicProtein, incoming: u8, current_tick: usize) void {
        self.excitation = incoming;

        if (self.excitation > 200) {
            const period = @as(u16, @intCast(current_tick)) - self.last_peak_tick;
            
            // STRICT FILTERING: Must be exactly the target period +/- 1
            if (period >= CONFIG.TARGET_PERIOD - 1 and period <= CONFIG.TARGET_PERIOD + 1) {
                self.resonance = self.resonance +| 40;
            } else if (period > 2) {
                // Harsh penalty for out-of-phase signals (Anti-Spoofing)
                self.resonance = self.resonance -| 50; 
            }
            self.last_peak_tick = @as(u16, @intCast(current_tick));
        }

        if (current_tick % 2 == 0) {
            self.resonance = self.resonance -| 1;
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- RED TEAM: The Mimic Attack (Spoofing) ---\n", .{});
    try stdout.print("Target: 10-tick period. Enemy injecting 9-tick and 11-tick noise.\n\n", .{});

    const matrix = try init.gpa.alloc(MimicProtein, CONFIG.NODE_COUNT);
    defer init.gpa.free(matrix);

    for (matrix, 0..) |*p, i| p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .resonance = 0, .last_peak_tick = 0 };

    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("{d: >3}: ", .{t});

        for (matrix, 0..) |*p, i| {
            var signal: u8 = 0;

            // NODE 10: The True Target (10-tick period)
            if (i == 10 and t % 10 == 0) signal = 255;
            
            // NODE 20: The "Fast" Mimic (9-tick period)
            if (i == 20 and t % 9 == 0) signal = 255;

            // NODE 30: The "Slow" Mimic (11-tick period)
            if (i == 30 and t % 11 == 0) signal = 255;

            p.tick(signal, t);

            const char: u8 = if (p.resonance > 150) '!' 
                           else if (p.resonance > 50) '*' 
                           else if (p.excitation > 200) '+' 
                           else '.';
            try stdout.print("{c}", .{char});
        }

        if (matrix[10].resonance > 150) try stdout.print(" [TRUE TARGET LOCKED]", .{});
        if (matrix[20].resonance > 150) try stdout.print(" [SPOOFED BY FAST MIMIC!]", .{});
        if (matrix[30].resonance > 150) try stdout.print(" [SPOOFED BY SLOW MIMIC!]", .{});
        
        try stdout.print("\n", .{});
        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }
}
