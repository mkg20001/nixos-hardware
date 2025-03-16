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
    rev = "b1dbca3f1dba69e953eeb81eec0485c387670b55";
    hash = "sha256-g3XNwmufAZQNh8DNDu1sQZM1gdxXL8oJfGnzQ+3DYoo=";
  };
  extraPkgs = pkgs.callPackage ./pkgs.nix { inherit base; };

  serialDevice = if pkgs.stdenv.hostPlatform.isx86 then "ttyS0" else "ttyAMA0";
in

with lib;
{
  /* services.ttyd = {
    enable = true;
    enableSSL = true;
    certFile = "/etc/ttyd/server.crt";
    keyFile = "/etc/ttyd/server.key";
    caFile = "/mnt/internal/ca.crt";
    writeable = true;
    #   disableLeaveAlert = true;
    #   -W login
    #   -f droid
    # package = extraPkgs.ttyd;
  }; */

  systemd.services.ttyd = {
    serviceConfig = {
      ExecStart = "${extraPkgs.ttyd}/bin/ttyd --ssl --ssl-cert /etc/ttyd/server.crt --ssl-key /etc/ttyd/server.key --ssl-ca /mnt/internal/ca.crt -t disableLeaveAlert=true -W login -f droid";
      Type = "simple";
      Restart = "always";
      User = "root";
      Group = "root";
    };

    wantedBy = [ "multi-user.target" ];
  };

  system.build.avfImage = pkgs.vmTools.runInLinuxVM (
    pkgs.callPackage ./finish.nix {
      raw_disk_image = import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
        inherit pkgs lib config;

        partitionTableType = "efi";
        copyChannel = true;
      };
    }
  );

  boot.growPartition = true;
  boot.loader.systemd-boot.enable = true;

  # image building needs to know what device to install bootloader on
  boot.loader.grub.device = "/dev/vda";
  # Faster boot. User can't access bootloader currently anyways (?)
  boot.loader.timeout = 0;

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

  boot.kernelParams = [
    "console=tty1"
    "console=${serialDevice}"
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

  # from Virtualization/guest/storage_balloon_agent/debian/service

  systemd.services.storage_balloon_agent = {
    path = [ extraPkgs.android_virt.storage_balloon_agent ];
    script = ''
      storage_balloon_agent --grpc-port-file /mnt/internal/debian_service_port
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
