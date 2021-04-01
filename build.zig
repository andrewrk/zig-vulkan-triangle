const std = @import("std");
const path = std.fs.path;
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("zig-vulkan-triangle", "src/main.zig");
    exe.setBuildMode(mode);

    exe.linkSystemLibrary("c");

    if (exe.target.isDarwin()) {
        const glfw_path = b.option([]const u8, "glfw-path", "The path to the libglfw.dylib library file") orelse "./deps/glfw/build/src";
        const vulkan_path = b.option([]const u8, "vulkan-path", "The path to the vulkan library files") orelse "./deps/vulkan/macOS/lib";

        exe.addLibPath(glfw_path);
        exe.addLibPath(vulkan_path);
        exe.linkSystemLibraryName("glfw");
        exe.linkSystemLibraryName("vulkan");
    } else {
        exe.linkSystemLibrary("glfw");
        exe.linkSystemLibrary("vulkan");
    }

    b.default_step.dependOn(&exe.step);
    exe.install();

    const run_step = b.step("run", "Run the app");
    const run_cmd = exe.run();
    run_step.dependOn(&run_cmd.step);

    if (exe.target.isDarwin()) {
        try addMoltenVKShader(b, exe, "shader.vert", "vert.spv");
        try addMoltenVKShader(b, exe, "shader.frag", "frag.spv");
    } else {
        try addShader(b, exe, "shader.vert", "vert.spv");
        try addShader(b, exe, "shader.frag", "frag.spv");
    }
}

fn addShader(b: *Builder, exe: anytype, in_file: []const u8, out_file: []const u8) !void {
    // example:
    // glslc -o shaders/vert.spv shaders/shader.vert
    const dirname = "shaders";
    const full_in = try path.join(b.allocator, &[_][]const u8{ dirname, in_file });
    const full_out = try path.join(b.allocator, &[_][]const u8{ dirname, out_file });

    const run_cmd = b.addSystemCommand(&[_][]const u8{
        "glslc",
        "-o",
        full_out,
        full_in,
    });
    exe.step.dependOn(&run_cmd.step);
}

fn addMoltenVKShader(b: *Builder, exe: anytype, in_file: []const u8, out_file: []const u8) !void {
    // example:
    // in MoltenVKShaderConverter -gi means glsl in, and -so means spirv out
    // MoltenVKShaderConverter -gi shaders/vert.spv -so shaders/shader.vert
    const dirname = "shaders";
    const full_in = try path.join(b.allocator, &[_][]const u8{ dirname, in_file });
    const full_out = try path.join(b.allocator, &[_][]const u8{ dirname, out_file });
    const tool = "MoltenVKShaderConverter";
    const tool_path = try path.join(b.allocator, &[_][]const u8{ "./deps/vulkan/macOS/bin/", tool });

    const run_cmd = b.addSystemCommand(&[_][]const u8{
        tool_path,
        "-gi",
        full_in,
        "-so",
        full_out,
    });
    exe.step.dependOn(&run_cmd.step);
}
