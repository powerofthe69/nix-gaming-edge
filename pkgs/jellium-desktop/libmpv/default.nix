{
  pkgs,
  source,
}:

# libmpv fork from andrewrabert/mpv#cef-mpv (a thin CEF-render-API patch set
# on upstream mpv). Override mpv-unwrapped's src and accept the default
# feature set; CEF integration is in the source, not the meson flags.
#
# xtask --external-mpv expects $dir/lib/libmpv.so + $dir/include/mpv/*.h
# under one root, but mpv-unwrapped splits those across $out and $dev. A
# symlink from $out to $dev cycles through mpv.pc's prefix=$out reference,
# so publish a runCommand-stitched merged view at its own store path. The
# path ends up in JFN_EXTRA_RPATH, so it has to be in the store (not /build).

let
  inherit (pkgs) lib;

  libmpv = pkgs.mpv-unwrapped.overrideAttrs (old: {
    pname = "jellium-desktop-libmpv-unmerged";
    inherit (source) version src;

    prePatch = (old.prePatch or "") + ''
      sed -i "s|conf_data\.set_quoted('CONFIGURATION'.*|conf_data.set_quoted('CONFIGURATION', meson.build_options())|" meson.build
    '';

    # mpv self-reports "0.41.0-UNKNOWN" because fetchgit drops .git, so
    # versionCheckHook (greps for `version` in `mpv --version`) fails on
    # our SHA-as-version.
    doInstallCheck = false;
  });
in
pkgs.runCommand "jellium-desktop-libmpv-${source.version}"
  {
    inherit (libmpv) version;
    passthru = { inherit libmpv; };
    meta = libmpv.meta // {
      description = "${libmpv.meta.description or "libmpv"} (jellium-desktop merged view)";
      # mpv-unwrapped's meta says to install [out man]; this merged view only
      # has out. Without this, `nix build .#jellium-desktop.passthru.libmpv`
      # fails with "does not have wanted outputs 'man'".
      outputsToInstall = [ "out" ];
    };
  }
  ''
    mkdir -p $out
    ln -s ${lib.getLib libmpv}/lib     $out/lib
    ln -s ${lib.getDev libmpv}/include $out/include
  ''
