const std = @import("std");
const path = std.fs.path;
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("zig-vulkan-triangle", "src/main.zig");
    exe.setBuildMode(mode);
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);
    exe.install();

    const run_step = b.step("run", "Run the app");
    const run_cmd = exe.run();
    run_step.dependOn(&run_cmd.step);

    try addShader(b, exe, "shader.vert", "vert.spv");
    try addShader(b, exe, "shader.frag", "frag.spv");
}

fn addShader(b: *Builder, exe: var, in_file: []const u8, out_file: []const u8) !void {
    // example:
    // glslc -o shaders/vert.spv shaders/shader.vert
    const dirname = "shaders";
    const full_in = try path.join(b.allocator, [_][]const u8{ dirname, in_file });
    const full_out = try path.join(b.allocator, [_][]const u8{ dirname, out_file });

    const run_cmd = b.addSystemCommand([_][]const u8{
        "glslc",
        "-o",
        full_out,
        full_in,
    });
    exe.step.dependOn(&run_cmd.step);
}
