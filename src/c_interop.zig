const std = @import("std");
const Io = std.Io;

// This is the "magic" part: Zig parses the C header directly!
const c = @cImport({
    @cInclude("math.h");
    @cInclude("stdio.h");
});

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- Zig C Interop Demo ---\n\n", .{});

    // Calling a C function (sin) from math.h
    const angle = 45.0;
    const radians = angle * (c.M_PI / 180.0);
    const sine_val = c.sin(radians);

    try stdout.print("C math.h: sin({d} degrees) = {d:.4}\n", .{ angle, sine_val });

    // Using a C constant
    try stdout.print("C PI Constant: {d:.10}\n", .{c.M_PI});

    // We can even use C's printf if we wanted to (though it's not idiomatic)
    _ = c.printf("Hello from C's printf! (called from Zig)\n");
}
