const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const shader_triangle_vert = @embedFile("shaders.triangle.vert");
const shader_triangle_frag = @embedFile("shaders.triangle.frag");
const xcb = @import("xcb.zig");
const GraphicsContext = @import("GraphicsContext.zig");
const Swapchain = @import("Swapchain.zig");

const vk = @import("vulkan");
pub const xcb_connection_t = xcb.connection_t;
pub const xcb_visualid_t = xcb.visualid_t;
pub const xcb_window_t = xcb.window_t;

const app_name = "vulkan-zig triangle example";

const enable_validation_layers = builtin.mode == .Debug;

const Vertex = struct {
    const binding_description = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .input_rate = .vertex,
    };

    const attribute_description = [_]vk.VertexInputAttributeDescription{
        .{
            .binding = 0,
            .location = 0,
            .format = .r32g32_sfloat,
            .offset = @offsetOf(Vertex, "pos"),
        },
        .{
            .binding = 0,
            .location = 1,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Vertex, "color"),
        },
    };

    pos: [2]f32,
    color: [3]f32,
};

const vertices = [_]Vertex{
    .{ .pos = .{ 0, -0.5 }, .color = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0, 1, 0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0, 0, 1 } },
};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_purpose_allocator.deinit();
    const gpa = general_purpose_allocator.allocator();

    var extent: vk.Extent2D = .{ .width = 800, .height = 600 };

    std.log.debug("connecting to X11", .{});

    var scr: c_int = undefined;
    const connection = xcb.connect(null, &scr).?;
    if (xcb.connection_has_error(connection) != 0) {
        @panic("Could not find a compatible Vulkan ICD");
    }
    const setup = xcb.get_setup(connection);
    var iter = xcb.setup_roots_iterator(setup);
    while (scr > 0) : (scr -= 1) {
        xcb.screen_next(&iter);
    }
    const screen = iter.data;

    std.log.debug("opening window", .{});
    const window = xcb.generate_id(connection);
    const value_mask = xcb.CW.BACK_PIXEL | xcb.CW.EVENT_MASK;
    const value_list = [_]u32{
        screen.black_pixel,
        xcb.EVENT_MASK.KEY_RELEASE |
            xcb.EVENT_MASK.KEY_PRESS |
            xcb.EVENT_MASK.EXPOSURE |
            xcb.EVENT_MASK.STRUCTURE_NOTIFY |
            xcb.EVENT_MASK.POINTER_MOTION |
            xcb.EVENT_MASK.BUTTON_PRESS |
            xcb.EVENT_MASK.BUTTON_RELEASE,
    };

    _ = xcb.create_window(
        connection,
        xcb.COPY_FROM_PARENT,
        window,
        screen.root,
        0,
        0,
        @intCast(extent.width),
        @intCast(extent.height),
        0,
        @intFromEnum(xcb.window_class_t.INPUT_OUTPUT),
        screen.root_visual,
        value_mask,
        &value_list,
    );

    // Send notification when window is destroyed.
    const atom_wm_protocols = try get_atom(connection, "WM_PROTOCOLS");
    const atom_wm_delete_window = try get_atom(connection, "WM_DELETE_WINDOW");
    _ = xcb.change_property(
        connection,
        .REPLACE,
        window,
        atom_wm_protocols,
        .ATOM,
        32,
        1,
        &atom_wm_delete_window,
    );

    const title = "Zig Vulkan Triangle";
    _ = xcb.change_property(connection, .REPLACE, window, .WM_NAME, .STRING, 8, title.len, title);

    // Set the WM_CLASS property to display title in dash tooltip and
    // application menu on GNOME and other desktop environments
    var wm_class_buf: [100]u8 = undefined;
    const wm_class = std.fmt.bufPrint(&wm_class_buf, "windowName\x00{s}\x00", .{title}) catch unreachable;
    _ = xcb.change_property(
        connection,
        .REPLACE,
        window,
        .WM_CLASS,
        .STRING,
        8,
        @intCast(wm_class.len),
        wm_class.ptr,
    );
    _ = xcb.map_window(connection, window);

    const gc = try GraphicsContext.init(gpa, app_name, connection, window, enable_validation_layers);
    defer gc.deinit();

    std.log.debug("Using device: {s}", .{gc.deviceName()});

    var swapchain = try Swapchain.init(&gc, gpa, extent);
    defer swapchain.deinit();

    const pipeline_layout = try gc.dev.createPipelineLayout(&.{
        .flags = .{},
        .set_layout_count = 0,
        .p_set_layouts = undefined,
        .push_constant_range_count = 0,
        .p_push_constant_ranges = undefined,
    }, null);
    defer gc.dev.destroyPipelineLayout(pipeline_layout, null);

    const render_pass = try createRenderPass(&gc, swapchain);
    defer gc.dev.destroyRenderPass(render_pass, null);

    const pipeline = try createPipeline(&gc, pipeline_layout, render_pass);
    defer gc.dev.destroyPipeline(pipeline, null);

    var framebuffers = try createFramebuffers(&gc, gpa, render_pass, swapchain);
    defer destroyFramebuffers(&gc, gpa, framebuffers);

    const pool = try gc.dev.createCommandPool(&.{
        .queue_family_index = gc.graphics_queue.family,
    }, null);
    defer gc.dev.destroyCommandPool(pool, null);

    const buffer = try gc.dev.createBuffer(&.{
        .size = @sizeOf(@TypeOf(vertices)),
        .usage = .{ .transfer_dst_bit = true, .vertex_buffer_bit = true },
        .sharing_mode = .exclusive,
    }, null);
    defer gc.dev.destroyBuffer(buffer, null);
    const mem_reqs = gc.dev.getBufferMemoryRequirements(buffer);
    const memory = try gc.allocate(mem_reqs, .{ .device_local_bit = true });
    defer gc.dev.freeMemory(memory, null);
    try gc.dev.bindBufferMemory(buffer, memory, 0);

    try uploadVertices(&gc, pool, buffer);

    var cmdbufs = try createCommandBuffers(
        &gc,
        pool,
        gpa,
        buffer,
        swapchain.extent,
        render_pass,
        pipeline,
        framebuffers,
    );
    defer destroyCommandBuffers(&gc, pool, gpa, cmdbufs);

    defer {
        swapchain.waitForAllFences() catch {};
        gc.dev.deviceWaitIdle() catch {};
    }

    std.log.debug("main loop", .{});

    while (true) {
        var extent_changed = false;
        var opt_event = xcb.wait_for_event(connection);
        while (opt_event) |event| : (opt_event = xcb.poll_for_event(connection)) {
            defer std.c.free(event);
            switch (event.response_type.op) {
                .CLIENT_MESSAGE => blk: {
                    const client_message: *xcb.client_message_event_t = @ptrCast(event);
                    if (client_message.window != window) break :blk;

                    if (client_message.type == atom_wm_protocols) {
                        const msg_atom: xcb.atom_t = @enumFromInt(client_message.data.data32[0]);
                        if (msg_atom == atom_wm_delete_window) return std.process.cleanExit();
                    } else if (client_message.type == .NOTICE) {
                        // We repaint every frame regardless.
                    }
                },
                .CONFIGURE_NOTIFY => {
                    const configure: *xcb.configure_notify_event_t = @ptrCast(event);
                    if (extent.width != configure.width or
                        extent.height != configure.height)
                    {
                        extent.width = configure.width;
                        extent.height = configure.height;
                        extent_changed = true;
                    }
                },
                .EXPOSE => {
                    // We paint everything every frame, so this message is pointless.
                },
                .KEY_PRESS => {
                    const key_press: *xcb.key_press_event_t = @ptrCast(event);
                    if (key_press.detail == 9) return std.process.cleanExit();
                },
                .KEY_RELEASE => {
                    // key up
                },
                .MOTION_NOTIFY => {
                    // mouse movement
                },
                .BUTTON_PRESS => {
                    // mouse down
                },
                .BUTTON_RELEASE => {
                    // mouse up
                },
                else => |t| {
                    std.log.debug("unhandled xcb message: {s}", .{@tagName(t)});
                },
            }
        }

        const cmdbuf = cmdbufs[swapchain.image_index];

        const state = swapchain.present(cmdbuf) catch |err| switch (err) {
            error.OutOfDateKHR => Swapchain.PresentState.suboptimal,
            else => |narrow| return narrow,
        };

        if (state == .suboptimal or extent_changed) {
            try swapchain.recreate(extent);

            destroyFramebuffers(&gc, gpa, framebuffers);
            framebuffers = try createFramebuffers(&gc, gpa, render_pass, swapchain);

            destroyCommandBuffers(&gc, pool, gpa, cmdbufs);
            cmdbufs = try createCommandBuffers(
                &gc,
                pool,
                gpa,
                buffer,
                swapchain.extent,
                render_pass,
                pipeline,
                framebuffers,
            );
        }
    }
}

