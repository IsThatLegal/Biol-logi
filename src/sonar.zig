const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const NODE_COUNT: usize = 40;
    pub const TICK_LIMIT: usize = 60;
};

pub const ProteinRole = enum(u8) {
    Standard = 0,
    Emitter = 1,
    Obstacle = 2,
};

pub const SonarProtein = packed struct {
    id: u32,
    role: u8,
    excitation: u8,      
    timer: u8,           
    distance_map: u8,    
    is_echoing: bool,
    padding: u63,

    comptime {
        if (@bitSizeOf(SonarProtein) != 128) {
            @compileError("SonarProtein struct must be exactly 128 bits for FPGA alignment");
        }
    }

    pub fn tick(self: *SonarProtein, next_gen_all: []SonarProtein, current_gen_all: []SonarProtein) void {
        const role = @as(ProteinRole, @enumFromInt(self.role));

        // Refractory decrement for standard nodes
        if (role == .Standard) {
            const next_std = &next_gen_all[self.id];
            if (self.timer > 0) {
                next_std.timer = self.timer - 1;
            }
        }

        // 1. Propagation Logic
        if (self.excitation > 50) {
            const signal = self.excitation -| 4;
            
            if (role == .Obstacle) {
                // REFLECT: Send back to where it came from
                self.exciteNeighbor(next_gen_all, -1, signal);
            } else if (role == .Emitter) {
                // Emitter only propagates the initial pulse, does not propagate echo backwards
                if (self.timer == 0) {
                    self.exciteNeighbor(next_gen_all, 1, signal);
                }
            } else {
                // PROPAGATE: Standard wave movement
                self.exciteNeighbor(next_gen_all, 1, signal);
                self.exciteNeighbor(next_gen_all, -1, signal);
            }
        }

        // 2. Sonar Logic (Emitter specific)
        if (role == .Emitter) {
            const next_emitter = &next_gen_all[self.id];
            if (self.is_echoing) {
                next_emitter.timer = self.timer +| 1;
                // If we receive a signal while echoing (from the echo return), record distance
                if (self.excitation > 50 and self.timer > 8) {
                    next_emitter.distance_map = self.timer - 1;
                    next_emitter.is_echoing = false;
                }
            }
        }

        // 3. Natural Decay
        const decay_val: u8 = if (role == .Obstacle) 0 else 140;
        next_gen_all[self.id].excitation = (next_gen_all[self.id].excitation -| self.excitation) +| (self.excitation -| decay_val);
        _ = current_gen_all;
    }

    fn exciteNeighbor(self: SonarProtein, next_gen_all: []SonarProtein, offset: i32, val: u8) void {
        const target_idx = @as(i64, @intCast(self.id)) + offset;
        if (target_idx >= 0 and target_idx < @as(i64, @intCast(CONFIG.NODE_COUNT))) {
            const idx = @as(usize, @intCast(target_idx));
            if (next_gen_all[idx].timer == 0 or next_gen_all[idx].role == @intFromEnum(ProteinRole.Emitter)) {
                if (next_gen_all[idx].excitation < val) {
                    next_gen_all[idx].excitation = val;
                }
                if (next_gen_all[idx].role == @intFromEnum(ProteinRole.Standard)) {
                    next_gen_all[idx].timer = 3; // 3 ticks of refractory period
                }
            }
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("--- Bio-Logi: Decentralized Sonar (Echolocation) ---\n", .{});

    var matrix = try init.gpa.alloc(SonarProtein, CONFIG.NODE_COUNT);
    var next_gen = try init.gpa.alloc(SonarProtein, CONFIG.NODE_COUNT);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    for (matrix, 0..) |*p, i| {
        p.* = .{
            .id = @as(u32, @intCast(i)),
            .role = @intFromEnum(ProteinRole.Standard),
            .excitation = 0,
            .timer = 0,
            .distance_map = 0,
            .is_echoing = false,
            .padding = 0,
        };
    }

    matrix[0].role = @intFromEnum(ProteinRole.Emitter);
    const obstacle_pos = 18;
    matrix[obstacle_pos].role = @intFromEnum(ProteinRole.Obstacle);

    try stdout.print("Emitter at Node 0, Obstacle at Node {d}.\n", .{obstacle_pos});
    matrix[0].excitation = 255;
    matrix[0].is_echoing = true;

    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("{d: >2}: ", .{t});
        for (matrix) |p| {
            const char: u8 = if (@as(ProteinRole, @enumFromInt(p.role)) == .Obstacle) 'X' 
                           else if (p.excitation > 200) '#' 
                           else if (p.excitation > 100) '*' 
                           else if (p.excitation > 50) '+' 
                           else '.';
            try stdout.print("{c}", .{char});
        }
        
        if (matrix[0].distance_map > 0) {
            try stdout.print(" [ECHO RECEIVED! DISTANCE: {d}]", .{matrix[0].distance_map});
        }
        try stdout.print("\n", .{});

        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix, 0..) |*p, i| {
            _ = i;
            p.tick(next_gen, matrix);
        }
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }

    try stdout.print("\nSonar Simulation Complete. Decentralized Spatial Mapping Successful.\n", .{});
}

test "SonarProtein size and basic tick" {
    var matrix = [_]SonarProtein{
        .{ .id = 0, .role = @intFromEnum(ProteinRole.Emitter), .excitation = 255, .timer = 0, .distance_map = 0, .is_echoing = true, .padding = 0 },
        .{ .id = 1, .role = @intFromEnum(ProteinRole.Standard), .excitation = 0, .timer = 0, .distance_map = 0, .is_echoing = false, .padding = 0 },
        .{ .id = 2, .role = @intFromEnum(ProteinRole.Standard), .excitation = 0, .timer = 0, .distance_map = 0, .is_echoing = false, .padding = 0 },
    };
    var next_gen = matrix;
    
    matrix[0].tick(&next_gen, &matrix);
    matrix[1].tick(&next_gen, &matrix);
    
    // Wave should propagate from Emitter to Node 1
    try std.testing.expect(next_gen[1].excitation > 0);
}
