const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 40;
    pub const HEIGHT: usize = 20;
    pub const TICK_LIMIT: usize = 250;
};

/// The Sentinel Protein: The "Super Hero" Brain Cell.
/// Fuses all 5 Human Senses + Superhuman RF-Sensing.
/// Total Size: 256 bits (32 bytes).
pub const SentinelProtein = packed struct {
    id: u32,
    
    // --- The 5 Human Senses ---
    s_vision: u8,    
    s_hearing: u8,   
    s_touch: u8,     
    s_smell: u8,     
    s_taste: u8,     

    // --- Superhuman Senses ---
    s_rf: u8,        
    
    // --- Metabolic & Processing State ---
    resonance: u8,   
    energy: u8,      
    role: u8,        
    threshold: u8,   
    last_peak: u16,  
    is_echoing: bool,
    
    padding: u87,   

    pub fn tick(self: SentinelProtein, next_gen_all: []SentinelProtein, current_tick: usize) void {
        const self_idx = @as(usize, @intCast(self.id));
        const next = &next_gen_all[self_idx];

        // 1. CROSS-MODAL FUSION (The Super Hero Logic)
        if (self.s_vision > 200 and self.s_rf > 150) {
            next.resonance = self.resonance +| 100;
        }

        if (self.s_smell > 100) {
            this.spread(next_gen_all, self.id, @as(i32, @intCast(self.s_smell)) - 5, .Smell);
        }

        if (self.s_touch > 200) {
            this.spread(next_gen_all, self.id, 255, .Touch);
        }

        // 2. STANDARD PROPAGATION (Vision/Hearing)
        if (self.s_vision > 40) this.spread(next_gen_all, self.id, @divTrunc(@as(i32, @intCast(self.s_vision)) - 10, 4), .Vision);
        if (self.s_hearing > 50) this.spread(next_gen_all, self.id, @as(i32, @intCast(self.s_hearing)) - 10, .Hearing);

        // 3. DECAY
        next.s_vision = self.s_vision -| 20;
        next.s_hearing = self.s_hearing -| 15;
        next.s_touch = self.s_touch -| 60;  
        next.s_smell = self.s_smell -| 5;   
        next.s_taste = self.s_taste -| 25;
        next.s_rf = self.s_rf -| 10;
        next.resonance = self.resonance -| 5;
        _ = current_tick;
    }

    const Mode = enum { Vision, Hearing, Touch, Smell, Taste, RF };

    fn spread(next_gen: []SentinelProtein, id: u32, val: i32, mode: Mode) void {
        const x = id % CONFIG.WIDTH;
        const y = id / CONFIG.WIDTH;
        const neighbors = [_][2]i32{ .{0,1}, .{0,-1}, .{1,0}, .{-1,0} };
        for (neighbors) |n| {
            const nx = @as(i64, @intCast(x)) + n[0];
            const ny = @as(i64, @intCast(y)) + n[1];
            if (nx >= 0 and nx < CONFIG.WIDTH and ny >= 0 and ny < CONFIG.HEIGHT) {
                const target = @as(usize, @intCast(ny * CONFIG.WIDTH + nx));
                const u_val = @as(u8, @intCast(@max(0, val)));
                switch (mode) {
                    .Vision => next_gen[target].s_vision = next_gen[target].s_vision +| u_val,
                    .Hearing => next_gen[target].s_hearing = next_gen[target].s_hearing +| u_val,
                    .Touch => next_gen[target].s_touch = next_gen[target].s_touch +| u_val,
                    .Smell => next_gen[target].s_smell = next_gen[target].s_smell +| u_val,
                    .Taste => next_gen[target].s_taste = next_gen[target].s_taste +| u_val,
                    .RF => next_gen[target].s_rf = next_gen[target].s_rf +| u_val,
                }
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

    const count = CONFIG.WIDTH * CONFIG.HEIGHT;
    const matrix = try init.gpa.alloc(SentinelProtein, count);
    const next_gen = try init.gpa.alloc(SentinelProtein, count);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    for (matrix, 0..) |*p, i| {
        p.* = .{ 
            .id = @as(u32, @intCast(i)), .s_vision = 0, .s_hearing = 0, .s_touch = 0, 
            .s_smell = 0, .s_taste = 0, .s_rf = 0, .resonance = 0, .last_peak = 0, 
            .energy = 255, .role = 0, .threshold = 30, .is_echoing = false, .padding = 0 
        };
    }

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- THE SENTINEL: Full Human + Superhuman Spectrum ---\n", .{});
        try stdout.print("Tick: {d} | Status: MULTI-MODAL SENSORY SYNTHESIS ACTIVE\n\n", .{t});

        // 1. Moving Biological Target
        const vx = @as(usize, @intFromFloat(@as(f32, @floatFromInt(CONFIG.WIDTH / 2)) + std.math.cos(@as(f32, @floatFromInt(t)) * 0.1) * 15.0));
        const vy = @as(usize, @intFromFloat(@as(f32, @floatFromInt(CONFIG.HEIGHT / 2)) + std.math.sin(@as(f32, @floatFromInt(t)) * 0.1) * 8.0));
        
        matrix[vy * CONFIG.WIDTH + vx].s_vision = 255;
        matrix[vy * CONFIG.WIDTH + vx].s_smell = 200; 
        if (t % 5 == 0) matrix[vy * CONFIG.WIDTH + vx].s_rf = 255; 

        // 2. Random Impact (Touch)
        if (t > 40 and t < 45) matrix[10 * CONFIG.WIDTH + 10].s_touch = 255;

        // 3. Logic
        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix) |p| p.tick(next_gen, t);
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // 4. Draw
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.resonance > 100) '!' 
                               else if (p.s_touch > 100) 'X' 
                               else if (p.s_rf > 100) 'R' 
                               else if (p.s_smell > 80) 's' 
                               else if (p.s_vision > 100) 'V' 
                               else '.';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }

        try stdout.print("\n[V]:Vision [s]:Smell [R]:RF/Life [X]:Impact [!]:FUSED TARGET\n", .{});
        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 40 * std.time.ns_per_ms }, .awake);
    }
}