fn uploadVertices(gc: *const GraphicsContext, pool: vk.CommandPool, buffer: vk.Buffer) !void {
    const staging_buffer = try gc.dev.createBuffer(&.{
        .size = @sizeOf(@TypeOf(vertices)),
        .usage = .{ .transfer_src_bit = true },
        .sharing_mode = .exclusive,
    }, null);
    defer gc.dev.destroyBuffer(staging_buffer, null);
    const mem_reqs = gc.dev.getBufferMemoryRequirements(staging_buffer);
    const staging_memory = try gc.allocate(mem_reqs, .{ .host_visible_bit = true, .host_coherent_bit = true });
    defer gc.dev.freeMemory(staging_memory, null);
    try gc.dev.bindBufferMemory(staging_buffer, staging_memory, 0);

    {
        const data = try gc.dev.mapMemory(staging_memory, 0, vk.WHOLE_SIZE, .{});
        defer gc.dev.unmapMemory(staging_memory);

        const gpu_vertices: [*]Vertex = @ptrCast(@alignCast(data));
        @memcpy(gpu_vertices, vertices[0..]);
    }

    try copyBuffer(gc, pool, buffer, staging_buffer, @sizeOf(@TypeOf(vertices)));
}

fn copyBuffer(gc: *const GraphicsContext, pool: vk.CommandPool, dst: vk.Buffer, src: vk.Buffer, size: vk.DeviceSize) !void {
    var cmdbuf_handle: vk.CommandBuffer = undefined;
    try gc.dev.allocateCommandBuffers(&.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&cmdbuf_handle));
    defer gc.dev.freeCommandBuffers(pool, 1, @ptrCast(&cmdbuf_handle));

    const cmdbuf = GraphicsContext.CommandBuffer.init(cmdbuf_handle, gc.dev.wrapper);

    try cmdbuf.beginCommandBuffer(&.{
        .flags = .{ .one_time_submit_bit = true },
    });

    const region = vk.BufferCopy{
        .src_offset = 0,
        .dst_offset = 0,
        .size = size,
    };
    cmdbuf.copyBuffer(src, dst, 1, @ptrCast(&region));

    try cmdbuf.endCommandBuffer();

    const si = vk.SubmitInfo{
        .command_buffer_count = 1,
        .p_command_buffers = (&cmdbuf.handle)[0..1],
        .p_wait_dst_stage_mask = undefined,
    };
    try gc.dev.queueSubmit(gc.graphics_queue.handle, 1, @ptrCast(&si), .null_handle);
    try gc.dev.queueWaitIdle(gc.graphics_queue.handle);
}

