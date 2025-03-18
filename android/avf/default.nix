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
    rev = "f3ae17a45df25d1c0913b5cca68fcea6e5a5ce05";
    hash = "sha256-BcfGSMOKc3Ku3GhpFgdOVM6VT3tj0ujbDIxR2MfZAxE=";
  };
  extraPkgs = pkgs.callPackage ./pkgs.nix { inherit base; };

  serialDevice = "ttyS0";

  mkService = name: {
    serviceConfig = {
      ExecStart = "${
        lib.getExe extraPkgs.android_virt.${name}
      } --grpc-port-file /mnt/internal/debian_service_port";
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 1;
      User = "root";
      Group = "root";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "network.target" "mnt-internal.mount" ];
  };

  vmConfig = pkgs.formats.json {};

  cfg = config.avf;
in

with lib;
{
  options = {
    avf.vmConfig = mkOption {
      description = "VM config for AVF";
      default = {};
      type = vmConfig.type;
    };
  };

  config = {
    avf.vmConfig = {
      name = "nixos";
      disks = [
        {
          partitions = [
            {
              label = "nixos";
              path = "$PAYLOAD_DIR/root_part";
              writable = true;
              guid = "{root_part_guid}";
            }
            {
              label = "ESP";
              path = "$PAYLOAD_DIR/efi_part";
              writable = false;
              guid = "{efi_part_guid}";
            }
          ];
          writable = true;
        }
      ];
      sharedPath = [
        {
          sharedPath = "/storage/emulated";
        }
        {
          sharedPath = "$APP_DATA_DIR/files";
        }
      ];
      protected = false;
      cpu_topology = "match_host";
      platform_version = "~1.0";
      memory_mib = 4096;
      debuggable = true;
      console_out = true;
      console_input_device = "ttyS0";
      network = true;
      auto_memory_balloon = true;
      gpu = {
        backend = "2d";
      };
    };

    systemd.services.ttyd = {
      serviceConfig = {
        ExecStart = "${extraPkgs.ttyd}/bin/ttyd --ssl --ssl-cert /etc/ttyd/server.crt --ssl-key /etc/ttyd/server.key --ssl-ca /mnt/internal/ca.crt -t disableLeaveAlert=true -W login -f droid";
        Type = "simple";
        Restart = "always";
        User = "root";
        Group = "root";
      };

      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "network.target" "mnt-internal.mount" ];
    };

    systemd.services.avahi_ttyd = {
      description = "avahi_TTYD";

      after = [ "ttyd.service" "avahi-daemon.socket" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.avahi}/bin/avahi-publish-service ttyd _http._tcp 7681";
        Type = "simple";
        Restart = "always";
        User = "root";
        Group = "root";
      };
    };

    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    system.build.avfImage = pkgs.callPackage ./finish.nix {
      raw_disk_image = import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
        inherit pkgs lib config;

        partitionTableType = "efi";
        copyChannel = true;
      };

      vm_config = vmConfig.generate "vm_config.json" cfg.vmConfig;
    };

    boot.growPartition = true;
    boot.loader.systemd-boot.enable = true;
    boot.initrd.systemd.enable = true;

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

    systemd.services.storage_balloon_agent = mkService "storage_balloon_agent";

    # from Virtualization/guest/forwarder_guest_launcher/debian/service

    systemd.services.forwarder_guest_launcher = mkService "forwarder_guest_launcher";

    # from Virtualization/guest/shutdown_runner/debian/service

    systemd.services.shutdown_runner = mkService "shutdown_runner";

    system.activationScripts.setup_files = {
      text = ''
        if [ ! -e /_setup ]; then
          cp -rv ${./etc}/* /etc/
          mkdir -vp /mnt/{shared,internal}
          chown -v 1000:100 /mnt/{shared,internal}
          touch /_setup
        fi
      '';
    };

    systemd.network.enable = true;
    networking.useNetworkd = true;
    networking.dhcpcd.enable = false;
    services.resolved.dnssec = "false";
    networking.useDHCP = true;
  };
}
