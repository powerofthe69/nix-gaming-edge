{
  stdenv,
  lib,
  unzip,
  makeWrapper,
  openjdk25,
  mesa,
  libGL,
  pipewire,
  openssl,
  wget,
  which,
  coreutils,
  zenity,
  xorg,
  udev,
  src,
}:

stdenv.mkDerivation rec {
  pname = "pokemmo";
  version = "latest";

  inherit src;

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];

  buildInputs = [
    openjdk25
    mesa
    libGL
    pipewire
    openssl
    wget
    which
    coreutils
    zenity
    xorg.libX11
    xorg.libXext
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libXrender
    xorg.libXtst
    udev
  ];

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
    rm -f $out/share/pokemmo/PokeMMO.sh

    # Install Icon
    mkdir -p $out/share/icons/hicolor/128x128/apps
    ln -s $out/share/pokemmo/data/icons/128x128.png $out/share/icons/hicolor/128x128/apps/pokemmo.png

    runtime_libs="${
      lib.makeLibraryPath [
        mesa
        libGL
        pipewire
        openssl
        xorg.libX11
        xorg.libXext
        xorg.libXcursor
        xorg.libXrandr
        xorg.libXi
        xorg.libXrender
        xorg.libXtst
        udev
      ]
    }"

    makeWrapper ${stdenv.shell} $out/bin/pokemmo \
      --prefix PATH : ${
        lib.makeBinPath [
          openjdk25
          wget
          which
          coreutils
          zenity
        ]
      } \
      --prefix LD_LIBRARY_PATH : "$runtime_libs" \
      --run "
        STORE_SRC=\"$out/share/pokemmo\"
        USER_DIR=\"\''${XDG_DATA_HOME:-\$HOME/.local/share}/pokemmo\"

        mkdir -p \"\$USER_DIR\"

        echo \"Syncing PokeMMO assets...\"
        cp -rn --no-preserve=mode \"\$STORE_SRC/\"* \"\$USER_DIR/\"

        chmod -R u+w \"\$USER_DIR\"

        if [ ! -f \"\$USER_DIR/PokeMMO.exe\" ]; then
          cp \"\$STORE_SRC/PokeMMO.exe\" \"\$USER_DIR/PokeMMO.exe\"
          chmod u+w \"\$USER_DIR/PokeMMO.exe\"
        fi

        cd \"\$USER_DIR\"
        exec ${openjdk25}/bin/java \\
          -Xmx384M \\
          -Dfile.encoding=\"UTF-8\" \\
          -Djava.library.path=\"\$USER_DIR\" \\
          -cp \"PokeMMO.exe:.\" \\
          com.pokeemu.client.Client
      "

    # Desktop Entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/pokemmo.desktop <<EOF
    [Desktop Entry]
    Name=PokeMMO
    Exec=pokemmo
    Icon=pokemmo
    Type=Application
    Categories=Game;
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "PokeMMO client";
    homepage = "https://pokemmo.com";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
