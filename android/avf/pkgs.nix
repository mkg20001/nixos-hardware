{
  base,
  lib,
  stdenv,
  ttyd,
  rustPlatform,
  zlib,
  protobuf_28,
  libwebsockets,
}:
let

  libs = with stdenv.cc; {
    ccLib = cc.lib;
    libc = libc;
    libcDev = libc.dev;
    libcStatic = libc.static;
    libgcc = cc.libgcc;
  };

  # Make clang aware of a few headers
  BINDGEN_EXTRA_CLANG_ARGS = ''-isystem ${libs.libcDev}/include'';

  # libc dynamic libraries
  LD_LIBRARY_PATH = lib.makeLibraryPath [
    libs.ccLib
    libs.libc
    libs.libgcc
    zlib
  ];

  # libc static libraries
  LIBRARY_PATH = lib.makeLibraryPath [ libs.libcStatic ];
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

      inherit BINDGEN_EXTRA_CLANG_ARGS LD_LIBRARY_PATH LIBRARY_PATH;

      src = base;
      setSourceRoot = "sourceRoot=$(echo */guest/forwarder_guest)";

      nativeBuildInputs = [
        protobuf_28
      ];

      cargoLock = {
        lockFile = "${base}/build/guest/forwarder_guest/Cargo.lock";
      };
    };
    forwarder_guest_launcher = rustPlatform.buildRustPackage {
      name = "forwarder_guest_launcher";

      inherit BINDGEN_EXTRA_CLANG_ARGS LD_LIBRARY_PATH LIBRARY_PATH;

      src = base;
      setSourceRoot = "sourceRoot=$(echo */guest/forwarder_guest_launcher)";

      nativeBuildInputs = [
        protobuf_28
      ];

      cargoLock = {
        lockFile = "${base}/guest/forwarder_guest_launcher/Cargo.lock";
      };
    };
    shutdown_runner = rustPlatform.buildRustPackage {
      name = "shutdown_runner";

      inherit BINDGEN_EXTRA_CLANG_ARGS LD_LIBRARY_PATH LIBRARY_PATH;

      src = base;
      setSourceRoot = "sourceRoot=$(echo */guest/shutdown_runner)";

      nativeBuildInputs = [
        protobuf_28
      ];

      cargoLock = {
        lockFile = "${base}/build/guest/shutdown_runner/Cargo.lock";
      };
    };
  };
}
