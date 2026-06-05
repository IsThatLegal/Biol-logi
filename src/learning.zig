const std = @import("std");
const Io = std.Io;

const CONFIG = struct {
    pub const WIDTH: usize = 30;
    pub const HEIGHT: usize = 15;
    pub const TICK_LIMIT: usize = 300;
};

/// The Learning Sentinel Protein.
/// Implements Local Synaptic Plasticity using Hebbian rules.
pub const LearningProtein = packed struct {
    id: u32,
    excitation: u8,
    energy: u8,
    
    // --- Local Connection Weights (The "Learning" memory) ---
    // These represent the strength of the physical 'wires' to neighbors.
    w_north: u8,
    w_south: u8,
    w_east: u8,
    w_west: u8,

    // Timing Trace: When did this node last fire?
    last_fired: u16,

    padding: u160,

    comptime {
        if (@bitSizeOf(LearningProtein) != 256) {
            @compileError("LearningProtein struct must be exactly 256 bits for FPGA alignment");
        }
    }

    pub fn tick(self: LearningProtein, next_gen_all: []LearningProtein, matrix: []LearningProtein, current_tick: usize) void {
        const self_idx = @as(usize, @intCast(self.id));
        const next = &next_gen_all[self_idx];

        // Action Potential Spike threshold: if excitation is above 100, we spike to 255
        const is_spiking = self.excitation > 100;
        const active_excitation: u8 = if (is_spiking) 255 else self.excitation;

        // 1. PROPAGATION (Weighted by local memory)
        if (active_excitation > 50) {
            const signal = @as(i32, @intCast(active_excitation)) - 10;
            const neighbors = [_][2]i32{ .{0,-1}, .{0,1}, .{1,0}, .{-1,0} }; // N, S, E, W
            const weights = [_]u8{ self.w_north, self.w_south, self.w_east, self.w_west };

            for (neighbors, 0..) |n, i| {
                // Modified Signal: Signal Strength * Connection Weight
                const weighted_signal = @divTrunc(signal * @as(i32, @intCast(weights[i])), 255);
                this.spread(next_gen_all, self.id, weighted_signal, n);
            }
        }

        if (is_spiking) {
            next.last_fired = @as(u16, @intCast(current_tick));
        }

        // 2. STDP LEARNING: Causal timing strengthens, non-causal weakens.
        if (is_spiking) {
            this.updateWeights(next_gen_all, matrix, self.id, current_tick);
        }

        // 3. DECAY & FORGETTING / REPOLARIZATION
        if (is_spiking) {
            next.excitation = 0; // Repolarize after firing
        } else {
            next.excitation = (next.excitation -| self.excitation) +| (self.excitation -| 15);
        }

        // Natural weight decay (prevents permanent obsessions)
        if (current_tick % 50 == 0) {
            next.w_north = next.w_north -| 1;
            next.w_south = next.w_south -| 1;
            next.w_east = next.w_east -| 1;
            next.w_west = next.w_west -| 1;
        }
    }

    fn updateWeights(next_gen: []LearningProtein, matrix: []LearningProtein, id: u32, t: usize) void {
        _ = t;
        const x = id % CONFIG.WIDTH;
        const y = id / CONFIG.WIDTH;
        const next_self = &next_gen[id];
        const self_last_fired = matrix[id].last_fired;
        const neighbors = [_][2]i32{ .{0,-1}, .{0,1}, .{1,0}, .{-1,0} };
        
        for (neighbors, 0..) |n, i| {
            const nx = @as(i64, @intCast(x)) + n[0];
            const ny = @as(i64, @intCast(y)) + n[1];
            if (nx >= 0 and nx < CONFIG.WIDTH and ny >= 0 and ny < CONFIG.HEIGHT) {
                const target_idx = @as(usize, @intCast(ny * CONFIG.WIDTH + nx));
                const target = matrix[target_idx];
                
                if (target.last_fired > self_last_fired and target.last_fired - self_last_fired <= 3) {
                    switch (i) {
                        0 => next_self.w_north = next_self.w_north +| 25,
                        1 => next_self.w_south = next_self.w_south +| 25,
                        2 => next_self.w_east = next_self.w_east +| 25,
                        3 => next_self.w_west = next_self.w_west +| 25,
                        else => {},
                    }
                }
                // 2. LTD (Non-causal): Neighbor fired before me -> Weaken my output weight to them
                else if (target.last_fired < self_last_fired and self_last_fired - target.last_fired <= 3) {
                    switch (i) {
                        0 => next_self.w_north = next_self.w_north -| 15,
                        1 => next_self.w_south = next_self.w_south -| 15,
                        2 => next_self.w_east = next_self.w_east -| 15,
                        3 => next_self.w_west = next_self.w_west -| 15,
                        else => {},
                    }
                }
            }
        }
    }

    fn spread(next_gen: []LearningProtein, id: u32, val: i32, n: [2]i32) void {
        const x = id % CONFIG.WIDTH;
        const y = id / CONFIG.WIDTH;
        const nx = @as(i64, @intCast(x)) + n[0];
        const ny = @as(i64, @intCast(y)) + n[1];
        if (nx >= 0 and nx < CONFIG.WIDTH and ny >= 0 and ny < CONFIG.HEIGHT) {
            const target = @as(usize, @intCast(ny * CONFIG.WIDTH + nx));
            next_gen[target].excitation = next_gen[target].excitation +| @as(u8, @intCast(@max(0, val)));
        }
    }
};

