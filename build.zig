const std = @import("std");
const zon: ZonStruct = @import("build.zig.zon");

/// Type of build.zig.zon file.
const ZonStruct = struct {
    version: []const u8,
    name: @Type(.enum_literal),
    fingerprint: u64,
    minimum_zig_version: []const u8,
    dependencies: struct {},
    paths: []const []const u8,
};

/// Hugin version string.
const hugin_version = zon.version;

/// Get SHA-1 hash of the current Git commit.
fn getGitSha(b: *std.Build) ![]const u8 {
    return blk: {
        const result = std.process.Child.run(.{
            .allocator = b.allocator,
            .argv = &.{
                "git",
                "rev-parse",
                "HEAD",
            },
            .cwd = b.pathFromRoot("."),
        }) catch |err| {
            std.log.warn("Failed to get git SHA: {s}", .{@errorName(err)});
            break :blk "(unknown)";
        };
        return b.dupe(std.mem.trim(u8, result.stdout[0..7], "\n \t"));
    };
}

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
        .ofmt = .elf,
    });
    const optimize = b.standardOptimizeOption(.{});

    // =============================================================
    // Options
    // =============================================================
    const s_log_level = b.option(
        []const u8,
        "log_level",
        "log_level",
    ) orelse "info";
    const log_level: std.log.Level = b: {
        const eql = std.mem.eql;
        break :b if (eql(u8, s_log_level, "debug"))
            .debug
        else if (eql(u8, s_log_level, "info"))
            .info
        else if (eql(u8, s_log_level, "warn"))
            .warn
        else if (eql(u8, s_log_level, "error"))
            .err
        else
            @panic("Invalid log level");
    };

    const options = b.addOptions();
    options.addOption(std.log.Level, "log_level", log_level);
    options.addOption([]const u8, "sha", try getGitSha(b));

    // =============================================================
    // Modules
    // =============================================================

    const hugin_module = b.createModule(.{
        .root_source_file = b.path("src/hugin.zig"),
    });
    hugin_module.addImport("hugin", hugin_module);
    hugin_module.addOptions("options", options);

    // =============================================================
    // Executables
    // =============================================================

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
    hugin.root_module.addOptions("options", options);
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
