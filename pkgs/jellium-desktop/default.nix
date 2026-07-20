{
  pkgs,
  source,
}:

# Jellium Desktop (CEF + mpv rewrite of the archived Qt client; formerly
# jellyfin/jellyfin-desktop v3, renamed and moved to andrewrabert's account).
# xtask drives the build and stages CEF + libmpv next to the binary.
# --external-cef / --external-mpv let us hand it pre-built dirs so nothing
# fetches at build time. JFN_EXTRA_RPATH is read by build.rs and baked into
# the binary's RPATH.
#
# CEF tarball and libmpv-fork sources live in ./nvfetcher.toml -> ./_dependencies/
# (per-package vendored-deps layout). Regenerate with:
#   nvfetcher -c pkgs/jellium-desktop/nvfetcher.toml -o pkgs/jellium-desktop/_dependencies

let
  inherit (pkgs) lib;

  deps = pkgs.callPackage ./_dependencies/generated.nix { };

  cef = pkgs.callPackage ./cef {
    source = deps.jellium-desktop-cef;
  };

  libmpv = pkgs.callPackage ./libmpv {
    source = deps.jellium-desktop-libmpv;
  };

  runtimeLibs = with pkgs; [
    libglvnd
    libxkbcommon
    wayland
    systemdLibs
    libxcb
    libxcb-cursor
  ];

  # jfn-mpv's build.rs links libav* directly (not just transitively through
  # libmpv) and probes via pkg-config. headless variant avoids X/SDL closure.
  buildOnlyLibs = with pkgs; [
    ffmpeg-headless
  ];
in
pkgs.rustPlatform.buildRustPackage {
  pname = "jellium-desktop";
  inherit (source) version src;

  # Workspace lives in src/, not the repo root.
  cargoRoot = "src";

  # Bumped by .github/workflows/update.yml when the vendor FOD's hash drifts.
  cargoHash = "sha256-2OqlZgNk5esutDjUGaXrDaaL9oywuGvW9Bj+gDItjt8=";

  nativeBuildInputs = with pkgs; [
    makeWrapper
    pkg-config
    copyDesktopItems
    # jfn-mpv and cef-dll-sys use bindgen
    rustPlatform.bindgenHook
    # cef-dll-sys's build.rs constructs a cmake::Config (Linux skips .build(),
    # but Config::new still runs at eval).
    cmake
    ninja
  ];

  buildInputs = runtimeLibs ++ buildOnlyLibs;

  env = {
    # xtask reads gix on the repo and overwrites JFN_GIT_HASH/JFN_GIT_DIRTY in
    # the cargo subprocess; the sandbox has no .git so xtask will set these to
    # empty. Setting them here lets jfn_rust's build.rs find them via gix
    # fallback when xtask leaves them empty. They get clobbered by xtask in
    # the actual rustc env, but we keep them as a documented seed in case the
    # override is dropped in a future xtask version.
    JFN_GIT_HASH = source.version;
    JFN_GIT_DIRTY = "0";
  };

  # Drive the build through xtask so it stages CEF/mpv next to the binary.
  # The repo's .cargo/config `cargo xtask` alias doesn't resolve under
  # rustPlatform's CARGO_HOME, so expand it inline.
  #
  # --cef-path (NOT --external-cef): `--external-cef <dir>` treats <dir> as
  # download-cef's cache root, expects <dir>/<ver>/<os-arch>/ layout, and
  # downloads from spotifycdn if missing. `--cef-path <dir>` uses the SDK in
  # place — just needs <dir>/libcef.so to be resolvable. Our cef derivation
  # exposes the flattened SDK-plus-runtime layout under $out/cef-dll-sys/;
  # xtask's sdk_proxy then symlinks that into a tempdir for cef-dll-sys's
  # build.rs (which reads CEF_PATH, which xtask sets to the proxy).
  buildPhase = ''
    runHook preBuild

    cargo run --quiet --release \
      --manifest-path src/xtask/Cargo.toml -- \
      build \
        --cef-path ${cef}/cef-dll-sys \
        --external-mpv ${libmpv} \
        --out build

    runHook postBuild
  '';

  doCheck = false;

  # Build cef or libmpv standalone with `nix build .#jellium-desktop.passthru.{cef,libmpv}`.
  passthru = {
    inherit cef libmpv;
  };

  installPhase = ''
    runHook preInstall

    # Intermediate build artifacts; also the second binary copy with the
    # /build/-tainted RPATH.
    rm -rf build/cargo-target

    install -dm755 $out/libexec/jellium-desktop
    cp -r build/. $out/libexec/jellium-desktop/

    # Strip cargo's auto-added $CARGO_TARGET_DIR/release/deps from RPATH.
    # The JFN_EXTRA_RPATH entries (CEF, libmpv) survive shrink because their
    # .so files are actually needed.
    patchelf --shrink-rpath $out/libexec/jellium-desktop/jellium-desktop

    install -dm755 $out/bin
    makeWrapper $out/libexec/jellium-desktop/jellium-desktop $out/bin/jellium-desktop \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"

    install -Dm644 resources/linux/net.nullsum.JelliumDesktop.desktop \
      $out/share/applications/net.nullsum.JelliumDesktop.desktop
    install -Dm644 resources/linux/net.nullsum.JelliumDesktop.svg \
      $out/share/icons/hicolor/scalable/apps/net.nullsum.JelliumDesktop.svg
    install -Dm644 resources/linux/net.nullsum.JelliumDesktop.metainfo.xml \
      $out/share/metainfo/net.nullsum.JelliumDesktop.metainfo.xml
    install -Dm644 LICENSE $out/share/licenses/jellium-desktop/LICENSE

    runHook postInstall
  '';

  meta = with lib; {
    description = "Unofficial Jellyfin desktop client built on CEF and mpv";
    homepage = "https://github.com/andrewrabert/jellium-desktop";
    license = licenses.gpl2Only;
    mainProgram = "jellium-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode # CEF
    ];
  };
}
