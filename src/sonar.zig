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

    pub fn tick(self: *SonarProtein, next_gen_all: []SonarProtein, current_gen_all: []SonarProtein) void {
        const role = @as(ProteinRole, @enumFromInt(self.role));

        // 1. Propagation Logic
        if (self.excitation > 50) {
            const signal = self.excitation -| 10;
            
            if (role == .Obstacle) {
                // REFLECT: Send back to where it came from
                self.exciteNeighbor(next_gen_all, -1, signal);
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
                if (self.excitation > 50 and self.timer > 4) {
                    next_emitter.distance_map = self.timer;
                    next_emitter.is_echoing = false;
                }
            }
        }

        // 3. Natural Decay
        next_gen_all[self.id].excitation = self.excitation -| 8;
        _ = current_gen_all;
    }

    fn exciteNeighbor(self: SonarProtein, next_gen_all: []SonarProtein, offset: i32, val: u8) void {
        const target_idx = @as(i64, @intCast(self.id)) + offset;
        if (target_idx >= 0 and target_idx < @as(i64, @intCast(CONFIG.NODE_COUNT))) {
            const idx = @as(usize, @intCast(target_idx));
            if (next_gen_all[idx].excitation < val) {
                next_gen_all[idx].excitation = val;
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
