{
  lib,
  stdenv,
  buildFHSEnv,
  writeShellScript,
  unzip,
  source, # Source from nvfetcher
}:

let
  pname = "hytale-launcher";
  version = source.version;

  # Unwrapped launcher - just extract the binary
  unwrapped = stdenv.mkDerivation {
    inherit pname version;
    src = source.src;
    nativeBuildInputs = [ unzip ];

    # FIX: This tells Nix the zip file is flat (no top-level directory)
    # This replaces the need for the manual `unpackPhase` you had before.
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 hytale-launcher $out/bin/hytale-launcher
      runHook postInstall
    '';
  };

in
buildFHSEnv {
  name = "hytale";

  # Combine the package lists properly using `++`
  targetPkgs =
    pkgs:
    with pkgs;
    [
      # UI Stack
      gtk3
      glib
      webkitgtk_4_1
      libsoup_3
      openssl
      gsettings-desktop-schemas
      glib-networking
      dbus
      pango
      cairo
      gdk-pixbuf
      atk
      at-spi2-atk
      at-spi2-core

      # Desktop & Utils
      hicolor-icon-theme
      xdg-utils
      cups
      icu
      zlib
      libpng
      freetype
      fontconfig
      harfbuzz
      nspr
      nss
      expat
      alsa-lib
      libxcrypt

      # Graphics
      mesa
      vulkan-loader
      libGL
      libva
      libdrm

      # Wayland
      wayland
      libxkbcommon
    ]
    ++ (with pkgs.xorg; [
      # X11 Libraries
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
      libxcb
      libXcursor
      libXi
      libXrender
      libXtst
      libXScrnSaver
      libXinerama
      libxshmfence
    ]);

  runScript = writeShellScript "hytale-run" ''
    set -euo pipefail

    # Path configuration
    DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale"
    LAUNCHER_DIR="$DATA_DIR/launcher"

    # Kept original binary name as requested
    TARGET_BIN="$LAUNCHER_DIR/hytale-launcher"
    SOURCE_BIN="${unwrapped}/bin/hytale-launcher"

    mkdir -p "$LAUNCHER_DIR"

    # Copy on launch to ensure updates propagate
    echo "Updating Launcher..."
    cp -f "$SOURCE_BIN" "$TARGET_BIN"
    chmod +x "$TARGET_BIN"

    # IPv6 Check
    if [[ -z "''${HYTALE_SKIP_IPV6_CHECK:-}" ]]; then
      if [[ ! -d /proc/sys/net/ipv6 ]]; then
        echo "⚠️  Hytale requires IPv6 (Netty QUIC). Enable in OS or set HYTALE_SKIP_IPV6_CHECK=1" >&2
      fi
    fi

    # Environment Setup
    export GDK_BACKEND="''${GDK_BACKEND:-wayland,x11}"

    # Optimization flags
    export AMD_VULKAN_ICD="''${AMD_VULKAN_ICD:-RADV}"
    export RADV_PERFTEST="''${RADV_PERFTEST:-gpl}"
    export __GL_GSYNC_ALLOWED="''${__GL_GSYNC_ALLOWED:-1}"
    export __GL_VRR_ALLOWED="''${__GL_VRR_ALLOWED:-1}"

    exec "$TARGET_BIN" "$@"
  '';

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/hytale.desktop << EOF
    [Desktop Entry]
    Name=Hytale
    GenericName=Voxel RPG
    Comment=Adventure awaits in Orbis
    Exec=$out/bin/hytale %U
    Icon=hytale
    Terminal=false
    Type=Application
    Categories=Game;ActionGame;RolePlaying;
    StartupWMClass=hytale
    StartupNotify=true
    PrefersNonDefaultGPU=true
    EOF
  '';

  meta = with lib; {
    description = "Official Hytale game launcher";
    homepage = "https://hytale.com";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hytale";
  };
}
