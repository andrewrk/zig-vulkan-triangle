const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;
const c = @import("vulkan.zig");

const WIDTH = 800;
const HEIGHT = 600;

const MAX_FRAMES_IN_FLIGHT = 2;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [][*]const u8{c"VK_LAYER_LUNARG_standard_validation"};
const deviceExtensions = [][*]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

var currentFrame: usize = 0;
var instance: c.VkInstance = undefined;
var callback: c.VkDebugReportCallbackEXT = undefined;
var surface: c.VkSurfaceKHR = undefined;
var physicalDevice: c.VkPhysicalDevice = undefined;
var global_device: c.VkDevice = undefined;
var graphicsQueue: c.VkQueue = undefined;
var presentQueue: c.VkQueue = undefined;
var swapChainImages: []c.VkImage = undefined;
var swapChain: c.VkSwapchainKHR = undefined;
var swapChainImageFormat: c.VkFormat = undefined;
var swapChainExtent: c.VkExtent2D = undefined;
var swapChainImageViews: []c.VkImageView = undefined;
var renderPass: c.VkRenderPass = undefined;
var pipelineLayout: c.VkPipelineLayout = undefined;
var graphicsPipeline: c.VkPipeline = undefined;
var swapChainFramebuffers: []c.VkFramebuffer = undefined;
var commandPool: c.VkCommandPool = undefined;
var commandBuffers: []c.VkCommandBuffer = undefined;

var imageAvailableSemaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore = undefined;
var renderFinishedSemaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore = undefined;
var inFlightFences: [MAX_FRAMES_IN_FLIGHT]c.VkFence = undefined;

const QueueFamilyIndices = struct {
    graphicsFamily: ?u32,
    presentFamily: ?u32,

    fn init() QueueFamilyIndices {
        return QueueFamilyIndices{
            .graphicsFamily = null,
            .presentFamily = null,
        };
    }

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null and self.presentFamily != null;
    }
};

const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: std.ArrayList(c.VkSurfaceFormatKHR),
    presentModes: std.ArrayList(c.VkPresentModeKHR),

    fn init(allocator: *Allocator) SwapChainSupportDetails {
        var result = SwapChainSupportDetails{
            .capabilities = undefined,
            .formats = std.ArrayList(c.VkSurfaceFormatKHR).init(allocator),
            .presentModes = std.ArrayList(c.VkPresentModeKHR).init(allocator),
        };
        const slice = @sliceToBytes((*[1]c.VkSurfaceCapabilitiesKHR)(&result.capabilities)[0..1]);
        std.mem.set(u8, slice, 0);
        return result;
    }

    fn deinit(self: *SwapChainSupportDetails) void {
        self.formats.deinit();
        self.presentModes.deinit();
    }
};

pub fn main() !void {
    if (c.glfwInit() == 0) return error.GlfwInitFailed;
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);

    const window = c.glfwCreateWindow(WIDTH, HEIGHT, c"Zig Vulkan Triangle", null, null) orelse return error.GlfwCreateWindowFailed;
    defer c.glfwDestroyWindow(window);

    const allocator = std.heap.c_allocator;
    try initVulkan(allocator, window);

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();
        try drawFrame();
    }
    try checkSuccess(c.vkDeviceWaitIdle(global_device));

    cleanup();
}

