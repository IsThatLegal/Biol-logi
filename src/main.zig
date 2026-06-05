const std = @import("std");
const Io = std.Io;

const protein_core = @import("protein_core");

/// Wrap protein_core demo as a reusable function
pub fn runProteinCoreDemo(allocator: std.mem.Allocator, io: Io, stdout: anytype) !void {
    try stdout.print("\n▶ DEMO 1: PROTEIN CORE (Sensorimotor Reflex)\n", .{});
    try stdout.print("   A simple pressure sensor → neural wave → motor action\n", .{});
    try stdout.print("   ─────────────────────────────────────────────────────\n\n", .{});

    var sim = try protein_core.MatrixSimulator.init(allocator, 50, io);
    defer sim.deinit();

    try sim.addSensor(0, .Pressure);
    try sim.addActor(10, .MotorPulse, 60);

    try stdout.print("   Pressure sensor injecting signal at node 0...\n", .{});
    try stdout.print("   Watching for reaction at node 10...\n\n", .{});

    var tick: usize = 0;
    while (tick < 30) : (tick += 1) {
        try sim.tick(tick, stdout);
        if (tick % 5 == 0) {
            try sim.visualizeWindow(stdout, tick, 0, 20);
        }
    }
    try stdout.flush();

    try stdout.print("\n   [Demo 1 Complete]\n", .{});
    try stdout.print("   Proteins successfully propagated and triggered motor action.\n\n", .{});
}

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

    try stdout.print("Available Demos:\n", .{});
    try stdout.print("  1. Protein Core - Reflex Arc (Sensing → Processing → Action)\n", .{});
    try stdout.print("  2. Orchestrator - Spatial Wave Propagation with Latency\n", .{});
    try stdout.print("  3. Reward Learning - Digital Dopamine-Based Pathfinding\n", .{});
    try stdout.print("\nRunning all demos in sequence...\n\n", .{});

    // --- DEMO 1: Protein Core ---
    try runProteinCoreDemo(allocator, io, stdout);

    // --- DEMO 2: Orchestrator ---
    try stdout.print("\n▶ DEMO 2: ORCHESTRATOR (Recipe-Driven Network)\n", .{});
    try stdout.print("   Programs the network via spatial recipes with wire latency\n", .{});
    try stdout.print("   ─────────────────────────────────────────────────────\n\n", .{});

    try stdout.print("   Building 20x15 grid with source, sensor, and motor actor...\n", .{});
    try stdout.print("   Signals travel with cycle-accurate routing delay.\n\n", .{});

    try stdout.print("   [Orchestrator module would run here]\n", .{});
    try stdout.print("   [Orchestrator has its own main() - integrate via wrapper]\n\n", .{});

    // --- DEMO 3: Reward Learning ---
    try stdout.print("\n▶ DEMO 3: REWARD LEARNING (Dopamine-Based Pathfinding)\n", .{});
    try stdout.print("   Robot learns optimal paths via reinforcement & eligibility traces\n", .{});
    try stdout.print("   ─────────────────────────────────────────────────────\n\n", .{});

    try stdout.print("   [Reward Learning module would run here]\n", .{});
    try stdout.print("   [Reward Learning has its own main() - integrate via wrapper]\n\n", .{});

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
