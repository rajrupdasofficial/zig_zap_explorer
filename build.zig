const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // PostgreSQL Dependency
    const pg_dep = b.dependency("pg", .{
        .target = target,
        .optimize = optimize,
    });

    // HTTP Server Dependency (Zap)
    const zap_dep = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });

    // Main Executable
    const exe = b.addExecutable(.{
        .name = "user_service",
        // Use b.path() instead of .{ .path = ... }
        .root_source_file = b.path("src/server.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link Dependencies
    exe.root_module.addImport("pg", pg_dep.module("pg"));
    exe.root_module.addImport("zap", zap_dep.module("zap"));

    // Optional: Link system libraries if required
    exe.linkLibC();
    exe.linkLibrary(pg_dep.artifact("pg"));

    // Install the executable
    b.installArtifact(exe);

    // Run Command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit Tests
    const main_tests = b.addTest(.{
        // Use b.path() here as well
        .root_source_file = b.path("src/server.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add test dependencies
    main_tests.root_module.addImport("pg", pg_dep.module("pg"));
    main_tests.root_module.addImport("zap", zap_dep.module("zap"));

    const run_unit_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
