const config = @import("config");

const std = @import("std");
const spirv = std.spirv;

const v4u8 = @Vector(4, u8);
const v2u16 = @Vector(2, u16);
const v2i16 = @Vector(2, i16);
const v2f32 = @Vector(2, f32);
const v3f32 = @Vector(3, f32);
const v4f32 = @Vector(4, f32);

comptime {
    @export(switch (config.stage) {
        .vert => &vertex,
        .frag => &fragment,
    }, .{ .name = "main" });
}

fn Param(comptime T: type) type {
    return switch (config.stage) {
        .vert => *addrspace(.output) T,
        .frag => *addrspace(.input) const T,
    };
}

/// For vertex it is output, for fragment it is input.
inline fn param(comptime name: []const u8, comptime T: type, location: u32) Param(T) {
    comptime return @extern(Param(T), .{ .name = name, .decoration = .{ .location = location } });
}

const param_color = param("color", v3f32, 0);

fn vertex() callconv(.spirv_vertex) void {
    const a_pos = @extern(*addrspace(.input) const v2f32, .{
        .name = "a_pos",
        .decoration = .{ .location = 0 },
    }).*;
    const a_color = @extern(*addrspace(.input) const v3f32, .{
        .name = "a_color",
        .decoration = .{ .location = 1 },
    }).*;
    spirv.position_out.* = .{ a_pos[0], a_pos[1], 0, 1 };
    param_color.* = a_color;
}

fn fragment() callconv(.{ .spirv_fragment = .{} }) void {
    const f_color = @extern(*addrspace(.output) v4f32, .{
        .name = "pos",
        .decoration = .{ .location = 0 },
    });
    f_color.* = .{ param_color[0], param_color[1], param_color[2], 1.0 };
}
