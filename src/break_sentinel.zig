const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 40;
    pub const HEIGHT: usize = 20;
    pub const TICK_LIMIT: usize = 150;
};

pub const SentinelProtein = packed struct {
    id: u32,
    s_vision: u8,    
    s_rf: u8,        
    resonance: u8,   
    energy: u8,      // METABOLIC BUDGET
    last_peak: u16,  
    padding: u176,

    comptime {
        if (@bitSizeOf(SentinelProtein) != 256) {
            @compileError("SentinelProtein struct must be exactly 256 bits for FPGA alignment");
        }
    }

    pub fn tick(self: SentinelProtein, next_gen_all: []SentinelProtein, current_tick: usize) void {
        const self_idx = @as(usize, @intCast(self.id));
        const next = &next_gen_all[self_idx];

        // --- 1. METABOLIC CHECK ---
        if (self.energy < 15) {
            // "Paralytic State": Node is too exhausted to process
            next.energy = self.energy +| 4; // Recovery
            next.s_vision = 0;
            next.s_rf = 0;
            next.resonance = 0;
            return;
        }

        var fired: bool = false;

        // 2. Logic (Visual Propagation)
        if (self.s_vision > 40) {
            this.spread(next_gen_all, self.id, @divTrunc(@as(i32, @intCast(self.s_vision)) - 10, 4), 1);
            fired = true;
        }

        // 3. Fused Logic
        if (self.s_vision > 200 and self.s_rf > 150) {
            next.resonance = self.resonance +| 100;
            fired = true;
        }

        // --- 4. METABOLIC COST ---
        if (fired) {
            // Processing intense signals drains energy rapidly
            next.energy = self.energy -| 20; 
        } else {
            // Inactive nodes recover energy
            next.energy = self.energy +| 10; 
        }

        next.s_vision = self.s_vision -| 25;
        next.s_rf = self.s_rf -| 15;
        next.resonance = self.resonance -| 5;
        _ = current_tick;
    }

    fn spread(next_gen: []SentinelProtein, id: u32, val: i32, mode: u8) void {
        const x = id % CONFIG.WIDTH;
        const y = id / CONFIG.WIDTH;
        const neighbors = [_][2]i32{ .{0,1}, .{0,-1}, .{1,0}, .{-1,0} };
        for (neighbors) |n| {
            const nx = @as(i64, @intCast(x)) + n[0];
            const ny = @as(i64, @intCast(y)) + n[1];
            if (nx >= 0 and nx < CONFIG.WIDTH and ny >= 0 and ny < CONFIG.HEIGHT) {
                const target = @as(usize, @intCast(ny * CONFIG.WIDTH + nx));
                if (mode == 1) next_gen[target].s_vision = next_gen[target].s_vision +| @as(u8, @intCast(@max(0, val)));
            }
        }
    }
};

const this = SentinelProtein;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const matrix = try init.gpa.alloc(SentinelProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    const next_gen = try init.gpa.alloc(SentinelProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .s_vision = 0, .s_rf = 0, .resonance = 0, .last_peak = 0, .energy = 255, .padding = 0 };
    }

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- STRESS TEST: Metabolic Resilience ---\n", .{});
        try stdout.print("Tick: {d: >3} | Avg Energy: ", .{t});

        const is_flashbang = (t >= 30 and t <= 45);
        
        for (matrix, 0..) |*p, i| {
            if (is_flashbang) {
                p.s_vision = 255;
                p.s_rf = 255;
            }
            next_gen[i] = p.*;
        }

        for (matrix) |p| p.tick(next_gen, t);
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        var avg_energy: u64 = 0;
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                avg_energy += p.energy;
                const char: u8 = if (p.energy > 200) 'E' 
                               else if (p.energy > 50) '.' 
                               else '#';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }
        
        const final_avg = avg_energy / (CONFIG.WIDTH * CONFIG.HEIGHT);
        try stdout.print("\nAverage Energy: {d}% | ", .{final_avg * 100 / 255});

        if (is_flashbang) {
            try stdout.print("ATTACK: SENSORY OVERLOAD!   \n", .{});
        } else if (final_avg < 80) {
            try stdout.print("RECOVERING...               \n", .{});
        } else {
            try stdout.print("System: STABLE              \n", .{});
        }

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }
}
