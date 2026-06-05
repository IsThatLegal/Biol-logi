const std = @import("std");
const Io = std.Io;

// --- Constants & Config ---
const CONFIG = struct {
    pub const NODE_COUNT: usize = 1000;
    pub const TICK_LIMIT: usize = 100;
    pub const PROTEIN_SIZE_BYTES: usize = 16;
    pub const DECAY_RATE: u8 = 2;
    pub const TRANSFER_LOSS: u8 = 10;
};

// --- Error Definitions ---
pub const SimulationError = error{
    OutOfBoundsNeighbor,
    AllocationFailed,
    InvalidNodeState,
};

/// The "Silicon Protein" - A decentralized logic cell.
/// Packed to exactly 128 bits (16 bytes) for bit-perfect FPGA alignment.
pub const Protein = packed struct {
    id: u32,
    energy: u8,
    excitation: u8,
    threshold: u8,
    role: u8,
    neighbor_a: i32,
    neighbor_b: i32,

    // Comptime check to ensure hardware alignment
    comptime {
        if (@sizeOf(Protein) != CONFIG.PROTEIN_SIZE_BYTES) {
            @compileError("Protein struct must be exactly 16 bytes for FPGA alignment");
        }
    }

    /// Pure function for state transition: calculates the contribution to neighbors.
    pub fn calculateContribution(self: Protein, neighbors_len: usize, next_gen: []u8) void {
        if (self.excitation > self.threshold) {
            const signal = self.excitation -| CONFIG.TRANSFER_LOSS;
            
            self.addToNext(self.neighbor_a, signal, neighbors_len, next_gen);
            self.addToNext(self.neighbor_b, signal, neighbors_len, next_gen);
        } else if (self.excitation > CONFIG.DECAY_RATE) {
            // Sustain and Decay locally
            const self_idx = @as(usize, @intCast(self.id));
            const decayed = self.excitation -| CONFIG.DECAY_RATE;
            if (next_gen[self_idx] < decayed) {
                next_gen[self_idx] = decayed;
            }
        }
    }

    fn addToNext(self: Protein, target_idx: i32, val: u8, neighbors_len: usize, next_gen: []u8) void {
        _ = self;
        if (target_idx >= 0 and target_idx < neighbors_len) {
            const idx = @as(usize, @intCast(target_idx));
            next_gen[idx] = next_gen[idx] +| val; // Saturating add
        }
    }
};

// --- Sensor Definitions ---
pub const SensorKind = enum {
    Thermal,
    Pressure,
    Proximity,
    RandomNoise,
};

pub const MockSensor = struct {
    target_id: u32,
    kind: SensorKind,
    phase: f32 = 0.0,

    pub fn getValue(self: *MockSensor, tick_num: usize) u8 {
        switch (self.kind) {
            .Thermal => {
                const val = (std.math.sin(self.phase) + 1.0) * 127.0;
                self.phase += 0.1;
                return @as(u8, @intFromFloat(val));
            },
            .Pressure => {
                return if (tick_num % 10 == 0) 200 else 0;
            },
            .Proximity => {
                return if (tick_num % 15 > 12) 250 else 20;
            },
            .RandomNoise => {
                var prng = std.Random.DefaultPrng.init(tick_num);
                const random = prng.random();
                return random.uintAtMost(u8, 50);
            },
        }
    }
};

// --- Actor Definitions ---
pub const ActorKind = enum {
    MotorPulse,
    BalanceCorrection,
    AlertSignal,
};

