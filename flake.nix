{
  description = "Openote 1.0.2 — prebuilt Linux x64 release";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      version = "1.0.2";

      src = pkgs.fetchurl {
        url = "https://github.com/icmric/openote/releases/download/v${version}/openote-${version}-linux-x64.tar.gz";
        hash = "sha256-sbCNdZ9S7rron1aVOQwwfsyPDAh08dYnyKZLCVLycIg=";
      };

      # The release bundle is built on debian:12 and dynamically links the
      # usual GTK/mpv stack. autoPatchelfHook rewrites the interpreter and
      # RPATHs of every ELF in $out so it resolves against nixpkgs libs.
      openote = pkgs.runCommand "openote-${version}" {
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        # We run autoPatchelf manually below (after registering $out/lib as a
        # search path), so skip the automatic postFixup pass.
        dontAutoPatchelf = true;
        # auto-patchelf ignores the libc-family sonames, so without this the
        # nix libs' GLIBC_2.4x requirements get resolved against the host's
        # older /lib libc. Pin the nix glibc into every RUNPATH.
        appendRunpaths = [ "${pkgs.glibc}/lib" ];
        buildInputs = [
          pkgs.stdenv.cc.cc.lib
          pkgs.zlib
          pkgs.libepoxy
          pkgs.fontconfig
          pkgs.gtk3
          pkgs.gdk-pixbuf
          pkgs.glib
          pkgs.pango
          pkgs.cairo
          pkgs.atk
          pkgs.harfbuzz
          pkgs.mpv
        ];
      } ''
        mkdir -p "$out"
        tar -xzf "${src}" -C "$out" --strip-components=1
        # The Flutter engine/plugins link each other by bare soname; they all
        # live in $out/lib, so make that dir visible to the patcher.
        addAutoPatchelfSearchPath "$out/lib"
        autoPatchelf "$out"
      '';
    in
    {
      packages.${system} = {
        default = openote;
        openote = openote;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${openote}/openote";
        };
        openote = {
          type = "app";
          program = "${openote}/openote";
        };
      };
    };
}