fn cleanup() void {
    // TODO
    //for (size_t i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
    //    vkDestroySemaphore(device, renderFinishedSemaphores[i], nullptr);
    //    vkDestroySemaphore(device, imageAvailableSemaphores[i], nullptr);
    //    vkDestroyFence(device, inFlightFences[i], nullptr);
    //}

    //vkDestroyCommandPool(device, commandPool, nullptr);

    //for (auto framebuffer : swapChainFramebuffers) {
    //    vkDestroyFramebuffer(device, framebuffer, nullptr);
    //}

    //vkDestroyPipeline(device, graphicsPipeline, nullptr);
    //vkDestroyPipelineLayout(device, pipelineLayout, nullptr);
    //vkDestroyRenderPass(device, renderPass, nullptr);

    //for (auto imageView : swapChainImageViews) {
    //    vkDestroyImageView(device, imageView, nullptr);
    //}

    //vkDestroySwapchainKHR(device, swapChain, nullptr);
    //vkDestroyDevice(device, nullptr);

    //if (enableValidationLayers) {
    //    DestroyDebugReportCallbackEXT(instance, callback, nullptr);
    //}

    //vkDestroySurfaceKHR(instance, surface, nullptr);
    //vkDestroyInstance(instance, nullptr);

    //glfwDestroyWindow(window);

    //glfwTerminate();
}

fn initVulkan(allocator: *Allocator, window: *c.GLFWwindow) !void {
    try createInstance(allocator);
    try setupDebugCallback();
    try createSurface(window);
    try pickPhysicalDevice(allocator);
    try createLogicalDevice(allocator);
    try createSwapChain(allocator);
    try createImageViews(allocator);
    try createRenderPass();
    try createGraphicsPipeline(allocator);
    try createFramebuffers(allocator);
    try createCommandPool(allocator);
    try createCommandBuffers(allocator);
    try createSyncObjects();
}

fn createCommandBuffers(allocator: *Allocator) !void {
    commandBuffers = try allocator.alloc(c.VkCommandBuffer, swapChainFramebuffers.len);

    const allocInfo = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = commandPool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(u32, commandBuffers.len),
        .pNext = null,
    };

    try checkSuccess(c.vkAllocateCommandBuffers(global_device, &allocInfo, commandBuffers.ptr));

    for (commandBuffers) |command_buffer, i| {
        const beginInfo = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT,
            .pNext = null,
            .pInheritanceInfo = null,
        };

        try checkSuccess(c.vkBeginCommandBuffer(commandBuffers[i], &beginInfo));

        const clearColor = c.VkClearValue{ .color = c.VkClearColorValue{ .float32 = []f32{ 0.0, 0.0, 0.0, 1.0 } } };

        const renderPassInfo = c.VkRenderPassBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = renderPass,
            .framebuffer = swapChainFramebuffers[i],
            .renderArea = c.VkRect2D{
                .offset = c.VkOffset2D{ .x = 0, .y = 0 },
                .extent = swapChainExtent,
            },
            .clearValueCount = 1,
            .pClearValues = (*[1]c.VkClearValue)(&clearColor),

            .pNext = null,
        };

        c.vkCmdBeginRenderPass(commandBuffers[i], &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
        {
            c.vkCmdBindPipeline(commandBuffers[i], c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
            c.vkCmdDraw(commandBuffers[i], 3, 1, 0, 0);
        }
        c.vkCmdEndRenderPass(commandBuffers[i]);

        try checkSuccess(c.vkEndCommandBuffer(commandBuffers[i]));
    }
}

fn createSyncObjects() !void {
    const semaphoreInfo = c.VkSemaphoreCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    const fenceInfo = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        .pNext = null,
    };

    var i: usize = 0;
    while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
        try checkSuccess(c.vkCreateSemaphore(global_device, &semaphoreInfo, null, &imageAvailableSemaphores[i]));
        try checkSuccess(c.vkCreateSemaphore(global_device, &semaphoreInfo, null, &renderFinishedSemaphores[i]));
        try checkSuccess(c.vkCreateFence(global_device, &fenceInfo, null, &inFlightFences[i]));
    }
}

fn createCommandPool(allocator: *Allocator) !void {
    const queueFamilyIndices = try findQueueFamilies(allocator, physicalDevice);

    const poolInfo = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = queueFamilyIndices.graphicsFamily.?,

        .pNext = null,
        .flags = 0,
    };

    try checkSuccess(c.vkCreateCommandPool(global_device, &poolInfo, null, &commandPool));
}

