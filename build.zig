const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("version_info", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/cli.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "version_info",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "cli", .module = cli_mod },
                .{ .name = "version_info", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const cli_tests = b.addTest(.{
        .root_module = cli_mod,
    });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(mod_tests).step);
    test_step.dependOn(&b.addRunArtifact(cli_tests).step);

    const make_coverage_dirs = b.addSystemCommand(&.{
        "mkdir",
        "-p",
        b.pathFromRoot("coverage/root"),
        b.pathFromRoot("coverage/cli"),
        b.pathFromRoot("coverage/merged"),
    });
    const mod_coverage_tests = b.addTest(.{
        .name = "root-coverage",
        .root_module = mod,
        .use_llvm = true,
    });
    const cli_coverage_tests = b.addTest(.{
        .name = "cli-coverage",
        .root_module = cli_mod,
        .use_llvm = true,
    });

    const mod_coverage = b.addSystemCommand(&.{
        "kcov",
        b.fmt("--include-path={s}", .{b.pathFromRoot("src")}),
        b.pathFromRoot("coverage/root"),
    });
    mod_coverage.addArtifactArg(mod_coverage_tests);
    mod_coverage.step.dependOn(&make_coverage_dirs.step);

    const cli_coverage = b.addSystemCommand(&.{
        "kcov",
        b.fmt("--include-path={s}", .{b.pathFromRoot("src")}),
        b.pathFromRoot("coverage/cli"),
    });
    cli_coverage.addArtifactArg(cli_coverage_tests);
    cli_coverage.step.dependOn(&make_coverage_dirs.step);

    const merge_coverage = b.addSystemCommand(&.{
        "kcov",
        "--merge",
        b.pathFromRoot("coverage/merged"),
        b.pathFromRoot("coverage/root"),
        b.pathFromRoot("coverage/cli"),
    });
    merge_coverage.step.dependOn(&mod_coverage.step);
    merge_coverage.step.dependOn(&cli_coverage.step);

    const coverage_step = b.step("coverage", "Run tests and generate code coverage");
    coverage_step.dependOn(&merge_coverage.step);
}
