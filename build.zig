const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create modules for all bio-system components
    const protein_core_mod = b.addModule("protein_core", .{
        .root_source_file = b.path("src/protein_core.zig"),
        .target = target,
    });

    const orchestrator_mod = b.addModule("orchestrator", .{
        .root_source_file = b.path("src/orchestrator.zig"),
        .target = target,
    });

    const reward_learning_mod = b.addModule("reward_learning", .{
        .root_source_file = b.path("src/reward_learning.zig"),
        .target = target,
    });

    const sentinel_mod = b.addModule("sentinel", .{
        .root_source_file = b.path("src/sentinel.zig"),
        .target = target,
    });

    // Create the main executable with all bio modules available
    const exe = b.addExecutable(.{
        .name = "biol-logi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "protein_core", .module = protein_core_mod },
                .{ .name = "orchestrator", .module = orchestrator_mod },
                .{ .name = "reward_learning", .module = reward_learning_mod },
                .{ .name = "sentinel", .module = sentinel_mod },
            },
        }),
    });

    b.installArtifact(exe);

    // Run step
    const run_step = b.step("run", "Run the bio-logi simulation");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Test step for individual modules
    const test_step = b.step("test", "Run all tests");

    // Tests for protein_core
    const protein_core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/protein_core.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_protein_core_tests = b.addRunArtifact(protein_core_tests);
    test_step.dependOn(&run_protein_core_tests.step);

    // Tests for orchestrator
    const orchestrator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/orchestrator.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_orchestrator_tests = b.addRunArtifact(orchestrator_tests);
    test_step.dependOn(&run_orchestrator_tests.step);

    // Tests for reward_learning
    const reward_learning_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/reward_learning.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_reward_learning_tests = b.addRunArtifact(reward_learning_tests);
    test_step.dependOn(&run_reward_learning_tests.step);
}