fn createFramebuffers(allocator: *Allocator) !void {
    swapChainFramebuffers = try allocator.alloc(c.VkFramebuffer, swapChainImageViews.len);

    for (swapChainImageViews) |swap_chain_image_view, i| {
        const attachments = []c.VkImageView{swap_chain_image_view};

        const framebufferInfo = c.VkFramebufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = renderPass,
            .attachmentCount = 1,
            .pAttachments = &attachments,
            .width = swapChainExtent.width,
            .height = swapChainExtent.height,
            .layers = 1,

            .pNext = null,
            .flags = 0,
        };

        try checkSuccess(c.vkCreateFramebuffer(global_device, &framebufferInfo, null, &swapChainFramebuffers[i]));
    }
}

fn createShaderModule(code: []align(@alignOf(u32)) const u8) !c.VkShaderModule {
    const createInfo = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = @bytesToSlice(u32, code).ptr,

        .pNext = null,
        .flags = 0,
    };

    var shaderModule: c.VkShaderModule = undefined;
    try checkSuccess(c.vkCreateShaderModule(global_device, &createInfo, null, &shaderModule));

    return shaderModule;
}

fn createGraphicsPipeline(allocator: *Allocator) !void {
    const vertShaderCode = try std.io.readFileAllocAligned(allocator, "shaders/vert.spv", @alignOf(u32));
    defer allocator.free(vertShaderCode);

    const fragShaderCode = try std.io.readFileAllocAligned(allocator, "shaders/frag.spv", @alignOf(u32));
    defer allocator.free(fragShaderCode);

    const vertShaderModule = try createShaderModule(vertShaderCode);
    const fragShaderModule = try createShaderModule(fragShaderCode);

    const vertShaderStageInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertShaderModule,
        .pName = c"main",

        .pNext = null,
        .flags = 0,
        .pSpecializationInfo = null,
    };

    const fragShaderStageInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragShaderModule,
        .pName = c"main",
        .pNext = null,
        .flags = 0,

        .pSpecializationInfo = null,
    };

    const shaderStages = []c.VkPipelineShaderStageCreateInfo{ vertShaderStageInfo, fragShaderStageInfo };

    const vertexInputInfo = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 0,
        .vertexAttributeDescriptionCount = 0,

        .pVertexBindingDescriptions = null,
        .pVertexAttributeDescriptions = null,
        .pNext = null,
        .flags = 0,
    };

    const inputAssembly = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };

    const viewport = []c.VkViewport{c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @intToFloat(f32, swapChainExtent.width),
        .height = @intToFloat(f32, swapChainExtent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    }};

    const scissor = []c.VkRect2D{c.VkRect2D{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = swapChainExtent,
    }};

    const viewportState = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,

        .pNext = null,
        .flags = 0,
    };

    const rasterizer = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = @intCast(u32, @enumToInt(c.VK_CULL_MODE_BACK_BIT)),
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,

        .pNext = null,
        .flags = 0,
        .depthBiasConstantFactor = 0,
        .depthBiasClamp = 0,
        .depthBiasSlopeFactor = 0,
    };

    const multisampling = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .pNext = null,
        .flags = 0,
        .minSampleShading = 0,
        .pSampleMask = null,
        .alphaToCoverageEnable = 0,
        .alphaToOneEnable = 0,
    };

    const colorBlendAttachment = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,

        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    const colorBlending = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlendAttachment,
        .blendConstants = []f32{ 0, 0, 0, 0 },

        .pNext = null,
        .flags = 0,
    };

    const pipelineLayoutInfo = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 0,
        .pushConstantRangeCount = 0,
        .pNext = null,
        .flags = 0,
        .pSetLayouts = null,
        .pPushConstantRanges = null,
    };

    try checkSuccess(c.vkCreatePipelineLayout(global_device, &pipelineLayoutInfo, null, &pipelineLayout));

    const pipelineInfo = []c.VkGraphicsPipelineCreateInfo{c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = @intCast(u32, shaderStages.len),
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputInfo,
        .pInputAssemblyState = &inputAssembly,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &colorBlending,
        .layout = pipelineLayout,
        .renderPass = renderPass,
        .subpass = 0,
        .basePipelineHandle = null,

        .pNext = null,
        .flags = 0,
        .pTessellationState = null,
        .pDepthStencilState = null,
        .pDynamicState = null,
        .basePipelineIndex = 0,
    }};

    try checkSuccess(c.vkCreateGraphicsPipelines(
        global_device,
        null,
        @intCast(u32, pipelineInfo.len),
        &pipelineInfo,
        null,
        (*[1]c.VkPipeline)(&graphicsPipeline),
    ));

    c.vkDestroyShaderModule(global_device, fragShaderModule, null);
    c.vkDestroyShaderModule(global_device, vertShaderModule, null);
}

