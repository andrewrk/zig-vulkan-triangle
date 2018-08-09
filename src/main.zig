const std = @import("std");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "");
    @cInclude("GLFW/glfw3.h");
});

const WIDTH = 800;
const HEIGHT = 600;

pub fn main() u8 {
    if (c.glfwInit() == 0) return 1;
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);

    const window = c.glfwCreateWindow(WIDTH, HEIGHT, c"SAW", null, null) orelse return 1;
    defer c.glfwDestroyWindow(window);

    initVulkan();

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();
        //drawFrame();
    }
    //c.vkDeviceWaitIdle(device);

    std.debug.warn("TODO port the cleanup function");

    return 0;
}

var imageAvailableSemaphores: std.ArrayList(c.VkSemaphore) = undefined;
var renderFinishedSemaphores: std.ArrayList(c.VkSemaphore) = undefined;
var inflightFences: std.ArrayList(c.VkFence) = undefined;
var currentFrame: usize = 0;

fn initVulkan() void {}

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
