const std = @import("std");
const Io = std.Io;

pub const Protein = packed struct {
    id: u32,
    energy: u8,
    excitation: u8,
    threshold: u8,
    role: u8,
    neighbor_a: i32,
    neighbor_b: i32,

    pub fn calculateContribution(self: Protein, neighbors_len: usize, next_gen: []u8) void {
        if (self.excitation > self.threshold) {
            const signal = self.excitation -| 10;
            self.addToNext(self.neighbor_a, signal, neighbors_len, next_gen);
            self.addToNext(self.neighbor_b, signal, neighbors_len, next_gen);
        } else if (self.excitation > 2) {
            const self_idx = @as(usize, @intCast(self.id));
            const decayed = self.excitation -| 2;
            if (next_gen[self_idx] < decayed) next_gen[self_idx] = decayed;
        }
    }

    fn addToNext(self: Protein, target_idx: i32, val: u8, neighbors_len: usize, next_gen: []u8) void {
        _ = self;
        if (target_idx >= 0 and target_idx < neighbors_len) {
            const idx = @as(usize, @intCast(target_idx));
            next_gen[idx] = next_gen[idx] +| val;
        }
    }
};

pub fn runScaleTest(allocator: std.mem.Allocator, node_count: usize, stdout: anytype, io: Io) !void {
    try stdout.print("\n--- Testing Scale: {d} Nodes ---\n", .{node_count});
    
    const matrix_size = node_count * @sizeOf(Protein);
    const buffer_size = node_count * @sizeOf(u8);
    const total_mb = (matrix_size + buffer_size) / 1024 / 1024;
    try stdout.print("    [RAM] Target Allocation: {d} MB\n", .{total_mb});

    const matrix = allocator.alloc(Protein, node_count) catch {
        try stdout.print("    [FAIL] Could not allocate matrix RAM.\n", .{});
        return;
    };
    defer allocator.free(matrix);

    const next_gen = allocator.alloc(u8, node_count) catch {
        try stdout.print("    [FAIL] Could not allocate next_gen buffer.\n", .{});
        return;
    };
    defer allocator.free(next_gen);

    // Init
    for (matrix, 0..) |*p, i| {
        p.* = .{
            .id = @as(u32, @intCast(i)),
            .energy = 255,
            .excitation = 0,
            .threshold = 30,
            .role = 1,
            .neighbor_a = @as(i32, @intCast(i)) + 1,
            .neighbor_b = @as(i32, @intCast(i)) - 1,
        };
    }

    const ticks = 5; // Reduced ticks for faster feedback
    const start_time = Io.Timestamp.now(io, .awake);

    var t: usize = 0;
    while (t < ticks) : (t += 1) {
        matrix[0].excitation = 200;
        for (next_gen) |*v| v.* = 0;
        for (matrix) |p| p.calculateContribution(node_count, next_gen);
        for (matrix, 0..) |*p, i| p.excitation = next_gen[i];
        try stdout.print(".", .{});
        try stdout.flush();
    }

    const end_time = Io.Timestamp.now(io, .awake);
    const diff_ns = end_time.nanoseconds - start_time.nanoseconds;
    const elapsed_ms = @as(f64, @floatFromInt(diff_ns)) / std.time.ns_per_ms;

    try stdout.print("\n    [CPU] {d} ticks resolved in {d:.2} ms\n", .{ticks, elapsed_ms});
    try stdout.print("    [PERF] {d:.2} Million Protein-Ticks/sec\n", .{
        (@as(f64, @floatFromInt(node_count)) * @as(f64, @floatFromInt(ticks))) / (elapsed_ms / 1000.0) / 1_000_000.0,
    });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const scales = [_]usize{ 10_000_000, 20_000_000, 40_000_000, 60_000_000, 80_000_000, 100_000_000 };
    for (scales) |s| {
        try runScaleTest(init.gpa, s, stdout, init.io);
    }
}
