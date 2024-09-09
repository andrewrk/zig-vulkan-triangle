# zig-vulkan-triangle

Example of using [vulkan-zig](https://github.com/Snektron/vulkan-zig) and
[shader_compiler](https://github.com/Games-by-Mason/shader_compiler) along with
libxcb to open a window and draw a triangle.

![](https://i.imgur.com/pHEHvMU.png)

## Building and Running

```
zig build run
```

## System Configuration

On NixOS, I had to add these to my shell:

```
buildInputs = [
    vulkan-loader
    vulkan-validation-layers
    xorg.libxcb
];

VK_LAYER_PATH="${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";
```