fn createCommandBuffers(
    gc: *const GraphicsContext,
    pool: vk.CommandPool,
    gpa: Allocator,
    buffer: vk.Buffer,
    extent: vk.Extent2D,
    render_pass: vk.RenderPass,
    pipeline: vk.Pipeline,
    framebuffers: []vk.Framebuffer,
) ![]vk.CommandBuffer {
    const cmdbufs = try gpa.alloc(vk.CommandBuffer, framebuffers.len);
    errdefer gpa.free(cmdbufs);

    try gc.dev.allocateCommandBuffers(&.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = @intCast(cmdbufs.len),
    }, cmdbufs.ptr);
    errdefer gc.dev.freeCommandBuffers(pool, @intCast(cmdbufs.len), cmdbufs.ptr);

    const clear: vk.ClearValue = .{
        .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
    };

    const viewport: vk.Viewport = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(extent.width),
        .height = @floatFromInt(extent.height),
        .min_depth = 0,
        .max_depth = 1,
    };

    const scissor: vk.Rect2D = .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = extent,
    };

    for (cmdbufs, framebuffers) |cmdbuf, framebuffer| {
        try gc.dev.beginCommandBuffer(cmdbuf, &.{});

        gc.dev.cmdSetViewport(cmdbuf, 0, 1, @ptrCast(&viewport));
        gc.dev.cmdSetScissor(cmdbuf, 0, 1, @ptrCast(&scissor));

        const render_area: vk.Rect2D = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = extent,
        };

        gc.dev.cmdBeginRenderPass(cmdbuf, &.{
            .render_pass = render_pass,
            .framebuffer = framebuffer,
            .render_area = render_area,
            .clear_value_count = 1,
            .p_clear_values = @ptrCast(&clear),
        }, .@"inline");

        gc.dev.cmdBindPipeline(cmdbuf, .graphics, pipeline);
        const offset = [_]vk.DeviceSize{0};
        gc.dev.cmdBindVertexBuffers(cmdbuf, 0, 1, @ptrCast(&buffer), &offset);
        gc.dev.cmdDraw(cmdbuf, vertices.len, 1, 0, 0);

        gc.dev.cmdEndRenderPass(cmdbuf);
        try gc.dev.endCommandBuffer(cmdbuf);
    }

    return cmdbufs;
}