const this = LearningProtein;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const count = CONFIG.WIDTH * CONFIG.HEIGHT;
    const matrix = try init.gpa.alloc(LearningProtein, count);
    const next_gen = try init.gpa.alloc(LearningProtein, count);
    defer init.gpa.free(matrix);
    defer init.gpa.free(next_gen);

    // Init: All weights start at 128 (Neutral)
    for (matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .energy = 255, .w_north = 128, .w_south = 128, .w_east = 128, .w_west = 128, .last_fired = 0, .padding = 0 };
    }

    try stdout.print("\x1B[2J", .{}); 
    var t: usize = 0;
    while (t < CONFIG.TICK_LIMIT) : (t += 1) {
        try stdout.print("\x1B[H", .{});
        try stdout.print("--- LEARNING TEST: Synaptic Plasticity --- \n", .{});
        try stdout.print("Tick: {d: >3} | Method: Hebbian Path Reinforcement\n\n", .{t});

        // SIMULATION: Repeated causal stimulus from Node (10, 5) to (11, 5)
        // Node 10 is stimulated first, and Node 11 is stimulated 1 tick later.
        if (t % 10 == 0) {
             matrix[5 * CONFIG.WIDTH + 10].excitation = 255;
        } else if (t % 10 == 1) {
             matrix[5 * CONFIG.WIDTH + 11].excitation = 255;
        }

        // Logic
        for (matrix, 0..) |p, i| next_gen[i] = p;
        for (matrix) |p| p.tick(next_gen, matrix, t);
        for (matrix, 0..) |*p, i| p.* = next_gen[i];

        // Draw WEIGHT Map (W = Strong path, . = Neutral)
        var y: usize = 0;
        while (y < CONFIG.HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < CONFIG.WIDTH) : (x += 1) {
                const p = matrix[y * CONFIG.WIDTH + x];
                const char: u8 = if (p.w_east > 200 or p.w_west > 200) 'W' // PATH LEARNED
                               else if (p.excitation > 100) '#' 
                               else '.';
                try stdout.print("{c} ", .{char});
            }
            try stdout.print("\n", .{});
        }

        if (matrix[5 * CONFIG.WIDTH + 10].w_east > 200) {
            try stdout.print("\n>>> KNOWLEDGE ACQUIRED: Path Reinforcement Success <<<\n", .{});
        } else {
            try stdout.print("\nPracticing stimulus... (Weight Building) | Node 160 w_east = {d}\n", .{matrix[5 * CONFIG.WIDTH + 10].w_east});
        }

        try stdout.flush();
        try Io.sleep(io, .{ .nanoseconds = 30 * std.time.ns_per_ms }, .awake);
    }
}

test "LearningProtein size and basic STDP" {
    const count = CONFIG.WIDTH * CONFIG.HEIGHT;
    var matrix: [count]LearningProtein = undefined;
    for (&matrix, 0..) |*p, i| {
        p.* = .{ .id = @as(u32, @intCast(i)), .excitation = 0, .energy = 255, .w_north = 128, .w_south = 128, .w_east = 128, .w_west = 128, .last_fired = 0, .padding = 0 };
    }
    var next_gen = matrix;
    
    const node_idx = 5 * CONFIG.WIDTH + 10;
    const east_idx = 5 * CONFIG.WIDTH + 11;

    // t=0: Node 160 spikes
    matrix[node_idx].excitation = 255;
    for (matrix, 0..) |p, i| next_gen[i] = p;
    matrix[node_idx].tick(&next_gen, &matrix, 0);
    matrix = next_gen;
    
    // t=1: Node 161 spikes
    matrix[east_idx].excitation = 255;
    for (matrix, 0..) |p, i| next_gen[i] = p;
    matrix[east_idx].tick(&next_gen, &matrix, 1);
    matrix = next_gen;
    
    // t=10: Node 160 spikes again
    matrix[node_idx].excitation = 255;
    for (matrix, 0..) |p, i| next_gen[i] = p;
    matrix[node_idx].tick(&next_gen, &matrix, 10);
    
    // Node 160 should strengthen its east weight towards Node 161
    try std.testing.expect(next_gen[node_idx].w_east > 128);
}
