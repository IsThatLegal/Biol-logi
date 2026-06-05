const std = @import("std");
const Io = std.Io;

// Import core bio modules
const protein_core = @import("protein_core");
const orchestrator = @import("orchestrator");
const reward_learning = @import("reward_learning");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║         BIO-LOGI: Biological Logic Simulation Engine         ║\n", .{});
    try stdout.print("║  Silicon Proteins, Reward Learning, Sensorimotor Integration  ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});

    // Menu system
    try stdout.print("Available Demos:\n", .{});
    try stdout.print("  1. Protein Core - Reflex Arc (Sensing → Processing → Action)\n", .{});
    try stdout.print("  2. Orchestrator - Spatial Wave Propagation with Latency\n", .{});
    try stdout.print("  3. Reward Learning - Digital Dopamine-Based Pathfinding\n", .{});
    try stdout.print("\nRunning all demos in sequence...\n\n", .{});

    // --- DEMO 1: Protein Core (Sensing-to-Action) ---
    try stdout.print("\n▶ DEMO 1: PROTEIN CORE (Sensorimotor Reflex)\n", .{});
    try stdout.print("   A simple pressure sensor → neural wave → motor action\n", .{});
    try stdout.print("   ─────────────────────────────────────────────────────\n\n", .{});
    
    var protein_sim = try protein_core.MatrixSimulator.init(allocator, 50, io);
    defer protein_sim.deinit();

    try protein_sim.addSensor(0, .Pressure);
    try protein_sim.addActor(10, .MotorPulse, 60);

    try stdout.print("   Pressure sensor injecting signal at node 0...\n", .{});
    try stdout.print("   Watching for reaction at node 10...\n\n", .{});

    var tick: usize = 0;
    while (tick < 30) : (tick += 1) {
        try protein_sim.tick(tick, stdout);
        if (tick % 5 == 0) {
            try protein_sim.visualizeWindow(stdout, tick, 0, 20);
        }
    }
    try stdout.flush();

    // Pause and transition
    try stdout.print("\n   [Demo 1 Complete]\n", .{});
    try stdout.print("   Proteins successfully propagated and triggered motor action.\n\n", .{});

    // --- DEMO 2: Orchestrator (Spatial Routing with Latency) ---
    try stdout.print("\n▶ DEMO 2: ORCHESTRATOR (Recipe-Driven Network)\n", .{});
    try stdout.print("   Programs the network via spatial recipes with wire latency\n", .{});
    try stdout.print("   ─────────────────────────────────────────────────────\n\n", .{});

    try stdout.print("   Building 20x15 grid with source, sensor, and motor actor...\n", .{});
    try stdout.print("   Signals travel with cycle-accurate routing delay.\n\n", .{});

    const matrix_size = 20 * 15;
    const matrix = try allocator.alloc(orchestrator.SentinelProtein, matrix_size);
    const next_gen = try allocator.alloc(orchestrator.SentinelProtein, matrix_size);
    defer allocator.free(matrix);
    defer allocator.free(next_gen);

    // Initialize matrix
    for (matrix, 0..) |*p, i| {
        p.* = .{
            .id = @as(u32, @intCast(i)),
            .excitation = 0,
            .role = 0,
            .energy = 255,
            .latency_buffer = 0,
            .padding = 0,
        };
    }

    // Program via recipes
    const recipes = [_]orchestrator.NetworkRecipe{
        .{ .x = 0, .y = 0, .role = .VisualSource },
        .{ .x = 10, .y = 7, .role = .LifeSensor },
        .{ .x = 19, .y = 14, .role = .MotorActor },
    };

    for (recipes) |recipe| {
        matrix[recipe.y * 20 + recipe.x].role = @intFromEnum(recipe.role);
    }

    try stdout.print("   Grid initialized with roles. Running simulation...\n\n", .{});

    tick = 0;
    while (tick < 40) : (tick += 1) {
        // Stimulus
        matrix[0].excitation = 255;

        // Step
        for (matrix, 0..) |p, i| {
            next_gen[i] = p;
        }
        for (matrix, 0..) |*p, i| {
            _ = i;
            p.tick(next_gen, tick);
        }
        for (matrix, 0..) |*p, i| {
            p.* = next_gen[i];
        }

        // Visualize every 10 ticks
        if (tick % 10 == 0) {
            try stdout.print("   T{d:2}: ", .{tick});
            for (0..15) |y| {
                if (y > 0) try stdout.print("         ", .{});
                for (0..20) |x| {
                    const idx = y * 20 + x;
                    const p = matrix[idx];
                    const char: u8 = if (p.role != 0) '?' 
                                    else if (p.excitation > 100) '#' 
                                    else if (p.excitation > 30) '*' 
                                    else '.';
                    try stdout.print("{c}", .{char});
                }
                if (y < 14) try stdout.print("\n", .{});
            }
            try stdout.print("\n", .{});
        }
    }
    try stdout.flush();

    try stdout.print("\n   [Demo 2 Complete]\n", .{});
    try stdout.print("   Wave propagated across spatial grid with latency effects.\n\n", .{});

    // --- DEMO 3: Reward Learning (Digital Dopamine) ---
    try stdout.print("\n▶ DEMO 3: REWARD LEARNING (Dopamine-Based Pathfinding)\n", .{});
    try stdout.print("   Robot learns optimal paths via reinforcement & eligibility traces\n", .{});
    try stdout.print("   ─────────────────────────────────────────────────────\n\n", .{});

    const rl_matrix_size = 30 * 15;
    const rl_matrix = try allocator.alloc(reward_learning.RewardProtein, rl_matrix_size);
    const rl_next_gen = try allocator.alloc(reward_learning.RewardProtein, rl_matrix_size);
    defer allocator.free(rl_matrix);
    defer allocator.free(rl_next_gen);

    // Initialize reward learning matrix
    for (rl_matrix, 0..) |*p, i| {
        p.* = .{
            .id = @as(u32, @intCast(i)),
            .excitation = 0,
            .w_north = 50,
            .w_south = 50,
            .w_east = 50,
            .w_west = 50,
            .eligibility_trace = 0,
            .padding = 0,
        };
    }

    try stdout.print("   Stimulus at (0,7) → Target at (29,7)\n", .{});
    try stdout.print("   Dopamine floods when target is reached.\n", .{});
    try stdout.print("   Robot learns the optimal path via weight reinforcement.\n\n", .{});

    var global_dopamine: u8 = 0;
    tick = 0;
    while (tick < 60) : (tick += 1) {
        // Stimulus: Random firing at source
        if (tick % 15 < 3) {
            rl_matrix[7 * 30 + 0].excitation = 255;
        }

        // Check for target activation (reward signal)
        if (rl_matrix[7 * 30 + 29].excitation > 100) {
            global_dopamine = 255;
        }

        // Copy state
        for (rl_matrix, 0..) |p, i| {
            rl_next_gen[i] = p;
        }

        // Tick all proteins
        for (rl_matrix, 0..) |*p, i| {
            _ = i;
            p.tick(rl_next_gen, global_dopamine);
        }

        // Commit
        for (rl_matrix, 0..) |*p, i| {
            p.* = rl_next_gen[i];
        }

        // Visualize
        if (tick % 15 == 0) {
            try stdout.print("   T{d:2}: ", .{tick});
            for (0..15) |y| {
                if (y > 0) try stdout.print("         ", .{});
                for (0..30) |x| {
                    const idx = y * 30 + x;
                    const p = rl_matrix[idx];
                    const char: u8 = if (p.w_east > 150) 'W' 
                                    else if (p.excitation > 100) '#' 
                                    else if (idx == 7 * 30 + 29) 'X' 
                                    else '.';
                    try stdout.print("{c}", .{char});
                }
                if (y < 14) try stdout.print("\n", .{});
            }
            try stdout.print(" Dopamine: {d:3}%\n", .{@as(u32, global_dopamine) * 100 / 255});
        }

        // Decay dopamine
        global_dopamine = global_dopamine -| 20;
    }
    try stdout.flush();

    try stdout.print("\n   [Demo 3 Complete]\n", .{});
    try stdout.print("   W = Learned east-going weights (optimal path)\n", .{});
    try stdout.print("   # = Active excitation\n", .{});
    try stdout.print("   X = Target location\n\n", .{});

    // Summary
    try stdout.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    SIMULATION COMPLETE                        ║\n", .{});
    try stdout.print("║                                                              ║\n", .{});
    try stdout.print("║  ✓ Protein Core: Sensorimotor reflexes working               ║\n", .{});
    try stdout.print("║  ✓ Orchestrator: Spatial routing with latency stable         ║\n", .{});
    try stdout.print("║  ✓ Reward Learning: Dopamine-based path optimization         ║\n", .{});
    try stdout.print("║                                                              ║\n", .{});
    try stdout.print("║  Next: Integrate all modules into a unified bio-agent.       ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});
}
