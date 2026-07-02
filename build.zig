const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "vulkan-triangle-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.linkSystemLibrary("vulkan", .{});
    exe.root_module.linkSystemLibrary("xcb", .{});
    b.installArtifact(exe);

    const registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    const vk_gen = b.dependency("vulkan", .{}).artifact("vulkan-zig-generator");
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    vk_generate_cmd.addFileArg(registry);

    exe.root_module.addAnonymousImport("vulkan", .{
        .root_source_file = vk_generate_cmd.addOutputFileArg("vk.zig"),
    });

    const spirv_target = b.resolveTargetQuery(.{
        .cpu_arch = .spirv32,
        .cpu_model = .{ .explicit = &std.Target.spirv.cpu.vulkan_v1_2 },
        .os_tag = .vulkan,
    });

    const vert_config = b.addOptions();
    const frag_config = b.addOptions();
    const Stage = enum { frag, vert };
    vert_config.addOption(Stage, "stage", .vert);
    frag_config.addOption(Stage, "stage", .frag);

    exe.root_module.addAnonymousImport("shader.vert", .{ .root_source_file = compileShader(
        b,
        spirv_target,
        optimize,
        b.path("src/shader.zig"),
        "shader.vert",
        vert_config,
    ) });
    exe.root_module.addAnonymousImport("shader.frag", .{ .root_source_file = compileShader(
        b,
        spirv_target,
        optimize,
        b.path("src/shader.zig"),
        "shader.frag",
        frag_config,
    ) });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn compileShader(
    b: *std.Build,
    spirv_target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    src: std.Build.LazyPath,
    name: []const u8,
    config: *std.Build.Step.Options,
) std.Build.LazyPath {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = src,
            .target = spirv_target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("config", config);
    return exe.getEmittedBin();
}
