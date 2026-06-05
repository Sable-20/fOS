const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    // ----------------------------
    // KERNEL
    // ----------------------------
    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = false,
            .code_model = .kernel,
        }),
    });

    kernel.root_module.addCSourceFiles(.{
        .files = &.{
            "kernel/kernel/kmain.c",
            "kernel/impl/memory.c",
        },
        .flags = &.{
            "-ffreestanding",
            "-fno-builtin",
            "-fno-stack-protector",
            "-mno-red-zone",
            "-fno-sanitize=all",
        },
    });

    kernel.root_module.addAssemblyFile(b.path("kernel/arch/x86_64/start.S"));

    kernel.root_module.addIncludePath(b.path("kernel/include"));
    kernel.root_module.addIncludePath(b.path("limine"));

    kernel.setLinkerScript(b.path("kernel/linker.ld"));

    // IMPORTANT: install artifact (this creates zig-out/bin/kernel.elf)
    const install_kernel = b.addInstallArtifact(kernel, .{});

    // ----------------------------
    // ISO DIRECTORY
    // ----------------------------
    _ = b.path("iso_root");

    const mkdir_iso = b.addSystemCommand(&.{
        "bash",
        "-c",
        "mkdir -p iso_root/boot && mkdir -p iso_root/boot/limine && mkdir -p iso_root/EFI/BOOT",
    });

    // copy kernel (SAFE: uses install step, not getPath)
    const copy_kernel = b.addSystemCommand(&.{
        "bash",
        "-c",
        "cp zig-out/bin/kernel.elf iso_root/boot/kernel.elf",
    });

    copy_kernel.step.dependOn(&install_kernel.step);
    copy_kernel.step.dependOn(&mkdir_iso.step);

    // copy limine config (FIXED NAME)
    const copy_cfg = b.addSystemCommand(&.{
        "bash",
        "-c",
        "cp -v limine.conf limine/limine-bios.sys limine/limine-bios-cd.bin limine/limine-uefi-cd.bin iso_root/boot/limine/",
    });

    copy_cfg.step.dependOn(&mkdir_iso.step);

    const copy_boot_files = b.addSystemCommand(&.{
        "bash",
        "-c",
        "cp -v limine/BOOTX64.EFI limine/BOOTIA32.EFI iso_root/EFI/BOOT/",
    });

    copy_boot_files.step.dependOn(&mkdir_iso.step);
    // copy limine files
    // const copy_limine = b.addSystemCommand(&.{
    //     "bash",
    //     "-c",
    //     "cp -r ./limine/* iso_root/",
    // });

    // copy_limine.step.dependOn(&mkdir_iso.step);

    const iso = b.addSystemCommand(&.{
        "xorriso",
        "-as",
        "mkisofs",
        "-R",
        "-r",
        "-J",
        "-b",
        "boot/limine/limine-bios-cd.bin",
        "-no-emul-boot",
        "-boot-load-size",
        "4",
        "-boot-info-table",
        "-hfsplus",
        "-apm-block-size",
        "2048",
        "--efi-boot",
        "boot/limine/limine-uefi-cd.bin",
        "-efi-boot-part",
        "--efi-boot-image",
        "--protective-msdos-label",
        "iso_root",
        "-o",
        "fOS.iso",
    });

    iso.step.dependOn(&copy_kernel.step);
    iso.step.dependOn(&copy_cfg.step);
    iso.step.dependOn(&copy_boot_files.step);
    // iso.step.dependOn(&copy_limine.step);

    // ----------------------------
    // TOP LEVEL STEP
    // ----------------------------
    const iso_step = b.step("iso", "Build bootable ISO");

    iso_step.dependOn(&iso.step);

    // default build also builds kernel
    b.default_step.dependOn(&install_kernel.step);
}
