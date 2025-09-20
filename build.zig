const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
        .ofmt = .elf,
    });
    const optimize = b.standardOptimizeOption(.{});

    const hugin_module = b.createModule(.{
        .root_source_file = b.path("src/hugin.zig"),
    });
    hugin_module.addImport("norn", hugin_module);

    const hugin = b.addExecutable(.{
        .name = "hugin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
        .use_llvm = true,
    });
    hugin.entry = .{ .symbol_name = "main" };
    hugin.linker_script = b.path("src/qemu.ld");
    hugin.root_module.addImport("hugin", hugin_module);
    b.installArtifact(hugin);

    // =============================================================
    // Unit tests
    // =============================================================

    const hugin_unit_test = b.addTest(.{
        .name = "hugin_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/hugin.zig"),
            .target = b.resolveTargetQuery(.{}),
            .optimize = optimize,
            .link_libc = true,
        }),
        .use_llvm = false,
    });
    hugin_unit_test.root_module.addImport("hugin", hugin_unit_test.root_module);
    const run_hugin_unit_test = b.addRunArtifact(hugin_unit_test);

    const unit_test_step = b.step("test", "Run unit tests");
    unit_test_step.dependOn(&run_hugin_unit_test.step);
}
