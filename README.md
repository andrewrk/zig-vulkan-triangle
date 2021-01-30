# zig-vulkan-triangle

Live coding every Thursday at 17:00 EST.
https://www.twitch.tv/andrewrok

![](https://i.imgur.com/pHEHvMU.png)

## Building

```
zig build run
```
___

# Steps for running on macOS

The following steps should allow you to build and run the example on macOS without installing vulkan or glfw to your system, instead referencing the libraries locally. 

### step 1 - Clone and create deps directory
Clone this repository and create a folder to hold the glfw3 and vulkan libraries.
```
git clone https://github.com/andrewrk/zig-vulkan-triangle.git
cd zig-vulkan-triangle
mkdir deps
cd deps
```
### step 2 - Building glfw
Clone the [glfw](https://github.com/glfw/glfw) repository. then build the library using cmake. If you don't have cmake installed there are instructions available on how to install it at [cmake.org](https://cmake.org)   

```
git clone https://github.com/glfw/glfw.git
cd glfw
mkdir build
cd build
cmake -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF -DBUILD_SHARED_LIBS=ON ..
make
```   
Once this completes, the folder src should contain a file named `libglfw.dylib`. the full path from the root directory of `zig-vulkan-triangle` should be `./deps/glfw/build/src/libglfw.dylib`.

### step 3 - Downloading Vulkan.
Return to the deps folder and create a directory for the vulkan library. 
```
mkdir vulkan
```
Then go to the [lunarg](https://vulkan.lunarg.com) website. LunarG provides a `.dmg` file that contains the required vulkan runtime along with MoltenVK, a framework which adapts vulkan commands so that they can be run on macOS via Metal. The file you want should have a name like `vulkansdk-macos-1.2.154.0.dmg` or similar. Copy all the files from the `.dmg` into the `vulkan` directory you created. Once complete there should be an Applications directory with some sample apps, a macOS directory that includes a bin directory with various useful apps (such as those that generate spir-v files), and a MoltenVK directory.
Move into this directory.
```
cd vulkan
```

### step 4 - Setting up the correct paths.
The Vulkan SDK has a shell script that will set up the correct paths for loading the Vulkan loader, the libraries and layer information. You can run it as follows.
```
source setup-env.h
```
Vulkan is now ready to be used. However, before we finish we need to set the `DYLD_LIBRARY_PATH` to also include the path to our glfw library. Change back to the `zig-vulkan-triangle` directory and put the path to `libglfw.dylib` onto the end of the `DYLD_LIBRARY_PATH`.
```
export DYLD_LIBRARY_PATH=$DYLD_LIBRARY_PATH:./deps/glfw/build/src/
```
checking it with `echo $DYLD_LIBRARY_PATH` should result in something like
```
/Users/your/path/to/zig-vulkan-triangle/deps/vulkan/macOS/lib:./deps/glfw/build/src/
```
instead of directly pathing from `./` you could put the full path in. You'll need to do this if you plan to run anything relying on `libglfw.dylib` from any directory other than `zig-vulkan-triangle`.

### step 5 - Build and run
You should now be able to use `zig build run` to run the app. You can use the options `glfw-path` and `vulkan-path` if you need to specify a different path to those libraries. eg
```
zig build run -Dglfw-path="./some/other/path/to/glfw/"
```    
.

