{
  stdenv,
  lib,
  unzip,
  makeWrapper,
  openjdk25,
  mesa,
  libGL,
  libpulseaudio,
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
    libpulseaudio
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
        # Attempt to move hidden files too, ignoring error if none exist
        mv "$item"/.[!.]* . 2>/dev/null || true
        rmdir "$item"
      fi
    fi

    runHook postUnpack
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p $out/share/pokemmo $out/bin $out/share/applications
        cp -r * $out/share/pokemmo

        rm $out/share/pokemmo/PokeMMO.sh

        mkdir -p $out/share/icons/hicolor/128x128/apps
        ln -s $out/share/pokemmo/data/icons/128x128.png $out/share/icons/hicolor/128x128/apps/pokemmo.png

        runtime_libs="${lib.makeLibraryPath buildInputs}:${lib.getLib udev}/lib"

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
            STORE_SRC='$out/share/pokemmo'
            USER_DIR='.local/share/pokemmo'

            mkdir -p \"\$USER_DIR\"

            rm -f \"\$USER_DIR/PokeMMO.exe\"

            if [ -f \"\$STORE_SRC/PokeMMO.exe\" ]; then
                cp \"\$STORE_SRC/PokeMMO.exe\" \"\$USER_DIR/PokeMMO.exe\"
                chmod u+w \"\$USER_DIR/PokeMMO.exe\"
            fi

            for file in \"\$STORE_SRC\"/*; do
              name=\$(basename \"\$file\")
              # Skip Exe (copied) and folders we handle manually
              if [[ \"\$name\" == \"PokeMMO.exe\" || \"\$name\" == \"config\" || \"\$name\" == \"roms\" || \"\$name\" == \"log\" || \"\$name\" == \"cache\" || \"\$name\" == \"data\" ]]; then
                continue
              fi
              ln -sfn \"\$file\" \"\$USER_DIR/\$name\"
            done

            mkdir -p \"\$USER_DIR/data\"

            # Link standard data files
            for file in \"\$STORE_SRC/data\"/*; do
              name=\$(basename \"\$file\")
              if [[ \"\$name\" == \"mods\" || \"\$name\" == \"themes\" ]]; then
                continue
              fi
              ln -sfn \"\$file\" \"\$USER_DIR/data/\$name\"
            done

            mkdir -p \"\$USER_DIR/data/themes\"
            if [ -d \"\$STORE_SRC/data/themes\" ]; then
                 for theme in \"\$STORE_SRC/data/themes\"/*; do
                     theme_name=\$(basename \"\$theme\")
                     ln -sfn \"\$theme\" \"\$USER_DIR/data/themes/\$theme_name\"
                 done
            fi

            mkdir -p \"\$USER_DIR/data/mods\"
            if [ -d \"\$STORE_SRC/data/mods\" ]; then
                 for mod in \"\$STORE_SRC/data/mods\"/*; do
                     mod_name=\$(basename \"\$mod\")
                     ln -sfn \"\$mod\" \"\$USER_DIR/data/mods/\$mod_name\"
                 done
            fi

            mkdir -p \"\$USER_DIR/roms\"
            mkdir -p \"\$USER_DIR/log\"
            mkdir -p \"\$USER_DIR/cache\"
            mkdir -p \"\$USER_DIR/config\"

            if [ -d \"\$STORE_SRC/config\" ]; then
                for cfg in \"\$STORE_SRC/config\"/*; do
                    base_cfg=\$(basename \"\$cfg\")
                    target=\"\$USER_DIR/config/\$base_cfg\"
                    if [ ! -f \"\$target\" ]; then
                        cp \"\$cfg\" \"\$target\"
                        chmod u+w \"\$target\"
                    fi
                done
            fi

            cd \"\$USER_DIR\"
            echo \"Launching PokeMMO from \$USER_DIR...\"
            exec ${openjdk25}/bin/java \
              -Xmx384M \
              -Dfile.encoding=\"UTF-8\" \
              -Djava.library.path=\"\$USER_DIR\" \
              -cp \"PokeMMO.exe:.\" \
              com.pokeemu.client.Client
          "

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
