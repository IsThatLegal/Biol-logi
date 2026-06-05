const std = @import("std");
const Io = std.Io;
const time = std.time;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const iterations = 100_000;
    const alloc_size = 64;

    try stdout.print("Benchmarking {d} iterations of {d} byte allocations (Zig 0.16.0)\n\n", .{ iterations, alloc_size });

    // --- Benchmark 1: FixedBufferAllocator ---
    {
        var buffer: [alloc_size * 2]u8 = undefined;
        const start = Io.Timestamp.now(io, .awake);
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            const allocator = fba.allocator();
            const ptr = try allocator.alloc(u8, alloc_size);
            std.mem.doNotOptimizeAway(ptr);
            allocator.free(ptr);
        }
        
        const end = Io.Timestamp.now(io, .awake);
        const diff_ns = end.nanoseconds - start.nanoseconds;
        const elapsed_ms = @as(f64, @floatFromInt(diff_ns)) / time.ns_per_ms;
        try stdout.print("FixedBufferAllocator: {d:.3} ms ({d:.3} ns/op)\n", .{ elapsed_ms, @as(f64, @floatFromInt(diff_ns)) / iterations });
    }

    // --- Benchmark 2: ArenaAllocator (Resetting) ---
    {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        
        const start = Io.Timestamp.now(io, .awake);
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const ptr = try allocator.alloc(u8, alloc_size);
            std.mem.doNotOptimizeAway(ptr);
            // We reset the arena periodically to simulate reuse
            if (i % 1000 == 0) {
                _ = arena.reset(.retain_capacity);
            }
        }
        
        const end = Io.Timestamp.now(io, .awake);
        const diff_ns = end.nanoseconds - start.nanoseconds;
        const elapsed_ms = @as(f64, @floatFromInt(diff_ns)) / time.ns_per_ms;
        try stdout.print("ArenaAllocator (reset): {d:.3} ms ({d:.3} ns/op)\n", .{ elapsed_ms, @as(f64, @floatFromInt(diff_ns)) / iterations });
    }

    // --- Benchmark 3: GPA (Standard Heap) ---
    {
        const allocator = init.gpa;
        const start = Io.Timestamp.now(io, .awake);
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const ptr = try allocator.alloc(u8, alloc_size);
            std.mem.doNotOptimizeAway(ptr);
            allocator.free(ptr);
        }
        
        const end = Io.Timestamp.now(io, .awake);
        const diff_ns = end.nanoseconds - start.nanoseconds;
        const elapsed_ms = @as(f64, @floatFromInt(diff_ns)) / time.ns_per_ms;
        try stdout.print("GeneralPurposeAllocator: {d:.3} ms ({d:.3} ns/op)\n", .{ elapsed_ms, @as(f64, @floatFromInt(diff_ns)) / iterations });
    }
}
