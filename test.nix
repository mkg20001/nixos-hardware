(import <nixpkgs/nixos/lib/eval-config.nix> {
  system = "x86_64-linux";
  modules = [
    (
      { modulesPath, ... }:
      {
        imports = [
          ./android/avf
        ];
      }
    )
  ];
}).config.system.build.avfImage