fn destroyCommandBuffers(gc: *const GraphicsContext, pool: vk.CommandPool, gpa: Allocator, cmdbufs: []vk.CommandBuffer) void {
    gc.dev.freeCommandBuffers(pool, @truncate(cmdbufs.len), cmdbufs.ptr);
    gpa.free(cmdbufs);
}

fn createFramebuffers(gc: *const GraphicsContext, gpa: Allocator, render_pass: vk.RenderPass, swapchain: Swapchain) ![]vk.Framebuffer {
    const framebuffers = try gpa.alloc(vk.Framebuffer, swapchain.swap_images.len);
    errdefer gpa.free(framebuffers);

    var i: usize = 0;
    errdefer for (framebuffers[0..i]) |fb| gc.dev.destroyFramebuffer(fb, null);

    for (framebuffers) |*fb| {
        fb.* = try gc.dev.createFramebuffer(&.{
            .render_pass = render_pass,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&swapchain.swap_images[i].view),
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        }, null);
        i += 1;
    }

    return framebuffers;
}

fn destroyFramebuffers(gc: *const GraphicsContext, gpa: Allocator, framebuffers: []const vk.Framebuffer) void {
    for (framebuffers) |fb| gc.dev.destroyFramebuffer(fb, null);
    gpa.free(framebuffers);
}

fn createRenderPass(gc: *const GraphicsContext, swapchain: Swapchain) !vk.RenderPass {
    const color_attachment: vk.AttachmentDescription = .{
        .format = swapchain.surface_format.format,
        .samples = .{ .@"1_bit" = true },
        .load_op = .clear,
        .store_op = .store,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = .undefined,
        .final_layout = .present_src_khr,
    };

    const color_attachment_ref: vk.AttachmentReference = .{
        .attachment = 0,
        .layout = .color_attachment_optimal,
    };

    const subpass: vk.SubpassDescription = .{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_attachment_ref),
    };

    return try gc.dev.createRenderPass(&.{
        .attachment_count = 1,
        .p_attachments = @ptrCast(&color_attachment),
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);
}

