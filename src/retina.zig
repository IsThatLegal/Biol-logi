const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 30;
    pub const HEIGHT: usize = 15;
    pub const TICK_LIMIT: usize = 100;
    pub const TRANSFER_LOSS: u8 = 15;
    pub const DECAY_RATE: u8 = 8;
    pub const INHIBITION_STRENGTH: u8 = 20; 
};

pub const Protein = packed struct {
    id: u32,
    energy: u8,
    excitation: u8,
    threshold: u8,
    role: u8,
    
    // 2D Neighbors
    north: i32,
    south: i32,
    east: i32,
    west: i32,

    pub fn calculateContribution(self: Protein, matrix: []Protein, next_gen: []i32) void {
        const self_idx = @as(usize, @intCast(self.id));
        
        if (self.excitation > self.threshold) {
            const signal = @as(i32, @intCast(self.excitation)) - CONFIG.TRANSFER_LOSS;
            
            // 1. Excitation (+): Immediate Neighbors
            const neighbors = [_]i32{ self.north, self.south, self.east, self.west };
            for (neighbors) |offset| {
                self.applySignal(matrix, next_gen, offset, @divTrunc(signal, 2));
            }

            // 2. Lateral Inhibition (-): 2nd-Degree Neighbors
            for (neighbors) |offset| {
                self.applySignal(matrix, next_gen, offset * 2, -@as(i32, @intCast(CONFIG.INHIBITION_STRENGTH)));
            }
            
            // 3. Self-Inhibition
            next_gen[self_idx] -= 50;

        } else if (self.excitation > CONFIG.DECAY_RATE) {
            const decayed = @as(i32, @intCast(self.excitation)) - CONFIG.DECAY_RATE;
            if (next_gen[self_idx] < decayed) next_gen[self_idx] = decayed;
        }
    }

    fn applySignal(self: Protein, matrix: []Protein, next_gen: []i32, offset: i32, val: i32) void {
        const target_idx = @as(i64, @intCast(self.id)) + offset;
        if (target_idx >= 0 and target_idx < @as(i64, @intCast(matrix.len))) {
            const idx = @as(usize, @intCast(target_idx));
            next_gen[idx] += val;
        }
    }
};

pub const Matrix2D = struct {
    allocator: std.mem.Allocator,
    matrix: []Protein,
    next_gen: []i32,
    width: usize,
    height: usize,

    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize) !Matrix2D {
        const count = w * h;
        const matrix = try allocator.alloc(Protein, count);
        const next_gen = try allocator.alloc(i32, count);

        const self = Matrix2D{
            .allocator = allocator,
            .matrix = matrix,
            .next_gen = next_gen,
            .width = w,
            .height = h,
        };

        for (matrix, 0..) |*p, i| {
            const x = i % w;
            const y = i / w;
            p.* = .{
                .id = @as(u32, @intCast(i)),
                .energy = 255,
                .excitation = 0,
                .threshold = 30,
                .role = 1,
                .north = if (y > 0) -@as(i32, @intCast(w)) else 0,
                .south = if (y < h - 1) @as(i32, @intCast(w)) else 0,
                .east = if (x < w - 1) 1 else 0,
                .west = if (x > 0) -1 else 0,
            };
        }
        return self;
    }

    pub fn deinit(self: *Matrix2D) void {
        self.allocator.free(self.matrix);
        self.allocator.free(self.next_gen);
    }

    pub fn tick(self: *Matrix2D, light_x: usize, light_y: usize) void {
        const light_idx = light_y * self.width + light_x;
        if (light_idx < self.matrix.len) {
            self.matrix[light_idx].excitation = 255;
        }

        for (self.next_gen) |*v| v.* = 0;
        for (self.matrix) |p| p.calculateContribution(self.matrix, self.next_gen);

        for (self.matrix, 0..) |*p, i| {
            const result = self.next_gen[i];
            p.excitation = if (result < 0) 0 else if (result > 255) 255 else @as(u8, @intCast(result));
        }
    }

    pub fn draw(self: Matrix2D, stdout: anytype) !void {
        try stdout.print("\x1B[H", .{}); 
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const p = self.matrix[y * self.width + x];
                const char: u8 = if (p.excitation > 200) '#' else if (p.excitation > 100) '*' else if (p.excitation > 30) '+' else ' ';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("\x1B[2J", .{}); // Clear screen
    var sim = try Matrix2D.init(init.gpa, CONFIG.WIDTH, CONFIG.HEIGHT);
    defer sim.deinit();

    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        const fx = @as(f32, @floatFromInt(t)) * 0.1;
        const lx = @as(usize, @intFromFloat(@as(f32, @floatFromInt(CONFIG.WIDTH / 2)) + std.math.cos(fx) * 12.0));
        const ly = @as(usize, @intFromFloat(@as(f32, @floatFromInt(CONFIG.HEIGHT / 2)) + std.math.sin(fx) * 6.0));

        sim.tick(lx, ly);
        try sim.draw(stdout);
        try stdout.print("Tick {d: >3}: Sharp Tracking (Lateral Inhibition Active)\n", .{ t });
        try stdout.flush();
        
        try Io.sleep(io, .{ .nanoseconds = 50 * std.time.ns_per_ms }, .awake);
    }
}
