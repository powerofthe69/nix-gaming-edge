{
  pkgs,
  mesa-src,
  libdrm-src,
  wayland-protocols-src,
}:

let
  lib = pkgs.lib;

  # Get short commit hash for versioning
  mesaVersion = builtins.substring 0 7 (mesa-src.rev or "unknown");
  libdrmVersion = builtins.substring 0 7 (libdrm-src.rev or "unknown");
  waylandProtocolsVersion = builtins.substring 0 7 (wayland-protocols-src.rev or "unknown");

  # Build libdrm-git AND libdrm32-git
  # Use clang for allegedly faster compilation and tighter integration with LLVM
  gitLibdrm =
    {
      is32bit ? false,
    }:
    let
      basePkgs = if is32bit then pkgs.pkgsi686Linux else pkgs;
    in
    (basePkgs.libdrm.override { stdenv = basePkgs.clangStdenv; }).overrideAttrs (old: {
      pname = "libdrm-git";
      version = "${libdrmVersion}";
      src = libdrm-src;
    });

  libdrm-git = gitLibdrm { is32bit = false; };
  libdrm32-git = gitLibdrm { is32bit = true; };

  # Build wayland-protocols-git
  # Mostly XML but use clang for uniformity
  wayland-protocols-git =
    (pkgs.wayland-protocols.override { stdenv = pkgs.clangStdenv; }).overrideAttrs
      (old: {
        pname = "wayland-protocols-git";
        version = "${waylandProtocolsVersion}";
        src = wayland-protocols-src;
      });

  makeMesa =
    {
      is32bit ? false,
    }:
    let
      basePkgs = if is32bit then pkgs.pkgsi686Linux else pkgs;
      gitLibdrm = if is32bit then libdrm32-git else libdrm-git;
    in
    # Use clang for allegedly faster compilation and tighter integration with LLVM
    (basePkgs.mesa.override { stdenv = basePkgs.clangStdenv; }).overrideAttrs (old: {
      pname = "mesa-git";
      version = "${mesaVersion}";
      src = mesa-src;

      # Remove spirv2dxil output since we're not building DirectX stuff
      outputs = lib.remove "spirv2dxil" (old.outputs or [ "out" ]);

      buildInputs =
        (lib.filter (
          x:
          let
            name = x.name or x.pname or "";
          in
          name != "libdrm" && name != "mesa-libgbm"
        ) old.buildInputs)
        ++ [
          pkgs.libdisplay-info
          gitLibdrm
        ];

      nativeBuildInputs =
        (
          if is32bit then
            (lib.filter (
              x:
              let
                name = x.name or x.pname or "";
              in
              name != "mesa"
            ) old.nativeBuildInputs)
            ++ [ mesa-git ]
          else
            old.nativeBuildInputs
        )
        ++ [
          wayland-protocols-git
        ];

      # Remove spirv2dxil from postInstall too
      postInstall =
        builtins.replaceStrings
          [ "moveToOutput bin/spirv2dxil $spirv2dxil" "moveToOutput \"lib/libspirv_to_dxil*\" $spirv2dxil" ]
          [ "" "" ]
          (old.postInstall or "");

      mesonFlags =
        # Filter out flags we want to override from the original
        (builtins.filter (
          flag:
          !(lib.hasPrefix "-Dgallium-drivers=" flag)
          && !(lib.hasPrefix "-Dvulkan-drivers=" flag)
          && !(lib.hasPrefix "-Dvulkan-layers=" flag)
          && !(lib.hasPrefix "-Dgallium-rusticl=" flag)
          && !(lib.hasPrefix "-Dteflon=" flag)
        ) (old.mesonFlags or [ ]))
        ++ [
          "-Dplatforms=x11,wayland"
          "-Dgallium-drivers=${if is32bit then "radeonsi,zink,llvmpipe,iris" else "all"}"
          "-Dvulkan-drivers=amd,intel,nouveau${if is32bit then "" else ",swrast"}"
          "-Dvulkan-layers=anti-lag,device-select,overlay"
          "-Dteflon=true"
          "-Dgallium-extra-hud=true"
          "-Dvideo-codecs=all"
          "-Dinstall-mesa-clc=true"
          "-Dinstall-precomp-compiler=true"
          "-Dgallium-mediafoundation=disabled"
          "-Dandroid-libbacktrace=disabled"
          "-Dmicrosoft-clc=disabled"
          "-Dlibgbm-external=false"
          "-Dspirv-to-dxil=false"
        ]
        ++ (
          if is32bit then
            [
              "-Dgallium-rusticl=false"
            ]
          else
            [
              "-Dgallium-rusticl=true"
              "-Dgallium-rusticl-enable-drivers=auto"
              "-Dintel-rt=enabled"
            ]
        );

      # Remove patches that don't apply to git
      patches = builtins.filter (
        p:
        let
          name = baseNameOf (toString p);
        in
        !(lib.hasPrefix "gallivm-llvm-21" name)
      ) (old.patches or [ ]);

      # Inject git version to driver name
      postPatch = (old.postPatch or "") + ''
        BASE_VERSION=$(cat VERSION | tr -d '\n')
        NEW_VERSION="$BASE_VERSION (git-${mesaVersion})"
        echo "$NEW_VERSION" > VERSION
      '';
    });

  mesa-git = makeMesa { is32bit = false; };
  mesa32-git = makeMesa { is32bit = true; };

in
{
  inherit
    mesa-git
    mesa32-git
    libdrm-git
    libdrm32-git
    wayland-protocols-git
    mesaVersion
    ;
}
