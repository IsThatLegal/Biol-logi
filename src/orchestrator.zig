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
    latency_buffer: u8, 
    destination_bus_id: u8,
    route_delay: u8,
    
    padding: u176,

    comptime {
        if (@bitSizeOf(SentinelProtein) != 256) {
            @compileError("SentinelProtein struct must be exactly 256 bits for FPGA alignment");
        }
    }

    pub fn tick(self: *SentinelProtein, next_gen_all: []SentinelProtein, current_tick: usize, width: usize, height: usize) void {
        _ = current_tick;
        
        // Handle Latency Buffer: Signal only hits 'excitation' after delay
        if (self.latency_buffer > 0) {
            self.excitation = self.excitation +| (self.latency_buffer / 2);
            // Subtract the consumed latency_buffer from next_gen_all, preserving any new incoming signals
            next_gen_all[self.id].latency_buffer = next_gen_all[self.id].latency_buffer -| self.latency_buffer;
            self.latency_buffer = 0;
        }

        if (self.excitation > 50) {
            const signal = self.excitation -| 20;
            if (self.destination_bus_id > 0) {
                // Long-range AXI Highway direct routing
                const target_idx = @as(usize, @intCast(self.destination_bus_id - 1));
                if (target_idx < next_gen_all.len) {
                    next_gen_all[target_idx].latency_buffer = next_gen_all[target_idx].latency_buffer +| signal;
                }
            } else {
                // Standard local neighborhood spread
                this.spread(next_gen_all, self.id, signal, width, height);
            }
        }

        self.excitation = self.excitation -| 15;
        next_gen_all[self.id].excitation = self.excitation;
    }

    fn spread(next_gen: []SentinelProtein, id: u32, val: u8, width: usize, height: usize) void {
        const neighbors = [_][2]i32{ .{0,1}, .{0,-1}, .{1,0}, .{-1,0} };
        for (neighbors) |n| {
            const x = id % width;
            const y = id / width;
            const nx = @as(i64, @intCast(x)) + n[0];
            const ny = @as(i64, @intCast(y)) + n[1];
            if (nx >= 0 and nx < @as(i64, @intCast(width)) and ny >= 0 and ny < @as(i64, @intCast(height))) {
                const u_nx = @as(usize, @intCast(nx));
                const u_ny = @as(usize, @intCast(ny));
                const target = u_ny * width + u_nx;
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
            p.tick(next_gen, t, CONFIG.WIDTH, CONFIG.HEIGHT);
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
