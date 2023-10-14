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
        const zig_clap_mod = b.addModule("clap", .{ .source_file = .{ .path = "modules/zig-clap/clap.zig" } });
        const hasher_mod = b.addModule("hasher", .{.source_file = .{ .path = "src/hasher.zig" } });
        const key_writer_mod = b.addModule("file_writer", .{ .source_file = .{ .path = "src/key_writer.zig" } });
        const config_mod = b.addModule("config", .{
                .source_file = .{ .path = "src/config.zig" },
                .dependencies = &.{
                        .{
                                .module = b.createModule(.{ .source_file = .{ .path = "modules/zig-clap/clap.zig" } }),
                                .name = "clap"
                        },
                },
        });

        // add the module to the exe
        // ! change this to a loop over an array/list of modules created by the previous section
        exe.addModule("utils", utils_mod);
        exe.addModule("clap", zig_clap_mod);
        exe.addModule("config", config_mod);
        exe.addModule("hasher", hasher_mod);
        exe.addModule("keyWriter", key_writer_mod);

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
        });

        b.installArtifact(test_exe);

        // add the same modules to test_exe
        test_exe.addModule("utils", utils_mod);
        test_exe.addModule("clap", zig_clap_mod);
        test_exe.addModule("config", config_mod);
        test_exe.addModule("hasher", hasher_mod);

        const test_args = b.addRunArtifact(test_exe);
        if(b.args) |args| test_args.addArgs(args);

        // create the test command
        const test_cmd = b.step("test", "builds and runs the tests");
        test_cmd.dependOn(&test_args.step);
}