fn createRenderPass() !void {
    const colorAttachment = c.VkAttachmentDescription{
        .format = swapChainImageFormat,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };

    const colorAttachmentRef = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const subpass = []c.VkSubpassDescription{c.VkSubpassDescription{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = (*[1]c.VkAttachmentReference)(&colorAttachmentRef),

        .flags = 0,
        .inputAttachmentCount = 0,
        .pInputAttachments = null,
        .pResolveAttachments = null,
        .pDepthStencilAttachment = null,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null,
    }};

    const dependency = []c.VkSubpassDependency{c.VkSubpassDependency{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,

        .dependencyFlags = 0,
    }};

    const renderPassInfo = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = (*[1]c.VkAttachmentDescription)(&colorAttachment),
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,

        .pNext = null,
        .flags = 0,
    };

    try checkSuccess(c.vkCreateRenderPass(global_device, &renderPassInfo, null, &renderPass));
}

fn createImageViews(allocator: *Allocator) !void {
    swapChainImageViews = try allocator.alloc(c.VkImageView, swapChainImages.len);
    errdefer allocator.free(swapChainImageViews);

    for (swapChainImages) |swap_chain_image, i| {
        const createInfo = c.VkImageViewCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = swap_chain_image,
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = swapChainImageFormat,
            .components = c.VkComponentMapping{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = c.VkImageSubresourceRange{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },

            .pNext = null,
            .flags = 0,
        };

        try checkSuccess(c.vkCreateImageView(global_device, &createInfo, null, &swapChainImageViews[i]));
    }
}

fn chooseSwapSurfaceFormat(availableFormats: []c.VkSurfaceFormatKHR) c.VkSurfaceFormatKHR {
    if (availableFormats.len == 1 and availableFormats[0].format == c.VK_FORMAT_UNDEFINED) {
        return c.VkSurfaceFormatKHR{
            .format = c.VK_FORMAT_B8G8R8A8_UNORM,
            .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        };
    }

    for (availableFormats) |availableFormat| {
        if (availableFormat.format == c.VK_FORMAT_B8G8R8A8_UNORM and
            availableFormat.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return availableFormat;
        }
    }

    return availableFormats[0];
}

fn chooseSwapPresentMode(availablePresentModes: []c.VkPresentModeKHR) c.VkPresentModeKHR {
    var bestMode: c.VkPresentModeKHR = c.VK_PRESENT_MODE_FIFO_KHR;

    for (availablePresentModes) |availablePresentMode| {
        if (availablePresentMode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            return availablePresentMode;
        } else if (availablePresentMode == c.VK_PRESENT_MODE_IMMEDIATE_KHR) {
            bestMode = availablePresentMode;
        }
    }

    return bestMode;
}

fn chooseSwapExtent(capabilities: *const c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    if (capabilities.currentExtent.width != @maxValue(u32)) {
        return capabilities.currentExtent;
    } else {
        var actualExtent = c.VkExtent2D{
            .width = WIDTH,
            .height = HEIGHT,
        };

        actualExtent.width = std.math.max(capabilities.minImageExtent.width, std.math.min(capabilities.maxImageExtent.width, actualExtent.width));
        actualExtent.height = std.math.max(capabilities.minImageExtent.height, std.math.min(capabilities.maxImageExtent.height, actualExtent.height));

        return actualExtent;
    }
}

