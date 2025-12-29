{
  pkgs,
  lib,
  rustPlatform,
  src,
  version,
  oodleSrc,
  ...
}:

let
  runtimeDeps = with pkgs; [
    libxkbcommon
    libGL
    fontconfig
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    atk
    gtk3
    pango
    glib
    gdk-pixbuf
    cairo
    stdenv.cc.cc.lib
    zstd
  ];

  oodleDir =
    pkgs.runCommand "oodle-dir" { }
      "mkdir $out; ln -s ${oodleSrc} $out/liboo2corelinux64.so";

  patchedSrc = pkgs.runCommand "source-with-local-lock" { } ''
    cp -r ${src} $out
    chmod -R u+w $out
    cp ${./Cargo.lock} $out/Cargo.lock
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "pseudoregalia-rando";
    desktopName = "Pseudoregalia Randomizer";
    exec = "pseudoregalia-rando";
    icon = "sybil";
    categories = [
      "Game"
      "Utility"
    ];
  };

in
rustPlatform.buildRustPackage {
  pname = "pseudoregalia-rando";
  inherit version;
  src = patchedSrc;

  cargoLock = {
    lockFile = ./Cargo.lock;
    allowBuiltinFetchGit = true;
  };

  strictDeps = true;

  ZSTD_SYS_USE_PKG_CONFIG = "1";
  RUSTFLAGS = "-L native=${oodleDir} -l dylib=oo2corelinux64";

  nativeBuildInputs = with pkgs; [
    pkg-config
    makeWrapper
    copyDesktopItems
    patchelf
    wrapGAppsHook3
    imagemagick
  ];

  buildInputs = runtimeDeps;

  desktopItems = [ desktopItem ];

  postInstall = ''
    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${lib.makeLibraryPath runtimeDeps}:$out/lib" \
      $out/bin/pseudoregalia-rando

    mkdir -p $out/share/pseudoregalia-rando
    cp $out/bin/pseudoregalia-rando $out/share/pseudoregalia-rando/pseudoregalia-rando-bin
    cp ${oodleSrc} $out/share/pseudoregalia-rando/liboo2corelinux64.so

    cp -r ${patchedSrc}/src/assets $out/share/pseudoregalia-rando/assets
    chmod -R u+w $out/share/pseudoregalia-rando/assets

    mkdir -p $out/share/icons/hicolor/128x128/apps
    magick $out/share/pseudoregalia-rando/assets/sybil.ico -thumbnail 128x128 $out/share/icons/hicolor/128x128/apps/sybil.png

    mkdir -p $out/lib
    cp ${oodleSrc} $out/lib/liboo2corelinux64.so

    cat > $out/bin/pseudoregalia-rando <<'WRAPPER'
    #!/bin/sh
    set -e
    USER_DIR="$HOME/.local/share/pseudoregalia-rando"
    mkdir -p "$USER_DIR"
    cp -rf --no-preserve=mode,ownership "@out@/share/pseudoregalia-rando/"* "$USER_DIR/"
    chmod +x "$USER_DIR/pseudoregalia-rando-bin"
    chmod +w "$USER_DIR/liboo2corelinux64.so"
    export LD_LIBRARY_PATH="$USER_DIR:${lib.makeLibraryPath runtimeDeps}:$out/lib:$LD_LIBRARY_PATH"
    cd "$USER_DIR"
    exec ./pseudoregalia-rando-bin "$@"
    WRAPPER

    substituteInPlace $out/bin/pseudoregalia-rando --replace "@out@" "$out"
    chmod +x $out/bin/pseudoregalia-rando
  '';

  dontPatchELF = true;
  dontStrip = true;

  meta = with lib; {
    description = "Pseudoregalia Randomizer";
    homepage = "https://github.com/pseudoregalia-modding/rando";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pseudoregalia-rando";
  };
}
