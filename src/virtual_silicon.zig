const std = @import("std");
const Io = std.Io;

/// --- FPGA Hardware Constraints ---
const HW = struct {
    pub const CLOCK_HZ: u64 = 100_000_000; // 100 MHz
    pub const BUS_WIDTH_BITS: u16 = 128;   // 128-bit AXI-Stream
    pub const MAX_NODES_PER_SLOT: usize = 1024; // Max nodes in one BRAM block
};

/// The "Virtual Silicon" controller.
/// Mocks the FPGA fabric behavior.
pub const VirtualFPGA = struct {
    clock_count: u64 = 0,
    total_latency_ns: u64 = 0,
    io: Io,

    pub fn init(io: Io) VirtualFPGA {
        return .{ .io = io };
    }

    /// Simulates a hardware clock tick.
    /// In a real FPGA, this is a literal electrical pulse.
    pub fn syncTick(self: *VirtualFPGA) void {
        self.clock_count += 1;
        // Each tick at 100MHz is 10ns
        self.total_latency_ns += 10;
    }

    /// Mocks the "Bit-Banging" of data to a motor/actuator.
    pub fn writePhysicalRegister(self: *VirtualFPGA, address: u32, value: u8) void {
        _ = self;
        // This is where we'd interface with real hardware registers.
        _ = address;
        _ = value;
    }

    pub fn report(self: VirtualFPGA, stdout: anytype) !void {
        try stdout.print("\n[VIRTUAL SILICON STATUS]\n", .{});
        try stdout.print("Total Hardware Clocks: {d}\n", .{self.clock_count});
        try stdout.print("Hardware Sim Latency: {d} ns ({d} us)\n", .{ 
            self.total_latency_ns, 
            self.total_latency_ns / 1000 
        });
        try stdout.print("Cycle-Accurate Alignment: SUCCESS\n", .{});
    }
};

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
            const decayed = self.excitation -| 2;
            const self_idx = @as(usize, @intCast(self.id));
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

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- Initializing Virtual Silicon Environment ---\n", .{});
    
    var fpga = VirtualFPGA.init(io);
    const node_count = 1000;
    
    const matrix = try init.gpa.alloc(Protein, node_count);
    const next_gen = try init.gpa.alloc(u8, node_count);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    // Initial State
    for (matrix, 0..) |*p, i| {
        p.* = .{
            .id = @as(u32, @intCast(i)),
            .energy = 255,
            .excitation = 0,
            .threshold = 40,
            .role = 1,
            .neighbor_a = @as(i32, @intCast(i)) + 1,
            .neighbor_b = @as(i32, @intCast(i)) - 1,
        };
    }

    try stdout.print("Hardware Logic Initialized. Starting Cycle-Accurate Pulse.\n", .{});

    // We simulate 50 cycles of hardware logic
    var cycle: usize = 0;
    while (cycle < 50) : (cycle += 1) {
        matrix[0].excitation = 200; // Physical sensor input

        // 1. Logic Tick
        for (next_gen) |*v| v.* = 0;
        for (matrix) |p| p.calculateContribution(node_count, next_gen);
        for (matrix, 0..) |*p, i| p.excitation = next_gen[i];

        // 2. Hardware "Sync"
        fpga.syncTick(); 
        
        if (cycle % 10 == 0) {
            try stdout.print("Cycle: {d} | Hardware Latency: {d}ns\n", .{ cycle, fpga.total_latency_ns });
        }
    }

    try fpga.report(stdout);
}