fn createSwapChain(allocator: *Allocator) !void {
    const swapChainSupport = try querySwapChainSupport(allocator, physicalDevice);

    const surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats.toSlice());
    const presentMode = chooseSwapPresentMode(swapChainSupport.presentModes.toSlice());
    const extent = chooseSwapExtent(swapChainSupport.capabilities);

    var imageCount: u32 = swapChainSupport.capabilities.minImageCount + 1;
    if (swapChainSupport.capabilities.maxImageCount > 0 and
        imageCount > swapChainSupport.capabilities.maxImageCount)
    {
        imageCount = swapChainSupport.capabilities.maxImageCount;
    }

    const indices = try findQueueFamilies(allocator, physicalDevice);
    const queueFamilyIndices = []u32{ indices.graphicsFamily.?, indices.presentFamily.? };

    const different_families = indices.graphicsFamily.? != indices.presentFamily.?;

    var createInfo = c.VkSwapchainCreateInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,

        .minImageCount = imageCount,
        .imageFormat = surfaceFormat.format,
        .imageColorSpace = surfaceFormat.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

        .imageSharingMode = if (different_families) c.VK_SHARING_MODE_CONCURRENT else c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = if (different_families) u32(2) else u32(0),
        .pQueueFamilyIndices = if (different_families) &queueFamilyIndices else &([]u32{ 0, 0 }),

        .preTransform = swapChainSupport.capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = presentMode,
        .clipped = c.VK_TRUE,

        .oldSwapchain = null,

        .pNext = null,
        .flags = 0,
    };

    try checkSuccess(c.vkCreateSwapchainKHR(global_device, &createInfo, null, &swapChain));

    try checkSuccess(c.vkGetSwapchainImagesKHR(global_device, swapChain, &imageCount, null));
    swapChainImages = try allocator.alloc(c.VkImage, imageCount);
    try checkSuccess(c.vkGetSwapchainImagesKHR(global_device, swapChain, &imageCount, swapChainImages.ptr));

    swapChainImageFormat = surfaceFormat.format;
    swapChainExtent = extent;
}

