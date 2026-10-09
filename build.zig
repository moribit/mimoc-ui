const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("mimoc_ui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{ .root_module = module });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run Core tests");
    test_step.dependOn(&run_tests.step);

    const embedded_step = b.step("check-embedded", "Compile RV32 freestanding smoke paths and footprint probe");
    const embedded_target = b.resolveTargetQuery(.{ .cpu_arch = .riscv32, .os_tag = .freestanding, .abi = .eabi });
    inline for (.{ "embedded_smoke", "ui_embedded_smoke", "widget_embedded_smoke", "footprint_embedded" }) |name| {
        const object = b.addObject(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/" ++ name ++ ".zig"),
                .target = embedded_target,
                .optimize = .small,
                .link_libc = false,
            }),
        });
        embedded_step.dependOn(&object.step);
    }

    // C backend probes are opt-in and never enter the platform or default build.
    const c_host_target = b.resolveTargetQuery(.{ .ofmt = .c });
    const c_source = b.addObject(.{ .name = "mimoc_ui", .root_module = b.createModule(.{
        .root_source_file = b.path("src/c_backend_smoke.zig"),
        .target = c_host_target,
        .optimize = .small,
        .link_libc = false,
    }) });
    const emit_c = b.step("emit-c", "Generate host-ABI C and copy upstream zig.h to zig-out/c-backend");
    emit_c.dependOn(&b.addInstallFile(c_source.getEmittedBin(), "c-backend/mimoc_ui.c").step);
    emit_c.dependOn(&b.addInstallFile(std.Build.LazyPath.zig_lib.path(b, "zig.h"), "c-backend/zig.h").step);
    b.step("c-backend", "Alias for emit-c").dependOn(emit_c);
    const native_smoke = b.addObject(.{ .name = "mimoc_ui_native", .root_module = b.createModule(.{
        .root_source_file = b.path("src/c_backend_smoke.zig"),
        .target = b.graph.host,
        .optimize = .small,
        .link_libc = false,
    }) });
    const host_check = b.addSystemCommand(&.{"python3"});
    host_check.has_side_effects = true;
    host_check.stdio = .inherit;
    host_check.addFileInput(b.path("integration/c_backend/smoke.h"));
    host_check.addFileArg(b.path("tools/check_c_backend.py"));
    host_check.addArgs(&.{ "host", "--zig", b.graph.zig_exe, "--generated" });
    host_check.addFileArg(c_source.getEmittedBin());
    host_check.addArg("--native");
    host_check.addFileArg(native_smoke.getEmittedBin());
    host_check.addArg("--driver");
    host_check.addFileArg(b.path("integration/c_backend/compare.c"));
    host_check.addArg("--zig-lib");
    host_check.addDirectoryArg(std.Build.LazyPath.zig_lib);
    if (b.option([]const u8, "c-host-cc", "Existing host C compiler (default CC/clang/cc)")) |cc| host_check.addArgs(&.{ "--cc", cc });
    host_check.addArg("--outdir");
    const host_output = host_check.addOutputDirectoryArg("c-backend-host");
    const check_c = b.step("check-c-backend-host", "Host C compile/link/run and exact native framebuffer equivalence");
    check_c.dependOn(&host_check.step);
    b.step("check-c-backend", "Alias for host C backend equivalence").dependOn(check_c);
    const install_host = b.step("c-backend-host", "Check and install host comparison logs/binary");
    install_host.dependOn(&b.addInstallDirectory(.{ .source_dir = host_output, .install_dir = .prefix, .install_subdir = "c-backend/host" }).step);

    const xtensa_source = b.addObject(.{ .name = "mimoc_ui_xtensa", .root_module = b.createModule(.{
        .root_source_file = b.path("src/c_backend_smoke.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .xtensa, .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.generic }, .os_tag = .freestanding, .ofmt = .c }),
        .optimize = .small,
        .link_libc = false,
    }) });
    const emit_xtensa = b.step("emit-c-xtensa", "Diagnostic: regenerate the same Zig entrypoint for the Xtensa ABI");
    emit_xtensa.dependOn(&b.addInstallFile(xtensa_source.getEmittedBin(), "c-backend/mimoc_ui.xtensa.c").step);
    emit_xtensa.dependOn(emit_c);
    const minimal_abi = b.addObject(.{ .name = "xtensa_abi_minimal", .root_module = b.createModule(.{
        .root_source_file = b.path("integration/esp32s3-c-backend/minimal.zig"),
        .target = xtensa_source.root_module.resolved_target.?,
        .optimize = .small,
        .link_libc = false,
    }) });
    const emit_minimal = b.step("emit-c-abi-minimal", "Emit an upstream Xtensa ABI reproducer without mimoc-ui");
    emit_minimal.dependOn(&b.addInstallFile(minimal_abi.getEmittedBin(), "c-backend/abi-minimal.c").step);
    const idf_path = b.option([]const u8, "esp-idf", "Existing official ESP-IDF directory; never downloaded");
    const xtensa_gcc = b.option([]const u8, "xtensa-gcc", "Existing official xtensa-esp-elf-gcc path; never downloaded");
    const strict_esp = b.step("check-esp32s3-c", "Stage B: compile the identical Stage A C source with official ESP-IDF GCC");
    const target_esp = b.step("check-esp32s3-c-target", "Diagnostic: compile Xtensa-regenerated C without changing ABI assertions");
    const minimal_esp = b.step("check-esp32s3-c-abi", "Diagnose upstream ABI assertions with a one-function Zig module");
    inline for (.{ 0, 1, 2 }) |variant| {
        const check = b.addSystemCommand(&.{"python3"});
        check.has_side_effects = true;
        check.stdio = .inherit;
        check.addFileInput(b.path("integration/esp32s3-c-backend/CMakeLists.txt"));
        check.addFileInput(b.path("integration/esp32s3-c-backend/abi_probe.c"));
        check.addFileArg(b.path("tools/check_c_backend.py"));
        check.addArgs(&.{ "esp32", "--zig", b.graph.zig_exe, "--generated" });
        check.addFileArg(switch (variant) {
            0 => c_source.getEmittedBin(),
            1 => xtensa_source.getEmittedBin(),
            else => minimal_abi.getEmittedBin(),
        });
        check.addArg("--zig-lib");
        check.addDirectoryArg(std.Build.LazyPath.zig_lib);
        check.addArg("--harness");
        check.addDirectoryArg(b.path("integration/esp32s3-c-backend"));
        if (idf_path) |path| check.addArgs(&.{ "--idf", path });
        if (xtensa_gcc) |path| check.addArgs(&.{ "--gcc", path });
        check.addArg("--outdir");
        _ = check.addOutputDirectoryArg(switch (variant) {
            0 => "esp32s3-identical",
            1 => "esp32s3-target",
            else => "esp32s3-abi-minimal",
        });
        check.step.dependOn(&host_check.step); // Stage B starts only after Stage A PASS.
        (switch (variant) {
            0 => strict_esp,
            1 => target_esp,
            else => minimal_esp,
        }).dependOn(&check.step);
    }
    const portability = b.step("check-portability", "RV32, host C equivalence and strict ESP32-S3 compile (fails on an ABI/toolchain blocker)");
    portability.dependOn(embedded_step);
    portability.dependOn(check_c);
    portability.dependOn(strict_esp);

    const report = b.addExecutable(.{
        .name = "mimoc-resource-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/footprint.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const resource_step = b.step("resource-report", "Print Core type sizes and representative RAM budgets");
    resource_step.dependOn(&b.addRunArtifact(report).step);

    if (target.result.os.tag == .macos) {
        const desktop_app = b.addExecutable(.{ .name = "mimoc-desktop-demo", .root_module = b.createModule(.{ .root_source_file = b.path("examples/desktop.zig"), .target = target, .optimize = optimize }) });
        desktop_app.root_module.addImport("mimoc_ui", module);
        const desktop_font = b.createModule(.{ .root_source_file = b.path("src/platform/macos/font.zig"), .target = target, .optimize = optimize });
        desktop_font.addImport("mimoc_ui", module);
        desktop_app.root_module.addImport("desktop_font", desktop_font);
        const desktop_window = b.createModule(.{ .root_source_file = b.path("src/platform/macos/window.zig"), .target = target, .optimize = optimize });
        desktop_window.addImport("mimoc_ui", module);
        desktop_app.root_module.addImport("desktop_window", desktop_window);
        desktop_app.root_module.addCSourceFile(.{ .file = b.path("src/platform/macos/window.m"), .flags = &.{"-fobjc-arc"} });
        desktop_app.root_module.addCSourceFile(.{ .file = b.path("src/platform/macos/font.m"), .flags = &.{"-fobjc-arc"} });
        inline for (.{ "AppKit", "Foundation", "CoreText", "CoreGraphics" }) |framework| desktop_app.root_module.linkFramework(framework, .{});
        desktop_app.root_module.link_libc = true;
        const desktop_tests = b.addTest(.{ .root_module = desktop_app.root_module });
        test_step.dependOn(&b.addRunArtifact(desktop_tests).step);
        b.installArtifact(desktop_app);
        b.step("desktop-demo", "Run resizable Desktop Foundation mock").dependOn(&b.addRunArtifact(desktop_app).step);
        b.step("check-desktop", "Compile Desktop demo without opening a window").dependOn(&desktop_app.step);
        const showcase_module = b.createModule(.{
            .root_source_file = b.path("examples/showcase.zig"),
            .target = target,
            .optimize = optimize,
        });
        showcase_module.addImport("mimoc_ui", module);
        const mobus_module = b.createModule(.{
            .root_source_file = b.path("examples/mobus/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        mobus_module.addImport("mimoc_ui", module);
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = mobus_module })).step);
        const app = b.addExecutable(.{
            .name = "mimoc-simulator",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/simulator.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        app.root_module.addImport("mimoc_ui", module);
        app.root_module.addImport("showcase", showcase_module);
        app.root_module.addCSourceFile(.{ .file = b.path("src/platform/macos/window.m"), .flags = &.{"-fobjc-arc"} });
        app.root_module.linkFramework("AppKit", .{});
        app.root_module.linkFramework("Foundation", .{});
        app.root_module.link_libc = true;
        b.installArtifact(app);
        const run = b.addRunArtifact(app);
        const run_step = b.step("run", "Run the virtual SSD1306 desktop simulator");
        run_step.dependOn(&run.step);

        const studio = b.addExecutable(.{
            .name = "mimoc-studio",
            .root_module = b.createModule(.{
                .root_source_file = b.path("studio/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        studio.root_module.addImport("mimoc_ui", module);
        const demo_module = b.createModule(.{
            .root_source_file = b.path("examples/demo_view.zig"),
            .target = target,
            .optimize = optimize,
        });
        demo_module.addImport("mimoc_ui", module);
        studio.root_module.addImport("demo_view", demo_module);
        studio.root_module.addImport("showcase", showcase_module);
        studio.root_module.addImport("mobus_demo", mobus_module);
        studio.root_module.addCSourceFile(.{ .file = b.path("src/platform/macos/window.m"), .flags = &.{"-fobjc-arc"} });
        studio.root_module.linkFramework("AppKit", .{});
        studio.root_module.linkFramework("Foundation", .{});
        studio.root_module.link_libc = true;
        b.installArtifact(studio);
        const run_studio = b.addRunArtifact(studio);
        const studio_step = b.step("studio", "Run Mimoc UI Studio");
        studio_step.dependOn(&run_studio.step);

        const studio_tests = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path("studio/main.zig"),
            .target = target,
            .optimize = optimize,
        }) });
        studio_tests.root_module.addImport("mimoc_ui", module);
        studio_tests.root_module.addImport("demo_view", demo_module);
        studio_tests.root_module.addImport("showcase", showcase_module);
        studio_tests.root_module.addImport("mobus_demo", mobus_module);
        studio_tests.root_module.addCSourceFile(.{ .file = b.path("src/platform/macos/window.m"), .flags = &.{"-fobjc-arc"} });
        studio_tests.root_module.linkFramework("AppKit", .{});
        studio_tests.root_module.linkFramework("Foundation", .{});
        studio_tests.root_module.link_libc = true;
        test_step.dependOn(&b.addRunArtifact(studio_tests).step);

        const snapshot = b.addExecutable(.{
            .name = "mimoc-studio-snapshot",
            .root_module = b.createModule(.{
                .root_source_file = b.path("studio/snapshot.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        snapshot.root_module.addImport("mimoc_ui", module);
        snapshot.root_module.addImport("demo_view", demo_module);
        snapshot.root_module.addImport("showcase", showcase_module);
        snapshot.root_module.addImport("mobus_demo", mobus_module);
        snapshot.root_module.addCSourceFile(.{ .file = b.path("src/platform/macos/window.m"), .flags = &.{"-fobjc-arc"} });
        snapshot.root_module.linkFramework("AppKit", .{});
        snapshot.root_module.linkFramework("Foundation", .{});
        snapshot.root_module.link_libc = true;
        b.installArtifact(snapshot);
        const run_snapshot = b.addRunArtifact(snapshot);
        const snapshot_step = b.step("studio-snapshot", "Write the Studio PBM snapshot to stdout");
        snapshot_step.dependOn(&run_snapshot.step);
    }
}
