const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;
const c = @import("vulkan.zig");

fn VK_MAKE_VERSION(major: u32, minor: u32, patch: u32) u32 {
    return ((major << u5(22)) | (minor << u5(12))) | patch;
}
const VK_API_VERSION_1_0 = VK_MAKE_VERSION(1, 0, 0);

const WIDTH = 800;
const HEIGHT = 600;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [][*]const u8{c"VK_LAYER_LUNARG_standard_validation"};

pub fn main() !void {
    if (c.glfwInit() == 0) return error.GlfwInitFailed;
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);

    const window = c.glfwCreateWindow(WIDTH, HEIGHT, c"SAW", null, null) orelse return error.GlfwCreateWindowFailed;
    defer c.glfwDestroyWindow(window);

    const allocator = std.heap.c_allocator;
    try initVulkan(allocator);

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();
        //drawFrame();
    }
    //c.vkDeviceWaitIdle(device);

    std.debug.warn("TODO port the cleanup function");
}

var imageAvailableSemaphores: std.ArrayList(c.VkSemaphore) = undefined;
var renderFinishedSemaphores: std.ArrayList(c.VkSemaphore) = undefined;
var inflightFences: std.ArrayList(c.VkFence) = undefined;
var currentFrame: usize = 0;
var instance: c.VkInstance = undefined;

fn initVulkan(allocator: *Allocator) !void {
    try createInstance(allocator);
    // TODO
    //setupDebugCallback();
    //createSurface();
    //pickPhysicalDevice();
    //createLogicalDevice();
    //createSwapChain();
    //createImageViews();
    //createRenderPass();
    //createGraphicsPipeline();
    //createFramebuffers();
    //createCommandPool();
    //createCommandBuffers();
    //createSyncObjects();
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
        .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = c"No Engine",
        .engineVersion = VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = VK_API_VERSION_1_0,
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

fn drawFrame() void {
    //c.vkWaitForFences(device, 1, &inFlightFences[currentFrame], c.VK_TRUE, @maxValue(u64));
    //c.vkResetFences(device, 1, &inFlightFences[currentFrame]);

    //var imageIndex: u32 = undefined;
    //c.vkAcquireNextImageKHR(device, swapChain, std::numeric_limits<uint64_t>::max(), imageAvailableSemaphores[currentFrame], VK_NULL_HANDLE, &imageIndex);

    //var waitSemaphores = []c.VkSemaphore{imageAvailableSemaphores.at(currentFrame)};
    //var waitStages = []c.VkPipelineStageFlags{VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

    //var submitInfo = VkSubmitInfo{
    //    .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
    //    .waitSemaphoreCount = 1,
    //    .pWaitSemaphores = &waitSemaphores,
    //    .pWaitDstStageMask = &waitStages,
    //};

    //submitInfo.commandBufferCount = 1;
    //submitInfo.pCommandBuffers = &commandBuffers[imageIndex];

    //VkSemaphore signalSemaphores[] = {renderFinishedSemaphores[currentFrame]};
    //submitInfo.signalSemaphoreCount = 1;
    //submitInfo.pSignalSemaphores = signalSemaphores;

    //if (c.vkQueueSubmit(graphicsQueue, 1, &submitInfo, inFlightFences[currentFrame]) != VK_SUCCESS) {
    //    throw std::runtime_error("failed to submit draw command buffer!");
    //}

    //VkPresentInfoKHR presentInfo = {};
    //presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;

    //presentInfo.waitSemaphoreCount = 1;
    //presentInfo.pWaitSemaphores = signalSemaphores;

    //VkSwapchainKHR swapChains[] = {swapChain};
    //presentInfo.swapchainCount = 1;
    //presentInfo.pSwapchains = swapChains;

    //presentInfo.pImageIndices = &imageIndex;

    //c.vkQueuePresentKHR(presentQueue, &presentInfo);

    //currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
}