fn createLogicalDevice(allocator: *Allocator) !void {
    const indices = try findQueueFamilies(allocator, physicalDevice);

    var queueCreateInfos = std.ArrayList(c.VkDeviceQueueCreateInfo).init(allocator);
    defer queueCreateInfos.deinit();
    const all_queue_families = []u32{ indices.graphicsFamily.?, indices.presentFamily.? };
    const uniqueQueueFamilies = if (indices.graphicsFamily.? == indices.presentFamily.?)
        all_queue_families[0..1]
    else
        all_queue_families[0..2];

    var queuePriority: f32 = 1.0;
    for (uniqueQueueFamilies) |queueFamily| {
        const queueCreateInfo = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queueFamily,
            .queueCount = 1,
            .pQueuePriorities = &queuePriority,
            .pNext = null,
            .flags = 0,
        };
        try queueCreateInfos.append(queueCreateInfo);
    }

    const deviceFeatures = c.VkPhysicalDeviceFeatures{
        .robustBufferAccess = 0,
        .fullDrawIndexUint32 = 0,
        .imageCubeArray = 0,
        .independentBlend = 0,
        .geometryShader = 0,
        .tessellationShader = 0,
        .sampleRateShading = 0,
        .dualSrcBlend = 0,
        .logicOp = 0,
        .multiDrawIndirect = 0,
        .drawIndirectFirstInstance = 0,
        .depthClamp = 0,
        .depthBiasClamp = 0,
        .fillModeNonSolid = 0,
        .depthBounds = 0,
        .wideLines = 0,
        .largePoints = 0,
        .alphaToOne = 0,
        .multiViewport = 0,
        .samplerAnisotropy = 0,
        .textureCompressionETC2 = 0,
        .textureCompressionASTC_LDR = 0,
        .textureCompressionBC = 0,
        .occlusionQueryPrecise = 0,
        .pipelineStatisticsQuery = 0,
        .vertexPipelineStoresAndAtomics = 0,
        .fragmentStoresAndAtomics = 0,
        .shaderTessellationAndGeometryPointSize = 0,
        .shaderImageGatherExtended = 0,
        .shaderStorageImageExtendedFormats = 0,
        .shaderStorageImageMultisample = 0,
        .shaderStorageImageReadWithoutFormat = 0,
        .shaderStorageImageWriteWithoutFormat = 0,
        .shaderUniformBufferArrayDynamicIndexing = 0,
        .shaderSampledImageArrayDynamicIndexing = 0,
        .shaderStorageBufferArrayDynamicIndexing = 0,
        .shaderStorageImageArrayDynamicIndexing = 0,
        .shaderClipDistance = 0,
        .shaderCullDistance = 0,
        .shaderFloat64 = 0,
        .shaderInt64 = 0,
        .shaderInt16 = 0,
        .shaderResourceResidency = 0,
        .shaderResourceMinLod = 0,
        .sparseBinding = 0,
        .sparseResidencyBuffer = 0,
        .sparseResidencyImage2D = 0,
        .sparseResidencyImage3D = 0,
        .sparseResidency2Samples = 0,
        .sparseResidency4Samples = 0,
        .sparseResidency8Samples = 0,
        .sparseResidency16Samples = 0,
        .sparseResidencyAliased = 0,
        .variableMultisampleRate = 0,
        .inheritedQueries = 0,
    };

    const createInfo = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,

        .queueCreateInfoCount = @intCast(u32, queueCreateInfos.len),
        .pQueueCreateInfos = queueCreateInfos.items.ptr,

        .pEnabledFeatures = &deviceFeatures,

        .enabledExtensionCount = @intCast(u32, deviceExtensions.len),
        .ppEnabledExtensionNames = &deviceExtensions,
        .enabledLayerCount = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
        .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else null,

        .pNext = null,
        .flags = 0,
    };

    try checkSuccess(c.vkCreateDevice(physicalDevice, &createInfo, null, &global_device));

    c.vkGetDeviceQueue(global_device, indices.graphicsFamily.?, 0, &graphicsQueue);
    c.vkGetDeviceQueue(global_device, indices.presentFamily.?, 0, &presentQueue);
}

fn pickPhysicalDevice(allocator: *Allocator) !void {
    var deviceCount: u32 = 0;
    try checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, null));

    if (deviceCount == 0) {
        return error.FailedToFindGPUsWithVulkanSupport;
    }

    const devices = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    defer allocator.free(devices);
    try checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, devices.ptr));

    physicalDevice = for (devices) |device| {
        if (try isDeviceSuitable(allocator, device)) {
            break device;
        }
    } else return error.FailedToFindSuitableGPU;
}

fn findQueueFamilies(allocator: *Allocator, device: c.VkPhysicalDevice) !QueueFamilyIndices {
    var indices = QueueFamilyIndices.init();

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    defer allocator.free(queueFamilies);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var i: u32 = 0;
    for (queueFamilies) |queueFamily| {
        if (queueFamily.queueCount > 0 and
            queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0)
        {
            indices.graphicsFamily = i;
        }

        var presentSupport: c.VkBool32 = 0;
        try checkSuccess(c.vkGetPhysicalDeviceSurfaceSupportKHR(device, i, surface, &presentSupport));

        if (queueFamily.queueCount > 0 and presentSupport != 0) {
            indices.presentFamily = i;
        }

        if (indices.isComplete()) {
            break;
        }

        i += 1;
    }

    return indices;
}