fn createPipeline(
    gc: *const GraphicsContext,
    layout: vk.PipelineLayout,
    render_pass: vk.RenderPass,
) !vk.Pipeline {
    const vert = try gc.dev.createShaderModule(&.{
        .code_size = shader_triangle_vert.len,
        .p_code = @alignCast(@ptrCast(shader_triangle_vert)),
    }, null);
    defer gc.dev.destroyShaderModule(vert, null);

    const frag = try gc.dev.createShaderModule(&.{
        .code_size = shader_triangle_frag.len,
        .p_code = @alignCast(@ptrCast(shader_triangle_frag)),
    }, null);
    defer gc.dev.destroyShaderModule(frag, null);

    const pssci = [_]vk.PipelineShaderStageCreateInfo{
        .{
            .stage = .{ .vertex_bit = true },
            .module = vert,
            .p_name = "main",
        },
        .{
            .stage = .{ .fragment_bit = true },
            .module = frag,
            .p_name = "main",
        },
    };

    const pvisci = vk.PipelineVertexInputStateCreateInfo{
        .vertex_binding_description_count = 1,
        .p_vertex_binding_descriptions = @ptrCast(&Vertex.binding_description),
        .vertex_attribute_description_count = Vertex.attribute_description.len,
        .p_vertex_attribute_descriptions = &Vertex.attribute_description,
    };

    const piasci = vk.PipelineInputAssemblyStateCreateInfo{
        .topology = .triangle_list,
        .primitive_restart_enable = vk.FALSE,
    };

    const pvsci = vk.PipelineViewportStateCreateInfo{
        .viewport_count = 1,
        .p_viewports = undefined, // set in createCommandBuffers with cmdSetViewport
        .scissor_count = 1,
        .p_scissors = undefined, // set in createCommandBuffers with cmdSetScissor
    };

    const prsci = vk.PipelineRasterizationStateCreateInfo{
        .depth_clamp_enable = vk.FALSE,
        .rasterizer_discard_enable = vk.FALSE,
        .polygon_mode = .fill,
        .cull_mode = .{ .back_bit = true },
        .front_face = .clockwise,
        .depth_bias_enable = vk.FALSE,
        .depth_bias_constant_factor = 0,
        .depth_bias_clamp = 0,
        .depth_bias_slope_factor = 0,
        .line_width = 1,
    };

    const pmsci = vk.PipelineMultisampleStateCreateInfo{
        .rasterization_samples = .{ .@"1_bit" = true },
        .sample_shading_enable = vk.FALSE,
        .min_sample_shading = 1,
        .alpha_to_coverage_enable = vk.FALSE,
        .alpha_to_one_enable = vk.FALSE,
    };

    const pcbas = vk.PipelineColorBlendAttachmentState{
        .blend_enable = vk.FALSE,
        .src_color_blend_factor = .one,
        .dst_color_blend_factor = .zero,
        .color_blend_op = .add,
        .src_alpha_blend_factor = .one,
        .dst_alpha_blend_factor = .zero,
        .alpha_blend_op = .add,
        .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
    };

    const pcbsci = vk.PipelineColorBlendStateCreateInfo{
        .logic_op_enable = vk.FALSE,
        .logic_op = .copy,
        .attachment_count = 1,
        .p_attachments = @ptrCast(&pcbas),
        .blend_constants = [_]f32{ 0, 0, 0, 0 },
    };

    const dynstate = [_]vk.DynamicState{ .viewport, .scissor };
    const pdsci = vk.PipelineDynamicStateCreateInfo{
        .flags = .{},
        .dynamic_state_count = dynstate.len,
        .p_dynamic_states = &dynstate,
    };

    const gpci = vk.GraphicsPipelineCreateInfo{
        .flags = .{},
        .stage_count = 2,
        .p_stages = &pssci,
        .p_vertex_input_state = &pvisci,
        .p_input_assembly_state = &piasci,
        .p_tessellation_state = null,
        .p_viewport_state = &pvsci,
        .p_rasterization_state = &prsci,
        .p_multisample_state = &pmsci,
        .p_depth_stencil_state = null,
        .p_color_blend_state = &pcbsci,
        .p_dynamic_state = &pdsci,
        .layout = layout,
        .render_pass = render_pass,
        .subpass = 0,
        .base_pipeline_handle = .null_handle,
        .base_pipeline_index = -1,
    };

    var pipeline: vk.Pipeline = undefined;
    _ = try gc.dev.createGraphicsPipelines(
        .null_handle,
        1,
        @ptrCast(&gpci),
        null,
        @ptrCast(&pipeline),
    );
    return pipeline;
}

fn get_atom(conn: *xcb.connection_t, name: [:0]const u8) error{OutOfMemory}!xcb.atom_t {
    const cookie = xcb.intern_atom(conn, 0, @intCast(name.len), name.ptr);
    if (xcb.intern_atom_reply(conn, cookie, null)) |r| {
        defer std.c.free(r);
        return r.atom;
    }
    return error.OutOfMemory;
}
