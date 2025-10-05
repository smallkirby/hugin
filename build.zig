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
        if (result.stdout.len < 7) {
            std.log.warn("Git SHA is too short: {s}", .{result.stdout});
            break :blk "(unknown)";
        }
        return b.dupe(std.mem.trim(u8, result.stdout[0..7], "\n \t"));
    };
}

pub fn build(b: *std.Build) !void {
    const Feature = std.Target.aarch64.Feature;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .abi = .none,
        .os_tag = .freestanding,
        .cpu_features_add = std.Target.aarch64.featureSet(&[_]Feature{
            .v8a,
        }),
        .cpu_features_sub = std.Target.aarch64.featureSet(&[_]Feature{
            .neon,
            .fp_armv8,
        }),
        .ofmt = .elf,
    });
    const optimize = b.standardOptimizeOption(.{});

    const home = std.process.getEnvVarOwned(b.allocator, "HOME") catch "..";

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

    const uboot_dir = b.option(
        []const u8,
        "uboot",
        "Path to U-Boot source directory",
    ) orelse b.fmt("{s}/u-boot", .{home});
    const qemu_dir = b.option(
        []const u8,
        "qemu",
        "Path to QEMU install directory",
    ) orelse b.fmt("{s}/qemu-aarch64", .{home});
    const image_path = b.option(
        []const u8,
        "guest",
        "Path to Linux kernel image",
    ) orelse "Image";
    const guestdisk_path = b.option(
        []const u8,
        "guestdisk",
        "Path to guest disk image",
    ) orelse "DISK0";

    const use_vfat = b.option(
        bool,
        "vfat",
        "Use QEMU Virtual FAT filesystem.",
    ) orelse false;

    const is_runtime_test = b.option(
        bool,
        "runtime_test",
        "Specify if the build is for the runtime testing.",
    ) orelse false;
    const wait_qemu = b.option(
        bool,
        "wait_qemu",
        "QEMU waits for GDB connection.",
    ) orelse false;
    const debug_virtio = b.option(
        bool,
        "debug_virtio",
        "Enable virtio debug logging.",
    ) orelse false;

    const options = b.addOptions();
    options.addOption(std.log.Level, "log_level", log_level);
    options.addOption(bool, "is_runtime_test", is_runtime_test);
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

    const hugin = blk: {
        const exe = b.addExecutable(.{
            .name = "hugin",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
            .linkage = .static,
            .use_llvm = true,
        });
        exe.entry = .{ .symbol_name = "main" };
        exe.linker_script = b.path("src/qemu.ld");
        exe.root_module.addImport("hugin", hugin_module);
        exe.root_module.addOptions("options", options);
        exe.root_module.addAssemblyFile(switch (target.result.cpu.arch) {
            .aarch64 => b.path("src/arch/aarch64/isr.S"),
            else => unreachable,
        });
        b.installArtifact(exe);

        break :blk exe;
    };

    // =============================================================
    // Disk image
    // =============================================================

    // Copy files to the install directory.
    const vfatdir_name = "disk";
    const install_hugin = b.addInstallFile(
        hugin.getEmittedBin(),
        b.fmt("{s}/{s}", .{ vfatdir_name, hugin.name }),
    );
    install_hugin.step.dependOn(&hugin.step);
    const install_guest = b.addInstallFile(
        std.Build.LazyPath{ .cwd_relative = image_path },
        b.fmt("{s}/{s}", .{ vfatdir_name, "Image" }),
    );
    const install_guestdisk = b.addInstallFile(
        std.Build.LazyPath{ .cwd_relative = guestdisk_path },
        b.fmt("{s}/{s}", .{ vfatdir_name, "DISK0" }),
    );
    b.getInstallStep().dependOn(&install_hugin.step);
    b.getInstallStep().dependOn(&install_guest.step);
    b.getInstallStep().dependOn(&install_guestdisk.step);

    // Compile DTB for the guest.
    {
        const command = b.addSystemCommand(&[_][]const u8{
            "dtc",
            "-I",
            "dts",
            "-O",
            "dtb",
            "-o",
            b.fmt("{s}/{s}/{s}", .{ b.install_path, vfatdir_name, "DTB" }),
            "assets/virt.dts",
        });
        command.step.dependOn(&install_hugin.step); // To ensure the install dir exists.
        b.getInstallStep().dependOn(&command.step);
    }

    // Compile boot.scr
    const compile_scr = blk: {
        const command = b.addSystemCommand(&[_][]const u8{
            "scripts/build_scr.sh",
            uboot_dir,
            b.fmt("{s}/{s}/boot.scr", .{ b.install_path, vfatdir_name }),
        });
        command.step.dependOn(&install_hugin.step); // To ensure the install dir exists.
        b.getInstallStep().dependOn(&command.step);

        break :blk command;
    };

    // Create FAT32 disk image.
    const diskimg_name = "diskimg";
    {
        const command = b.addSystemCommand(&[_][]const u8{
            "scripts/create_disk.bash",
            b.fmt("{s}/{s}", .{ b.install_path, vfatdir_name }), // copy source
            b.fmt("{s}/{s}", .{ b.install_path, diskimg_name }), // output image
        });
        command.step.dependOn(&compile_scr.step);
        command.step.dependOn(&install_hugin.step);
        command.step.dependOn(&install_guest.step);
        command.step.dependOn(&install_guestdisk.step);

        if (!use_vfat) b.getInstallStep().dependOn(&command.step);
    }

    // =============================================================
    // Run QEMU
    // =============================================================

    const qemu_bin = b.fmt("{s}/bin/qemu-system-aarch64", .{qemu_dir});
    {
        const fs = blk: {
            if (use_vfat) {
                break :blk b.fmt("fat:rw:{s}/{s}", .{ b.install_path, vfatdir_name });
            } else {
                break :blk b.fmt("{s}/{s}", .{ b.install_path, diskimg_name });
            }
        };

        var qemu_args = std.array_list.Aligned([]const u8, null).empty;
        defer qemu_args.deinit(b.allocator);
        try qemu_args.appendSlice(b.allocator, &.{
            qemu_bin,
            "-M",
            "virt,gic-version=3,secure=off,virtualization=on",
            "-m",
            "1G",
            "-bios",
            b.fmt("{s}/u-boot.bin", .{uboot_dir}),
            "-cpu",
            "cortex-a53",
            "-device",
            "virtio-blk-device,drive=disk",
            "-drive",
            b.fmt("file={s},format=raw,if=none,media=disk,id=disk", .{fs}),
            "-nographic",
            "-serial",
            "mon:stdio",
            "-no-reboot",
            "-smp",
            "3",
            "-s",
            "-d",
            "guest_errors",
        });
        if (wait_qemu) try qemu_args.append(b.allocator, "-S");
        if (is_runtime_test) try qemu_args.append(b.allocator, "-semihosting");
        if (debug_virtio) try qemu_args.appendSlice(b.allocator, &.{ "-d", "trace:virtio*" });

        const qemu_cmd = b.addSystemCommand(qemu_args.items);
        qemu_cmd.step.dependOn(b.getInstallStep());
        const run_qemu = b.step("run", "Run Hugin on QEMU");
        run_qemu.dependOn(&qemu_cmd.step);
    }

    // =============================================================
    // Devicetree
    // =============================================================

    {
        const dump_dts = b.addSystemCommand(&[_][]const u8{
            qemu_bin,
            "-M",
            b.fmt("virt,gic-version=3,secure=off,virtualization=on,dumpdtb={s}/qemu.dtb", .{b.install_path}),
            "-m",
            "1G",
            "-bios",
            b.fmt("{s}/u-boot.bin", .{uboot_dir}),
            "-cpu",
            "cortex-a53",
            "-drive",
            b.fmt("file=fat:rw:{s}/{s},format=raw,if=none,media=disk,id=disk", .{ b.install_path, vfatdir_name }),
            "-smp",
            "3",
        });
        const decompile_dts = b.addSystemCommand(&[_][]const u8{
            "dtc",
            "-I",
            "dtb",
            "-O",
            "dts",
            "-o",
            b.fmt("{s}/qemu.dts", .{b.install_path}),
            b.fmt("{s}/qemu.dtb", .{b.install_path}),
        });
        decompile_dts.step.dependOn(&dump_dts.step);

        const extract_dts = b.step("dts", "Extract QEMU devicetree");
        extract_dts.dependOn(&decompile_dts.step);
    }

    // =============================================================
    // Unit tests
    // =============================================================

    {
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
        hugin_unit_test.root_module.addOptions("options", options);
        const run_hugin_unit_test = b.addRunArtifact(hugin_unit_test);

        const unit_test_step = b.step("test", "Run unit tests");
        unit_test_step.dependOn(&run_hugin_unit_test.step);
    }
}