fn isDeviceSuitable(allocator: *Allocator, device: c.VkPhysicalDevice) !bool {
    const indices = try findQueueFamilies(allocator, device);

    const extensionsSupported = try checkDeviceExtensionSupport(allocator, device);

    var swapChainAdequate = false;
    if (extensionsSupported) {
        const swapChainSupport = try querySwapChainSupport(allocator, device);
        swapChainAdequate = swapChainSupport.formats.len != 0 and swapChainSupport.presentModes.len != 0;
    }

    return indices.isComplete() and extensionsSupported and swapChainAdequate;
}

fn querySwapChainSupport(allocator: *Allocator, device: c.VkPhysicalDevice) !SwapChainSupportDetails {
    var details = SwapChainSupportDetails.init(allocator);
    defer details.deinit();

    try checkSuccess(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities));

    var formatCount: u32 = undefined;
    try checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, null));

    if (formatCount != 0) {
        try details.formats.resize(formatCount);
        try checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, details.formats.items.ptr));
    }

    var presentModeCount: u32 = undefined;
    try checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, null));

    if (presentModeCount != 0) {
        try details.presentModes.resize(presentModeCount);
        try checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, details.presentModes.items.ptr));
    }

    return details;
}

fn checkDeviceExtensionSupport(allocator: *Allocator, device: c.VkPhysicalDevice) !bool {
    var extensionCount: u32 = undefined;
    try checkSuccess(c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, null));

    const availableExtensions = try allocator.alloc(c.VkExtensionProperties, extensionCount);
    defer allocator.free(availableExtensions);
    try checkSuccess(c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, availableExtensions.ptr));

    var requiredExtensions = std.HashMap([*]const u8, void, hash_cstr, eql_cstr).init(allocator);
    defer requiredExtensions.deinit();
    for (deviceExtensions) |device_ext| {
        _ = try requiredExtensions.put(device_ext, {});
    }

    for (availableExtensions) |extension| {
        _ = requiredExtensions.remove(&extension.extensionName);
    }

    return requiredExtensions.count() == 0;
}

fn createSurface(window: *c.GLFWwindow) !void {
    if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VK_SUCCESS) {
        return error.FailedToCreateWindowSurface;
    }
}

// TODO https://github.com/ziglang/zig/issues/661
// Doesn't work on Windows until the above is fixed, because
// this function needs to be stdcallcc on Windows.
extern fn debugCallback(
    flags: c.VkDebugReportFlagsEXT,
    objType: c.VkDebugReportObjectTypeEXT,
    obj: u64,
    location: usize,
    code: i32,
    layerPrefix: [*]const u8,
    msg: [*]const u8,
    userData: ?*c_void,
) c.VkBool32 {
    std.debug.warn("validation layer: {s}\n", msg);
    return c.VK_FALSE;
}

fn setupDebugCallback() !void {
    if (!enableValidationLayers) return;

    var createInfo = c.VkDebugReportCallbackCreateInfoEXT{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT,
        .flags = c.VK_DEBUG_REPORT_ERROR_BIT_EXT | c.VK_DEBUG_REPORT_WARNING_BIT_EXT,
        .pfnCallback = debugCallback,
        .pNext = null,
        .pUserData = null,
    };

    if (CreateDebugReportCallbackEXT(&createInfo, null, &callback) != c.VK_SUCCESS) {
        return error.FailedToSetUpDebugCallback;
    }
}

fn CreateDebugReportCallbackEXT(
    pCreateInfo: *const c.VkDebugReportCallbackCreateInfoEXT,
    pAllocator: ?*const c.VkAllocationCallbacks,
    pCallback: *c.VkDebugReportCallbackEXT,
) c.VkResult {
    const func = @ptrCast(c.PFN_vkCreateDebugReportCallbackEXT, c.vkGetInstanceProcAddr(
        instance,
        c"vkCreateDebugReportCallbackEXT",
    )) orelse return c.VK_ERROR_EXTENSION_NOT_PRESENT;
    return func(instance, pCreateInfo, pAllocator, pCallback);
}

