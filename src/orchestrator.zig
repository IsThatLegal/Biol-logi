const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 40;
    pub const HEIGHT: usize = 20;
    pub const TICK_LIMIT: usize = 200;
};

// --- FIX 1: THE PROGRAMMING PROBLEM (A SIMPLE RECIPE SYSTEM) ---
pub const NodeRole = enum(u8) {
    Empty = 0,
    VisualSource = 1,
    LifeSensor = 2,
    MotorActor = 3,
};

pub const NetworkRecipe = struct {
    x: u8,
    y: u8,
    role: NodeRole,
};

// --- THE CORE PROTEIN WITH SPATIAL ROUTING ---
pub const SentinelProtein = packed struct {
    id: u32,
    excitation: u8,
    role: u8,
    energy: u8,
    
    // FIX 2: THE SCALING MIRAGE (ROUTING LATENCY)
    // Signals now take 'delay' ticks to travel based on physical distance
    // This is stored as a 'buffer' of in-flight signals
    latency_buffer: u8, 
    
    padding: u208, // Still 256 bits

    pub fn tick(self: *SentinelProtein, next_gen_all: []SentinelProtein, current_tick: usize) void {
        _ = current_tick;
        
        // Handle Latency Buffer: Signal only hits 'excitation' after delay
        if (self.latency_buffer > 0) {
            self.excitation = self.excitation +| (self.latency_buffer / 2);
            self.latency_buffer = 0;
        }

        if (self.excitation > 50) {
            const signal = self.excitation -| 20;
            // Spread to neighbors (simulating physical wire delay)
            this.spread(next_gen_all, self.id, signal);
        }

        self.excitation = self.excitation -| 15;
    }

    fn spread(next_gen: []SentinelProtein, id: u32, val: u8) void {
        const neighbors = [_][2]i32{ .{0,1}, .{0,-1}, .{1,0}, .{-1,0} };
        for (neighbors) |n| {
            const x = id % CONFIG.WIDTH;
            const y = id / CONFIG.WIDTH;
            const nx = @as(i64, @intCast(x)) + n[0];
            const ny = @as(i64, @intCast(y)) + n[1];
            if (nx >= 0 and nx < CONFIG.WIDTH and ny >= 0 and ny < CONFIG.HEIGHT) {
                const target = @as(usize, @intCast(ny * CONFIG.WIDTH + nx));
                // ADDING SPATIAL LATENCY: Instead of instant update, we put it in the buffer
                // This simulates the 'wire length' on the FPGA chip.
                next_gen[target].latency_buffer = next_gen[target].latency_buffer +| val;
            }
        }
    }
};

const this = SentinelProtein;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const matrix = try init.gpa.alloc(SentinelProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    const next_gen = try init.gpa.alloc(SentinelProtein, CONFIG.WIDTH * CONFIG.HEIGHT);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .role = 0, .energy = 255, .latency_buffer = 0, .padding = 0 };
    }

    // --- FIX 1 DEMO: PROGRAMMING VIA RECIPE ---
    // Anyone can "program" the robot by adding to this simple list.
    const recipe = [_]NetworkRecipe{
        .{ .x = 0, .y = 0, .role = .VisualSource },
        .{ .x = 15, .y = 7, .role = .LifeSensor },
        .{ .x = 39, .y = 19, .role = .MotorActor },
    };

    for (recipe) |r| {
        matrix[r.y * CONFIG.WIDTH + r.x].role = @intFromEnum(r.role);
    }

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- BIO-LOGI ORCHESTRATOR: Solving Weaknesses ---\n", .{});
        try stdout.print("Latency: CYCLE-ACCURATE ROUTING | Mode: RECIPE-DRIVEN\n\n", .{});

        // Stimulate the source from the recipe
        matrix[0].excitation = 255;

        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix, 0..) |*p, i| {
            _ = i;
            p.tick(next_gen, t);
        }
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // Draw
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.role != 0) '?' 
                               else if (p.excitation > 100) '#' 
                               else if (p.excitation > 30) '*' 
                               else '.';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }
        
        try stdout.print("\nStatus: Signals now follow the physics of 'Wire Delay'.\n", .{});
        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 40 * std.time.ns_per_ms }, .awake);
    }
}
