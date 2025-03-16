{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  base = pkgs.fetchgit {
    url = "https://android.googlesource.com/platform/packages/modules/Virtualization/";
    rev = "e74bf8329a1e8fcac201bb93f7d6437a35ae9794";
    sha256 = "1r418g908hkfx4yw08kirwf3mpzbggf2yyqyk3zi8prgl4zw0ihh";
  };
  extraPkgs = pkgs.callPackage ./pkgs.nix { inherit base; };
in

with lib;
{
  services.ttyd = {
    enable = true;
    certFile = "/etc/ttyd/server.crt";
    keyFile = "/etc/ttyd/server.key";
    caFile = "/mnt/internal/ca.crt";
    writeable = true;
    #   disableLeaveAlert = true;
    #   -W login
    #   -f droid
    # package = extraPkgs.ttyd;
  };

  system.build.qemuImage = import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
    inherit pkgs lib config;

    partitionTableType = "efi";
    format = "qcow2-compressed";
    copyChannel = true;
  };

  boot.growPartition = true;
  boot.loader.systemd-boot.enable = true;

  # image building needs to know what device to install bootloader on
  boot.loader.grub.device = "/dev/vda";

  # avf patches only available for 6.1 right now
  boot.kernelPackages = pkgs.linuxPackages_6_1;

  boot.kernelPatches = [
    {
      name = "avf";
      patch = "${base}/build/debian/kernel/patches/avf/arm64-balloon.patch";
      extraStructuredConfig = with lib.kernel; {
        # DRM = module;
        SND_VIRTIO = module;
        SND = yes;
        SOUND = yes;
      };
    }
  ];

  systemd.services.ttyd = {
    #    after = [ "virtiofs_internal.service" ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };

    "/mnt/internal" = {
      device = "internal";
      fsType = "virtiofs";
    };
    "/mnt/shared" = {
      device = "android";
      fsType = "virtiofs";
    };
  };

  # from Virtualization/guest/forwarder_guest_launcher/debian/service

  systemd.services.forwarder_guest_launcher = {
    path = [ extraPkgs.android_virt.forwarder_guest_launcher ];
    script = ''
      forwarder_guest_launcher --grpc-port-file /mnt/internal/debian_service_port
    '';
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 1;
      User = "root";
      Group = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "multi-user.target" ];
  };

  # from Virtualization/guest/shutdown_runner/debian/service

  systemd.services.shutdown_runner = {
    path = [ extraPkgs.android_virt.shutdown_runner ];
    script = ''
      shutdown_runner --grpc-port-file /mnt/internal/debian_service_port
    '';
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 1;
      User = "root";
      Group = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
