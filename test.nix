(import <nixpkgs/nixos/lib/eval-config.nix> {
  system = "aarch64-linux";
  modules = [
    (
      { modulesPath, ... }:
      {
        imports = [
          ./android/avf
          ./android/avf/debug.nix
        ];
      }
    )
  ];
}).config.system.build.avfImage
