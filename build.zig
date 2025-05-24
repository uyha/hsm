const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "hsm",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    inline for (.{"traffic"}) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path(
                b.pathJoin(&.{ "examples", name ++ ".zig" }),
            ),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("hsm", lib.root_module);

        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(name, "Run " ++ name ++ "example");
        run_step.dependOn(&run_cmd.step);
    }

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const end_to_end_tests = b.addTest(.{
        .root_source_file = b.path("test/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    end_to_end_tests.root_module.addAnonymousImport(
        "hsm",
        .{ .root_source_file = lib.root_module.root_source_file },
    );

    const run_end_to_end_tests = b.addRunArtifact(end_to_end_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_end_to_end_tests.step);
}
