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

    if (target.result.os.tag == .macos) {
        const app = b.addExecutable(.{
            .name = "mimoc-simulator",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/simulator.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        app.root_module.addImport("mimoc_ui", module);
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
        studio_tests.root_module.addCSourceFile(.{ .file = b.path("src/platform/macos/window.m"), .flags = &.{"-fobjc-arc"} });
        studio_tests.root_module.linkFramework("AppKit", .{});
        studio_tests.root_module.linkFramework("Foundation", .{});
        studio_tests.root_module.link_libc = true;
        test_step.dependOn(&b.addRunArtifact(studio_tests).step);
    }
}
