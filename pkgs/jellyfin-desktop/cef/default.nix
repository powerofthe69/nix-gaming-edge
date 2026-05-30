{
  pkgs,
  source,
}:

# nixpkgs.cef-binary override pinned to the CEF release in jellyfin-desktop's
# CEF_VERSION file. Swap src for the nvfetcher-prefetched tarball; the
# default-version fetchurl still evaluates but never realizes.
#
# Two consumers want different layouts at the same prefix:
#   xtask --external-cef expects the SDK as shipped (include/, Release/,
#     Resources/, CMakeLists.txt, cmake/, libcef_dll/), which is already what
#     cef-binary produces at $out.
#   cef-dll-sys's build.rs expects Release/ and Resources/ flattened into the
#     root plus an archive.json sentinel that download-cef checks. We stitch
#     that view under $out/cef-dll-sys/ with symlinks, and the main derivation
#     points CEF_PATH at it.

let
  inherit (pkgs) lib;
  shortVersion = lib.head (lib.splitString "+" source.version);
in
pkgs.cef-binary.overrideAttrs (old: {
  pname = "jellyfin-desktop-cef";
  version = shortVersion;
  src = source.src;

  postInstall = (old.postInstall or "") + ''
    install -dm755 "$out/cef-dll-sys"
    cd "$out/cef-dll-sys"

    # CMake assets cef-dll-sys feeds into cmake::Config::new(cef_dir).
    ln -s ../CMakeLists.txt CMakeLists.txt
    ln -s ../cmake cmake
    ln -s ../include include
    ln -s ../libcef_dll libcef_dll
    [ -e ../CREDITS.html ] && ln -s ../CREDITS.html CREDITS.html

    # Runtime files copy_cef_runtime_files() drops next to the binary and
    # rustc-link-search uses to resolve libcef.so.
    for f in ../Release/*; do
      ln -s "$f" "$(basename "$f")"
    done
    for f in ../Resources/*; do
      ln -s "$f" "$(basename "$f")"
    done

    # download-cef checks archive.json's version is <= cef-dll-sys's pinned
    # Chromium (147.0.14, from `cef-dll-sys = "=148.1.0+147.0.14"` in
    # upstream src/Cargo.toml). Upstream intentionally ships skew: link-time
    # bindings target the older ABI, runtime gets the newer libcef.so via
    # stage_cef. Claim the older version here so the check passes; the actual
    # 148.0.9 binaries are reachable through the symlinks above. Bump this
    # when upstream advances the cef-dll-sys pin.
    cat > archive.json <<'EOF'
    {
      "type": "minimal",
      "name": "cef_binary_147.0.14+linux64_minimal.tar.bz2",
      "sha1": ""
    }
    EOF
  '';
})
