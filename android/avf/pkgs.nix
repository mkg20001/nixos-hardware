{
  base,
  lib,
  ttyd,
  rustPlatform,
  protobuf_28,
  libwebsockets,
}:
let
  RUSTFLAGS = "-C linker=gcc";
in
{
  ttyd =
    (ttyd.override ({
      libwebsockets = libwebsockets.overrideAttrs (_: {
        patches = [
          "${base}/build/debian/ttyd/client_cert.patch"
        ];
      });
    })).overrideAttrs
      (a: {
        patches = [
          "${base}/build/debian/ttyd/xtermjs_a11y.patch"
        ];
      });

  android_virt = lib.recurseIntoAttrs {
    forwarder_guest = rustPlatform.buildRustPackage {
      name = "forwarder_guest";

      inherit RUSTFLAGS;

      src = base;
      setSourceRoot = "sourceRoot=$(echo */guest/forwarder_guest)";

      nativeBuildInputs = [
        protobuf_28
      ];

      postPatch = ''
        ln -s ${./forwarder_guest_Cargo.lock} Cargo.lock
      '';

      cargoLock = {
        lockFile = ./forwarder_guest_Cargo.lock;
      };
    };
    forwarder_guest_launcher = rustPlatform.buildRustPackage {
      name = "forwarder_guest_launcher";

      inherit RUSTFLAGS;

      src = base;
      setSourceRoot = "sourceRoot=$(echo */guest/forwarder_guest_launcher)";

      nativeBuildInputs = [
        protobuf_28
      ];

      postPatch = ''
        ln -s ${./forwarder_guest_launcher_Cargo.lock} Cargo.lock
      '';

      cargoLock = {
        lockFile = ./forwarder_guest_launcher_Cargo.lock;
      };
    };
    shutdown_runner = rustPlatform.buildRustPackage {
      name = "shutdown_runner";

      inherit RUSTFLAGS;

      src = base;
      setSourceRoot = "sourceRoot=$(echo */guest/shutdown_runner)";

      nativeBuildInputs = [
        protobuf_28
      ];

      postPatch = ''
        ln -s ${./shutdown_runner_Cargo.lock} Cargo.lock
      '';

      cargoLock = {
        lockFile = ./shutdown_runner_Cargo.lock;
      };
    };
    storage_balloon_agent = rustPlatform.buildRustPackage {
      name = "storage_balloon_agent";

      inherit RUSTFLAGS;

      src = base;
      setSourceRoot = "sourceRoot=$(echo */guest/storage_balloon_agent)";

      nativeBuildInputs = [
        protobuf_28
      ];

      postPatch = ''
        ln -s ${./storage_balloon_agent_Cargo.lock} Cargo.lock
      '';

      cargoLock = {
        lockFile = ./storage_balloon_agent_Cargo.lock;
      };
    };
  };
}
