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

        mkdir -p $out/share/pokemmo $out/bin $out/share/applications
        cp -r * $out/share/pokemmo

        rm -f $out/share/pokemmo/PokeMMO.sh

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
            STORE_SRC=\"$out/share/pokemmo\"
            USER_DIR=\"\''${XDG_DATA_HOME:-\$HOME/.local/share}/pokemmo\"

            mkdir -p \"\$USER_DIR\"

            # Remove stale symlinks (but not in config - those are real files)
            find \"\$USER_DIR\" -path \"\$USER_DIR/config\" -prune -o -type l -print | xargs -r rm -f 2>/dev/null || true

            # Copy PokeMMO.exe if it doesn't exist (allows self-updating)
            if [ ! -f \"\$USER_DIR/PokeMMO.exe\" ]; then
              cp \"\$STORE_SRC/PokeMMO.exe\" \"\$USER_DIR/PokeMMO.exe\"
              chmod u+w \"\$USER_DIR/PokeMMO.exe\"
            fi

            # Mirror directory structure: real dirs, symlinked files
            cd \"\$STORE_SRC\"
            find . -type d | while read -r dir; do
              mkdir -p \"\$USER_DIR/\$dir\"
            done
            find . -type f | while read -r file; do
              name=\$(basename \"\$file\")
              # Skip PokeMMO.exe, PokeMMO.sh, and config files (config files are copied, not symlinked)
              if [ \"\$name\" = \"PokeMMO.exe\" ] || [ \"\$name\" = \"PokeMMO.sh\" ]; then
                continue
              fi
              case \"\$file\" in
                ./config/*) continue ;;
              esac
              ln -sfn \"\$STORE_SRC/\$file\" \"\$USER_DIR/\$file\"
            done
            cd - >/dev/null

            # Ensure user-writable directories exist
            mkdir -p \"\$USER_DIR\"/{roms,log,cache,config}

            # Copy default configs if they dont exist yet (these are real files, not symlinks)
            # First, remove any symlinks in config (from old versions)
            find \"\$USER_DIR/config\" -type l -delete 2>/dev/null || true
            if [ -d \"\$STORE_SRC/config\" ]; then
              for cfg in \"\$STORE_SRC/config\"/*; do
                [ -f \"\$cfg\" ] || continue
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
            exec ${openjdk25}/bin/java \\
              -Xmx384M \\
              -Dfile.encoding=\"UTF-8\" \\
              -Djava.library.path=\"\$USER_DIR\" \\
              -cp \"PokeMMO.exe:.\" \\
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
