const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 10;
    pub const HEIGHT: usize = 10;
    pub const TICK_LIMIT: usize = 100;
};

pub const ChaosProtein = packed struct {
    id: u32,
    excitation: u8,
    energy: u8,
    role: u8, 
    
    padding: u208,

    pub fn tick(self: ChaosProtein, next_gen_all: []ChaosProtein, current_tick: usize) void {
        _ = current_tick;
        const self_idx = @as(usize, @intCast(self.id));
        const next = &next_gen_all[self_idx];

        // --- 1. METABOLIC CHECK ---
        if (self.energy < 30) {
            next.energy = self.energy +| 10;
            // No processing while paralyzed
            return;
        }

        // --- 2. FEEDBACK PROPAGATION ---
        if (self.excitation > 50) {
            const signal = self.excitation; 
            
            const target_id: usize = switch (self.id) {
                0 => 1,
                1 => 11,
                11 => 10,
                10 => 0,
                else => 999,
            };

            if (target_id < next_gen_all.len) {
                // IMPORTANT: Add to neighbor, don't overwrite
                next_gen_all[target_id].excitation = next_gen_all[target_id].excitation +| signal;
            }

            // High energy cost for sustaining a feedback loop
            next.energy = self.energy -| 80; 
        } else {
            next.energy = self.energy +| 20;
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const matrix = try init.gpa.alloc(ChaosProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    const next_gen = try init.gpa.alloc(ChaosProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .energy = 255, .role = 0, .padding = 0 };
    }

    matrix[0].role = 1; matrix[1].role = 1; matrix[10].role = 1; matrix[11].role = 1;

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    
    // Inject first pulse
    matrix[0].excitation = 255;

    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- RED TEAM: The Chaos Loop Attack ---\n", .{});
        try stdout.print("Target: Infinite signal loop (0->1->11->10->0)\n", .{});
        try stdout.print("Tick: {d: >3}\n\n", .{t});

        // 1. Prepare next generation (Decay existing excitation)
        for (matrix, 0..) |p, i| {
            next_gen[i] = p;
            next_gen[i].excitation = p.excitation -| 10; 
        }

        // 2. Process Ticks (Interactions)
        for (matrix) |p| {
            p.tick(next_gen, t);
        }

        // 3. Sync
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // 4. Draw
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.energy < 40) '!' 
                               else if (p.excitation > 100) '#' 
                               else if (p.role == 1) 'o' 
                               else '.';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }

        const loop_energy = (@as(u32, matrix[0].energy) + matrix[1].energy + matrix[10].energy + matrix[11].energy) / 4;
        try stdout.print("\nLoop Health: {d}% | Status: ", .{loop_energy * 100 / 255});
        
        if (matrix[0].excitation > 10 or matrix[1].excitation > 10 or matrix[11].excitation > 10) {
            try stdout.print("LOOP ACTIVE (DANGEROUS)\n", .{});
        } else if (loop_energy < 50) {
            try stdout.print("LOOP BROKEN BY METABOLIC COLLAPSE (SUCCESS)\n", .{});
        } else {
            try stdout.print("INACTIVE\n", .{});
        }

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 100 * std.time.ns_per_ms }, .awake);
    }
}
