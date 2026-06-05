const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- Zig Memory Management Demo (Zig 0.16.0) ---\n\n", .{});

    // 1. FixedBufferAllocator: Allocation on the stack (or a pre-allocated buffer)
    try stdout.print("1. FixedBufferAllocator (No heap allocation):\n", .{});
    var buffer: [128]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const fba_allocator = fba.allocator();

    const stack_str = try fba_allocator.alloc(u8, 20);
    @memcpy(stack_str[0..14], "Hello from FBA");
    try stdout.print("   Allocated: {s}\n", .{stack_str[0..14]});
    fba_allocator.free(stack_str);


    // 2. Process GPA: The default general purpose allocator
    try stdout.print("\n2. Process GPA (Managed by init):\n", .{});
    const gpa_allocator = init.gpa;

    const gpa_str = try gpa_allocator.alloc(u8, 10);
    @memcpy(gpa_str, "SafeMemory");
    try stdout.print("   Allocated: {s}\n", .{gpa_str});
    
    // In Zig, if we don't free this, the GPA will detect a leak!
    // gpa_allocator.free(gpa_str);


    // 3. ArenaAllocator: Fast allocations, clean up all at once
    try stdout.print("\n3. ArenaAllocator (Batch cleanup):\n", .{});
    // init.arena is already an ArenaAllocator!
    const arena_allocator = init.arena.allocator();

    // We can allocate many things and not worry about freeing them individually
    _ = try arena_allocator.alloc(u8, 100);
    _ = try arena_allocator.alloc(u8, 200);
    const arena_str = try arena_allocator.dupe(u8, "Cleaned up automatically!");
    try stdout.print("   Allocated: {s}\n", .{arena_str});

    try stdout.print("\nDemo finished. GPA will check for leaks upon process exit.\n", .{});
}
