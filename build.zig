const std = @import("std");
const Build = std.Build;


pub fn build(b: *Build) !void {
        // set target and build modes
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

        // create the main executable compile step
        const exe = b.addExecutable(.{
                .name = "angoku",
                .root_source_file = .{ .path = "src/main.zig" },
                .target = target,
                .optimize = optimize,
        });

        b.installArtifact(exe);

        // create modules
        // ! change this to a loop over contents within the src directory
        const utils_mod = b.addModule("utils", .{ .source_file = .{ .path = "src/utils.zig" } });

        // add the module to the exe
        // ! change this to a loop over an array/list of modules created by the previous section
        exe.addModule("utils", utils_mod);

        // add the run step
        const run_step = b.addRunArtifact(exe);
        if(b.args) |args| run_step.addArgs(args);

        // create the actual run command useable with `zig build`: `zig build run`
        const run_cmd = b.step("run", "builds and/or runs the app");
        run_cmd.dependOn(&run_step.step);

        const test_exe = b.addTest(.{
                .root_source_file = .{ .path = "src/main.zig" },
                .name = "test_angoku",
                .target = target,
                .optimize = optimize,
        });

        b.installArtifact(test_exe);

        // create the test command
        const test_cmd = b.step("test", "builds and runs the tests");
        test_cmd.dependOn(&test_exe.step);
}