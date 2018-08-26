const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;
const c = @import("vulkan.zig");

const WIDTH = 800;
const HEIGHT = 600;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [][*]const u8{c"VK_LAYER_LUNARG_standard_validation"};
const deviceExtensions = [][*]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

var imageAvailableSemaphores: std.ArrayList(c.VkSemaphore) = undefined;
var renderFinishedSemaphores: std.ArrayList(c.VkSemaphore) = undefined;
var inflightFences: std.ArrayList(c.VkFence) = undefined;
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
        //drawFrame();
    }
    //c.vkDeviceWaitIdle(device);

    std.debug.warn("TODO port the cleanup function");
}

fn initVulkan(allocator: *Allocator, window: *c.GLFWwindow) !void {
    try createInstance(allocator);
    try setupDebugCallback();
    try createSurface(window);
    try pickPhysicalDevice(allocator);
    try createLogicalDevice(allocator);
    try createSwapChain(allocator);
    try createImageViews(allocator);
    // TODO
    //createRenderPass();
    //createGraphicsPipeline();
    //createFramebuffers();
    //createCommandPool();
    //createCommandBuffers();
    //createSyncObjects();
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

fn hash_cstr(a: [*]const u8) u32 {
    return 0; // TODO
}

fn eql_cstr(a: [*]const u8, b: [*]const u8) bool {
    return std.cstr.cmp(a, b) == 0;
}
