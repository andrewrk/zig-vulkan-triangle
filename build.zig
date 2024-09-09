const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    const shader_compiler = b.dependency("shader_compiler", .{
        .target = b.host,
        .optimize = .ReleaseFast,
    }).artifact("shader_compiler");

    const exe = b.addExecutable(.{
        .name = "vulkan-triangle-example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("xcb");
    b.installArtifact(exe);

    const vk_gen = b.dependency("vulkan", .{}).artifact("vulkan-zig-generator");
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    vk_generate_cmd.addFileArg(registry);

    exe.root_module.addAnonymousImport("vulkan", .{
        .root_source_file = vk_generate_cmd.addOutputFileArg("vk.zig"),
    });

    exe.root_module.addAnonymousImport("shaders.triangle.vert", .{
        .root_source_file = compileShader(b, optimize, shader_compiler, b.path("shaders/triangle.vert"), "triangle.vert.spv"),
    });
    exe.root_module.addAnonymousImport("shaders.triangle.frag", .{
        .root_source_file = compileShader(b, optimize, shader_compiler, b.path("shaders/triangle.frag"), "triangle.frag.spv"),
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn compileShader(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    shader_compiler: *std.Build.Step.Compile,
    src: std.Build.LazyPath,
    out_basename: []const u8,
) std.Build.LazyPath {
    const compile_shader = b.addRunArtifact(shader_compiler);
    compile_shader.addArgs(&.{
        "--target", "Vulkan-1.3",
    });
    switch (optimize) {
        .Debug => compile_shader.addArgs(&.{
            "--robust-access",
        }),
        .ReleaseSafe => compile_shader.addArgs(&.{
            "--optimize-perf",
            "--robust-access",
        }),
        .ReleaseFast => compile_shader.addArgs(&.{
            "--optimize-perf",
        }),
        .ReleaseSmall => compile_shader.addArgs(&.{
            "--optimize-perf",
            "--optimize-small",
        }),
    }
    compile_shader.addFileArg(src);
    return compile_shader.addOutputFileArg(out_basename);
}