pub const MockActor = struct {
    protein_id: u32,
    kind: ActorKind,
    activation_threshold: u8,
    triggered_count: usize = 0,

    pub fn process(self: *MockActor, protein: Protein, stdout: anytype, tick_num: usize) !void {
        if (protein.excitation >= self.activation_threshold) {
            self.triggered_count += 1;
            switch (self.kind) {
                .MotorPulse => {
                    try stdout.print("[ACTOR] Tick {d: >2}: High Pressure at Node {d}! Triggering Motor Reflex.\n", .{ tick_num, self.protein_id });
                },
                .BalanceCorrection => {
                    try stdout.print("[ACTOR] Tick {d: >2}: Wave at Node {d} triggering Balance Correction.\n", .{ tick_num, self.protein_id });
                },
                .AlertSignal => {
                    try stdout.print("[ACTOR] Tick {d: >2}: Alert at Node {d}!\n", .{ tick_num, self.protein_id });
                },
            }
        }
    }
};

/// The Simulation Engine
pub const MatrixSimulator = struct {
    allocator: std.mem.Allocator,
    matrix: []Protein,
    next_gen: []u8,
    sensors: std.ArrayListUnmanaged(MockSensor),
    actors: std.ArrayListUnmanaged(MockActor),
    io: Io,

    pub fn init(allocator: std.mem.Allocator, node_count: usize, io: Io) SimulationError!MatrixSimulator {
        const matrix = allocator.alloc(Protein, node_count) catch return error.AllocationFailed;
        const next_gen = allocator.alloc(u8, node_count) catch {
            allocator.free(matrix);
            return error.AllocationFailed;
        };

        var self = MatrixSimulator{
            .allocator = allocator,
            .matrix = matrix,
            .next_gen = next_gen,
            .sensors = .empty,
            .actors = .empty,
            .io = io,
        };

        self.reset();
        return self;
    }

    pub fn deinit(self: *MatrixSimulator) void {
        self.allocator.free(self.matrix);
        self.allocator.free(self.next_gen);
        self.sensors.deinit(self.allocator);
        self.actors.deinit(self.allocator);
    }

    pub fn addSensor(self: *MatrixSimulator, target_id: u32, kind: SensorKind) !void {
        try self.sensors.append(self.allocator, .{ .target_id = target_id, .kind = kind });
    }

    pub fn addActor(self: *MatrixSimulator, protein_id: u32, kind: ActorKind, threshold: u8) !void {
        try self.actors.append(self.allocator, .{ 
            .protein_id = protein_id, 
            .kind = kind, 
            .activation_threshold = threshold 
        });
    }

    pub fn reset(self: *MatrixSimulator) void {
        for (self.matrix, 0..) |*p, i| {
            p.* = .{
                .id = @as(u32, @intCast(i)),
                .energy = 255,
                .excitation = 0,
                .threshold = 30,
                .role = 1,
                .neighbor_a = @as(i32, @intCast(i)) + 1,
                .neighbor_b = @as(i32, @intCast(i)) - 1,
            };
            self.next_gen[i] = 0;
        }
    }

    pub fn tick(self: *MatrixSimulator, tick_num: usize, stdout: anytype) !void {
        // 1. Inject Sensor Data
        for (self.sensors.items) |*sensor| {
            const val = sensor.getValue(tick_num);
            const target = &self.matrix[@as(usize, @intCast(sensor.target_id))];
            target.excitation = target.excitation +| val;
        }

        // 2. Compute local interactions
        for (self.next_gen) |*val| val.* = 0;
        for (self.matrix) |p| {
            p.calculateContribution(self.matrix.len, self.next_gen);
        }

        // 3. Commit state changes
        for (self.matrix, 0..) |*p, i| {
            p.excitation = self.next_gen[i];
        }

        // 4. Process Actors
        for (self.actors.items) |*actor| {
            const p = self.matrix[@as(usize, @intCast(actor.protein_id))];
            try actor.process(p, stdout, tick_num);
        }
    }

    pub fn visualizeWindow(self: MatrixSimulator, stdout: anytype, tick_num: usize, start: usize, len: usize) !void {
        try stdout.print("{d: >2}: ", .{tick_num});
        const end = @min(start + len, self.matrix.len);
        for (self.matrix[start..end]) |p| {
            const char: u8 = if (p.excitation > 150) '#' else if (p.excitation > 80) '*' else if (p.excitation > 30) '+' else ' ';
            try stdout.print("{c}", .{char});
        }
        try stdout.print("...\n", .{});
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- Silicon Protein: Sensing-to-Action Reflex Demo ---\n", .{});

    var sim = try MatrixSimulator.init(init.gpa, CONFIG.NODE_COUNT, io);
    defer sim.deinit();

    // Attach sensors
    try sim.addSensor(0, .Thermal);
    const pressure_sensor_id = CONFIG.NODE_COUNT / 2;
    try sim.addSensor(@as(u32, @intCast(pressure_sensor_id)), .Pressure);

    // Attach an ACTOR downstream from the pressure sensor
    // Node (pressure_sensor_id + 5) will trigger once the wave reaches it
    const actor_id = pressure_sensor_id + 5;
    try sim.addActor(@as(u32, @intCast(actor_id)), .MotorPulse, 50);

    try stdout.print("Pressure sensor at node {d}, Actor watching node {d}.\n", .{ pressure_sensor_id, actor_id });
    try stdout.print("Simulating reaction wave...\n", .{});

    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try sim.tick(t, stdout);
        
        // Visualize the window around the pressure sensor and actor
        if (t % 10 == 0 or t % 10 < 5) {
            try sim.visualizeWindow(stdout, t, pressure_sensor_id, 20);
        }
    }

    try stdout.print("\nReflex Simulation Complete.\n", .{});
}

