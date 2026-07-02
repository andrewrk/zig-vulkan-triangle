# zig-vulkan-triangle

Minimal example of using [vulkan-zig](https://github.com/Snektron/vulkan-zig)
along with libxcb to open a window and draw a triangle.

![](https://i.imgur.com/pHEHvMU.png)

## Building and Running

```
zig build run
```

## System Configuration

On NixOS, this `nix-shell` works for me:

```nix
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  hardeningDisable = [ "all" ];
  buildInputs = [
    pkgs.vulkan-loader
    pkgs.vulkan-validation-layers
    pkgs.xorg.libxcb
  ];
  VK_LAYER_PATH="${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";
}
```
