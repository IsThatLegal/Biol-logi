const std = @import("std");
const orchestrator = @import("orchestrator.zig");
const SentinelProtein = orchestrator.SentinelProtein;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("=== BIOL-LOGI: LATENCY BENCHMARK ===\n", .{});
    try stdout.print("Comparing Local neighbor hops vs. Long-range AXI Highways\n\n", .{});

    const node_count = 10;
    const matrix_local = try allocator.alloc(SentinelProtein, node_count);
    const next_gen_local = try allocator.alloc(SentinelProtein, node_count);
    defer allocator.free(matrix_local);
    defer allocator.free(next_gen_local);

    const matrix_axon = try allocator.alloc(SentinelProtein, node_count);
    const next_gen_axon = try allocator.alloc(SentinelProtein, node_count);
    defer allocator.free(matrix_axon);
    defer allocator.free(next_gen_axon);

    // --- CASE 1: LOCAL HOP-BY-HOP ROUTING ---
    for (matrix_local, 0..) |*p, i| {
        p.* = .{
            .id = @as(u32, @intCast(i)),
            .excitation = 0,
            .role = 0,
            .energy = 255,
            .latency_buffer = 0,
            .destination_bus_id = 0, // Local only
            .route_delay = 0,
            .padding = 0,
        };
    }

    // Stimulate Node 0
    matrix_local[0].excitation = 255;

    var ticks_local: usize = 0;
    while (ticks_local < 100) : (ticks_local += 1) {
        // Copy to next gen
        for (matrix_local, 0..) |p, i| next_gen_local[i] = p;
        // Process tick
        for (matrix_local, 0..) |*p, i| {
            _ = i;
            p.tick(next_gen_local, ticks_local, 10, 1);
        }
        // Commit
        for (matrix_local, 0..) |*p, i| p.* = next_gen_local[i];

        if (matrix_local[9].excitation > 0) {
            break;
        }
    }

    // --- CASE 2: LONG-RANGE DIRECT AXON ROUTING ---
    for (matrix_axon, 0..) |*p, i| {
        p.* = .{
            .id = @as(u32, @intCast(i)),
            .excitation = 0,
            .role = 0,
            .energy = 255,
            .latency_buffer = 0,
            .destination_bus_id = if (i == 0) 10 else 0, // Node 0 routes to Node 9 (1-based index)
            .route_delay = 1,
            .padding = 0,
        };
    }

    // Stimulate Node 0
    matrix_axon[0].excitation = 255;

    var ticks_axon: usize = 0;
    while (ticks_axon < 100) : (ticks_axon += 1) {
        // Copy to next gen
        for (matrix_axon, 0..) |p, i| next_gen_axon[i] = p;
        // Process tick
        for (matrix_axon, 0..) |*p, i| {
            _ = i;
            p.tick(next_gen_axon, ticks_axon, 10, 1);
        }
        // Commit
        for (matrix_axon, 0..) |*p, i| p.* = next_gen_axon[i];

        if (matrix_axon[9].excitation > 0) {
            break;
        }
    }

    // Print Results
    try stdout.print("Local Hops (0 -> 1 -> ... -> 9): {d} cycles\n", .{ticks_local});
    try stdout.print("Long-Range Axon (0 -> 9 direct): {d} cycles\n", .{ticks_axon});
    try stdout.print("Latency Reduction: {d:.1}%\n", .{
        (@as(f64, @floatFromInt(ticks_local)) - @as(f64, @floatFromInt(ticks_axon))) / @as(f64, @floatFromInt(ticks_local)) * 100.0,
    });
}
