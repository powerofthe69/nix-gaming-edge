{
  pkgs,
  source,
}:

# Jellyfin Desktop v3 (CEF + mpv rewrite of the archived Qt client).
# xtask drives the build and stages CEF + libmpv next to the binary.
# --external-cef / --external-mpv let us hand it pre-built dirs so nothing
# fetches at build time. JFN_EXTRA_RPATH is read by build.rs and baked into
# the binary's RPATH.
#
# CEF tarball and libmpv-fork sources live in ./nvfetcher.toml -> ./_dependencies/
# (eden-emulator layout). Regenerate with:
#   nvfetcher -c pkgs/jellyfin-desktop/nvfetcher.toml -o pkgs/jellyfin-desktop/_dependencies

let
  inherit (pkgs) lib;

  deps = pkgs.callPackage ./_dependencies/generated.nix { };

  cef = pkgs.callPackage ./cef {
    source = deps.jellyfin-desktop-cef;
  };

  libmpv = pkgs.callPackage ./libmpv {
    source = deps.jellyfin-desktop-libmpv;
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
  pname = "jellyfin-desktop";
  inherit (source) version src;

  # Workspace lives in src/, not the repo root.
  cargoRoot = "src";

  # Bumped by .github/workflows/update.yml when the vendor FOD's hash drifts.
  cargoHash = "sha256-QdwdJRXkoRC7iCwMT64Hw/1yYic5OH7gq4cHifzlcN8=";

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
    # xtask shells out to git for these; the sandbox has no .git, so seed
    # from the nvfetcher rev for traceability.
    JFN_GIT_HASH = source.version;
    JFN_GIT_DIRTY = "0";
    # Linux-only. build.rs reads JFN_EXTRA_RPATH and bakes each entry into
    # the binary's RPATH via rustc -C link-arg.
    JFN_EXTRA_RPATH = "${cef}/Release:${libmpv}/lib";
    # cef-dll-sys downloads CEF if CEF_PATH is unset. Point at the merged-
    # layout subdir of our CEF derivation.
    CEF_PATH = "${cef}/cef-dll-sys";
  };

  # Drive the build through xtask so it stages CEF/mpv next to the binary.
  # The repo's .cargo/config `cargo xtask` alias doesn't resolve under
  # rustPlatform's CARGO_HOME, so expand it inline.
  buildPhase = ''
    runHook preBuild

    cargo run --quiet --release \
      --manifest-path src/xtask/Cargo.toml -- \
      build \
        --external-cef ${cef} \
        --external-mpv ${libmpv} \
        --out build

    runHook postBuild
  '';

  doCheck = false;

  # Build cef or libmpv standalone with `nix build .#jellyfin-desktop.passthru.{cef,libmpv}`.
  passthru = {
    inherit cef libmpv;
  };

  installPhase = ''
    runHook preInstall

    # Intermediate build artifacts; also the second binary copy with the
    # /build/-tainted RPATH.
    rm -rf build/cargo-target

    install -dm755 $out/libexec/jellyfin-desktop
    cp -r build/. $out/libexec/jellyfin-desktop/

    # Strip cargo's auto-added $CARGO_TARGET_DIR/release/deps from RPATH.
    # The JFN_EXTRA_RPATH entries (CEF, libmpv) survive shrink because their
    # .so files are actually needed.
    patchelf --shrink-rpath $out/libexec/jellyfin-desktop/jellyfin-desktop

    install -dm755 $out/bin
    makeWrapper $out/libexec/jellyfin-desktop/jellyfin-desktop $out/bin/jellyfin-desktop \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"

    install -Dm644 resources/linux/org.jellyfin.JellyfinDesktop.desktop \
      $out/share/applications/org.jellyfin.JellyfinDesktop.desktop
    install -Dm644 resources/linux/org.jellyfin.JellyfinDesktop.svg \
      $out/share/icons/hicolor/scalable/apps/org.jellyfin.JellyfinDesktop.svg
    install -Dm644 LICENSE $out/share/licenses/jellyfin-desktop/LICENSE

    runHook postInstall
  '';

  meta = with lib; {
    description = "Jellyfin desktop client";
    homepage = "https://github.com/jellyfin/jellyfin-desktop";
    license = licenses.gpl2Only;
    mainProgram = "jellyfin-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode # CEF
    ];
  };
}
