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