fn createInstance(allocator: *Allocator) !void {
    if (enableValidationLayers) {
        if (!(try checkValidationLayerSupport(allocator))) {
            return error.ValidationLayerRequestedButNotAvailable;
        }
    }

    const appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = c"Hello Triangle",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = c"No Engine",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
        .pNext = null,
    };

    const extensions = try getRequiredExtensions(allocator);
    defer allocator.free(extensions);

    const createInfo = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .enabledExtensionCount = @intCast(u32, extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
        .enabledLayerCount = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
        .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else null,
        .pNext = null,
        .flags = 0,
    };

    try checkSuccess(c.vkCreateInstance(&createInfo, null, &instance));
}

/// caller must free returned memory
fn getRequiredExtensions(allocator: *Allocator) ![][*]const u8 {
    var glfwExtensionCount: u32 = 0;
    var glfwExtensions: [*]const [*]const u8 = c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

    var extensions = std.ArrayList([*]const u8).init(allocator);
    errdefer extensions.deinit();

    try extensions.appendSlice(glfwExtensions[0..glfwExtensionCount]);

    if (enableValidationLayers) {
        try extensions.append(c.VK_EXT_DEBUG_REPORT_EXTENSION_NAME);
    }

    return extensions.toOwnedSlice();
}

fn checkSuccess(result: c.VkResult) !void {
    switch (result) {
        c.VK_SUCCESS => {},
        else => return error.Unexpected,
    }
}

fn checkValidationLayerSupport(allocator: *Allocator) !bool {
    var layerCount: u32 = undefined;

    try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, null));

    const availableLayers = try allocator.alloc(c.VkLayerProperties, layerCount);
    defer allocator.free(availableLayers);

    try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr));

    for (validationLayers) |layerName| {
        var layerFound = false;

        for (availableLayers) |layerProperties| {
            if (std.cstr.cmp(layerName, &layerProperties.layerName) == 0) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) {
            return false;
        }
    }

    return true;
}

fn drawFrame() !void {
    try checkSuccess(c.vkWaitForFences(global_device, 1, (*[1]c.VkFence)(&inFlightFences[currentFrame]), c.VK_TRUE, @maxValue(u64)));
    try checkSuccess(c.vkResetFences(global_device, 1, (*[1]c.VkFence)(&inFlightFences[currentFrame])));

    var imageIndex: u32 = undefined;
    try checkSuccess(c.vkAcquireNextImageKHR(global_device, swapChain, @maxValue(u64), imageAvailableSemaphores[currentFrame], null, &imageIndex));

    var waitSemaphores = []c.VkSemaphore{imageAvailableSemaphores[currentFrame]};
    var waitStages = []c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

    const signalSemaphores = []c.VkSemaphore{renderFinishedSemaphores[currentFrame]};

    var submitInfo = []c.VkSubmitInfo{c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &waitSemaphores,
        .pWaitDstStageMask = &waitStages,
        .commandBufferCount = 1,
        .pCommandBuffers = commandBuffers.ptr + imageIndex,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &signalSemaphores,

        .pNext = null,
    }};

    try checkSuccess(c.vkQueueSubmit(graphicsQueue, 1, &submitInfo, inFlightFences[currentFrame]));

    const swapChains = []c.VkSwapchainKHR{swapChain};
    const presentInfo = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,

        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signalSemaphores,

        .swapchainCount = 1,
        .pSwapchains = &swapChains,

        .pImageIndices = (*[1]u32)(&imageIndex),

        .pNext = null,
        .pResults = null,
    };

    try checkSuccess(c.vkQueuePresentKHR(presentQueue, &presentInfo));

    currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
}

fn hash_cstr(a: [*]const u8) u32 {
    return 0; // TODO
}

fn eql_cstr(a: [*]const u8, b: [*]const u8) bool {
    return std.cstr.cmp(a, b) == 0;
}
