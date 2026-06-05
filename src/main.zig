const std = @import("std");
const Io = std.Io;
const sentinel = @import("sentinel");

const CONFIG = struct {
    pub const WIDTH: usize = 30;
    pub const HEIGHT: usize = 12;
    pub const TICK_LIMIT: usize = 300;
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const count = CONFIG.WIDTH * CONFIG.HEIGHT;
    const matrix = try allocator.alloc(sentinel.SentinelProtein, count);
    const next_gen = try allocator.alloc(sentinel.SentinelProtein, count);
    defer allocator.free(matrix);
    defer allocator.free(next_gen);

    // Initialize
    for (matrix, 0..) |*p, i| {
        p.* = .{ 
            .id = @as(u32, @intCast(i)), .s_vision = 0, .s_hearing = 0, .s_touch = 0, 
            .s_smell = 0, .s_taste = 0, .s_rf = 0, .resonance = 0, .last_peak = 0, 
            .energy = 255, .role = 0, .threshold = 30, .is_echoing = false,
            .destination_bus_id = 0, .route_delay = 0, .padding = 0 
        };
    }

    try stdout.print("\x1B[2J", .{}); 

    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{}); 
        
        try stdout.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        try stdout.print("║         BIO-LOGI: SENTINEL CORE LIVE DASHBOARD               ║\n", .{});
        try stdout.print("║  Multi-Modal Fusion • Metabolic Logic • High Fidelity Proof  ║\n", .{});
        try stdout.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        
        // 1. STIMULUS
        const fx = @as(f32, @floatFromInt(t)) * 0.1;
        const lx = @as(usize, @intFromFloat(@as(f32, @floatFromInt(CONFIG.WIDTH / 2)) + std.math.cos(fx) * 12.0));
        const ly = @as(usize, @intFromFloat(@as(f32, @floatFromInt(CONFIG.HEIGHT / 2)) + std.math.sin(fx) * 4.0));
        matrix[ly * CONFIG.WIDTH + lx].s_vision = 255;
        matrix[ly * CONFIG.WIDTH + lx].s_smell = 250;
        if (t % 5 == 0) matrix[ly * CONFIG.WIDTH + lx].s_rf = 255;

        // 2. LOGIC
        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix) |p| p.tick(next_gen, t, CONFIG.WIDTH, CONFIG.HEIGHT);
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // 3. DRAW PERCEPTION FIELD
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            try stdout.print("  ", .{});
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.resonance > 100) '!' 
                               else if (p.s_rf > 100) 'R' 
                               else if (p.s_vision > 150) 'V'
                               else if (p.s_smell > 100) 's'
                               else ' '; // Use space instead of · for clearer view
                
                if (char == '!') {
                    try stdout.print("\x1B[1;32m{c}\x1B[0m ", .{char});
                } else if (char == 'R') {
                    try stdout.print("\x1B[1;31m{c}\x1B[0m ", .{char});
                } else if (char == 'V') {
                    try stdout.print("\x1B[1;37m{c}\x1B[0m ", .{char});
                } else if (char == 's') {
                    try stdout.print("\x1B[34m{c}\x1B[0m ", .{char});
                } else {
                    try stdout.print("{c} ", .{char});
                }
            }
            try stdout.print("\n", .{});
        }

        try stdout.print("\n  [V]:Vision [s]:Smell [R]:RF/Heartbeat [!]:FUSED TARGET\n", .{});
        try stdout.print("  Tick: {d: >4} | Mode: MULTI-MODAL SYNTHESIS\n", .{t});
        
        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 40 * std.time.ns_per_ms }, .awake);
    }
}