// Add this to MatrixSimulator struct in next turn or via replace

// --- Unit Tests ---
test "Protein saturating math" {
    const allocator = std.testing.allocator;
    const next_gen = try allocator.alloc(u8, 1);
    defer allocator.free(next_gen);
    next_gen[0] = 200;

    const p = Protein{
        .id = 0,
        .energy = 255,
        .excitation = 200,
        .threshold = 50,
        .role = 1,
        .neighbor_a = 0,
        .neighbor_b = 0,
    };

    p.calculateContribution(1, next_gen);
    try std.testing.expectEqual(@as(u8, 255), next_gen[0]);
}

test "Wave propagation timing" {
    const allocator = std.testing.allocator;
    const io = (std.process.Init{
        .minimal = undefined,
        .arena = undefined,
        .gpa = undefined,
        .io = undefined,
        .environ_map = undefined,
        .preopens = std.process.Preopens.empty,
    }).io;

    var sim = try MatrixSimulator.init(allocator, 5, io);
    defer sim.deinit();

    sim.matrix[0].excitation = 100;

    // A simple mock writer that does nothing
    const MockWriter = struct {
        pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
            _ = self; _ = fmt; _ = args;
        }
    };
    const mock_writer = MockWriter{};

    try sim.tick(0, mock_writer);
    try std.testing.expect(sim.matrix[1].excitation > 0);
    
    try sim.tick(1, mock_writer);
    try std.testing.expect(sim.matrix[2].excitation > 0);
}

test "Boundary safety (Edge nodes)" {
    const allocator = std.testing.allocator;
    const next_gen = try allocator.alloc(u8, 2);
    defer allocator.free(next_gen);

    const p = Protein{
        .id = 0,
        .energy = 255,
        .excitation = 100,
        .threshold = 10,
        .role = 1,
        .neighbor_a = -1,
        .neighbor_b = 99,
    };

    p.calculateContribution(2, next_gen);
}

test "Signal decay" {
    const allocator = std.testing.allocator;
    const next_gen = try allocator.alloc(u8, 1);
    defer allocator.free(next_gen);
    next_gen[0] = 0;
    
    const p = Protein{
        .id = 0,
        .energy = 255,
        .excitation = 20,
        .threshold = 30,
        .role = 1,
        .neighbor_a = -1,
        .neighbor_b = -1,
    };

    p.calculateContribution(1, next_gen);
    try std.testing.expectEqual(@as(u8, 18), next_gen[0]);
}
