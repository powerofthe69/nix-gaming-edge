{
  pkgs,
  source,
}:

let
  inherit (pkgs) lib;
  shortVersion = lib.head (lib.splitString "+" source.version);
in
pkgs.cef-binary.overrideAttrs (old: {
  pname = "jellium-desktop-cef";
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

    # archive.json marks this dir as a download-cef extraction so cef-dll-sys's
    # build.rs accepts it as CEF_PATH. download-cef's check parses the version
    # as the name's `cef_binary_` .. first `+` span and requires it <= the cef
    # crate pin (`cef = "=150.0.0+150.0.10"` in upstream src/Cargo.lock). Since
    # upstream rev 1272c89 the pin matches this tarball exactly (no more
    # version skew), so we can claim the real archive name. Note: xtask's
    # sdk_proxy now *excludes* this file and synthesizes its own from the crate
    # pin; this copy only matters for direct CEF_PATH use without xtask.
    cat > archive.json <<EOF
    {
      "type": "minimal",
      "name": "cef_binary_${source.version}_linux64_minimal.tar.bz2",
      "sha1": ""
    }
    EOF

    # CEF loads its resource bundle (icudtl.dat, the *.pak files, locales/) from
    # the dir containing libcef.so. The binary's RPATH resolves that to
    # $out/Release, but upstream ships the data only under Resources/ — so
    # CefInitialize aborts in InitializeICU when icudtl.dat is missing. Mirror
    # the data into Release/ to make it a self-contained runtime dir.
    for f in icudtl.dat chrome_100_percent.pak chrome_200_percent.pak resources.pak locales; do
      ln -s "../Resources/$f" "$out/Release/$f"
    done
  '';
})
