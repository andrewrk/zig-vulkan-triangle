const c = @cImport({
    @cInclude("epoxy/gl.h");
    @cInclude("GLFW/glfw3.h");
});

pub fn main() u8 {
    if (c.glfwInit() == 0) return 1;
    defer c.glfwTerminate();

    const window = c.glfwCreateWindow(640, 480, c"SAW", null, null) orelse return 1;
    c.glfwMakeContextCurrent(window);

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    return 0;
}
