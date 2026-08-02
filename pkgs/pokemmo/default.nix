{
  alsa-lib,
  buildFHSEnv,
  coreutils,
  gtk3,
  gtk4,
  lib,
  libGL,
  libpulseaudio,
  libX11,
  libXcursor,
  libXext,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  mesa,
  openjdk25,
  openssl,
  pipewire,
  src,
  stdenv,
  udev,
  unzip,
  wget,
  which,
  writeShellScript,
  zenity,
  zlib,
}:

let
  pokemmo-unwrapped = stdenv.mkDerivation {
    pname = "pokemmo-unwrapped";
    version = "latest";

    inherit src;

    nativeBuildInputs = [ unzip ];

    unpackPhase = ''
      runHook preUnpack

      unzip -q "$src"

      if [ "$(ls -A | wc -l)" -eq 1 ]; then
        item=$(ls -A)
        if [ -d "$item" ]; then
          echo "Removing nesting from directory: $item"
          mv "$item"/* .
          mv "$item"/.[!.]* . 2>/dev/null || true
          rmdir "$item"
        fi
      fi

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/pokemmo
      cp -r * $out/share/pokemmo
      rm -f $out/share/pokemmo/PokeMMO.sh $out/share/pokemmo/env-vars

      # Install Icon
      mkdir -p $out/share/icons/hicolor/128x128/apps
      ln -s $out/share/pokemmo/data/icons/128x128.png $out/share/icons/hicolor/128x128/apps/pokemmo.png

      runHook postInstall
    '';
  };

  launcher = writeShellScript "pokemmo-launcher" ''
    STORE_SRC="${pokemmo-unwrapped}/share/pokemmo"
    USER_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/pokemmo"

    mkdir -p "$USER_DIR"

    echo "Syncing PokeMMO assets..."
    cp -rn --no-preserve=mode "$STORE_SRC/"* "$USER_DIR/"

    chmod -R u+w "$USER_DIR"

    cd "$USER_DIR"

    NATIVE="bin/linux/${if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"}/PokeMMO"
    if [ -f "$NATIVE" ]; then
      chmod u+x "$NATIVE"
      exec "$NATIVE"
    fi

    exec java \
      -Xmx384M \
      -Dfile.encoding="UTF-8" \
      -Djava.library.path="$USER_DIR" \
      -cp "PokeMMO.exe:." \
      com.pokeemu.client.Client
  '';
in
# The client self-updates: it downloads a PokeMMO-Updater ELF and execs it,
# and the updater re-execs the client afterwards. Both expect
# /lib64/ld-linux-x86-64.so.2 to exist, so the whole process tree has to run
# inside an FHS namespace — exec'ing the store ld-linux by hand only fixes
# the first binary, not anything the game spawns on its own.
buildFHSEnv {
  pname = "pokemmo";
  version = "latest";

  targetPkgs = _: [
    alsa-lib
    coreutils
    # PokeMMO-Updater is an SWT app: dlopens libswt-pi3 (gtk3) with a
    # libswt-pi4 (gtk4) fallback
    gtk3
    gtk4
    libGL
    libpulseaudio
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
    libXrender
    libXtst
    mesa
    openjdk25
    openssl
    pipewire
    stdenv.cc.cc.lib
    udev
    wget
    which
    zenity
    zlib
  ];

  runScript = launcher;

  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons
    ln -s ${pokemmo-unwrapped}/share/icons/hicolor $out/share/icons/hicolor

    cat > $out/share/applications/pokemmo.desktop <<EOF
    [Desktop Entry]
    Name=PokeMMO
    Exec=pokemmo
    Icon=pokemmo
    Type=Application
    Categories=Game;
    EOF
  '';

  passthru.unwrapped = pokemmo-unwrapped;

  meta = with lib; {
    description = "PokeMMO client";
    homepage = "https://pokemmo.com";
    license = licenses.unfree;
    mainProgram = "pokemmo";
    platforms = platforms.linux;
  };
}
