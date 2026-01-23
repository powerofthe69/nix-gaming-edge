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

  unwrapped = stdenv.mkDerivation {
    inherit pname version;
    src = source.src;
    nativeBuildInputs = [ unzip ];

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

  targetPkgs =
    pkgs:
    with pkgs;
    [
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
      libsecret
      libxcrypt
      mesa
      vulkan-loader
      libGL
      libva
      libdrm
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
        echo "Hytale requires IPv6 (Netty QUIC). Enable in OS or set HYTALE_SKIP_IPV6_CHECK=1" >&2
      fi
    fi

    # Environment Setup
    export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/''$UID/bus}"
    export GDK_BACKEND="''${GDK_BACKEND:-wayland,x11}"

    # Optimization flags
    export AMD_VULKAN_ICD="''${AMD_VULKAN_ICD:-RADV}"
    export RADV_PERFTEST="''${RADV_PERFTEST:-gpl}"
    export __GL_GSYNC_ALLOWED="''${__GL_GSYNC_ALLOWED:-1}"
    export __GL_VRR_ALLOWED="''${__GL_VRR_ALLOWED:-1}"

    exec "$TARGET_BIN" "$@"
  '';

  extraInstallCommands = ''
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${./hytale.png} $out/share/icons/hicolor/256x256/apps/hytale.png

    mkdir -p $out/share/applications
    cat > $out/share/applications/com.hypixel.HytaleLauncher.desktop << EOF
    [Desktop Entry]
    Name=Hytale
    GenericName=Voxel RPG
    Comment=Adventure awaits in Orbis
    Exec=$out/bin/hytale %U
    Icon=$out/share/icons/hicolor/256x256/apps/hytale.png
    Terminal=false
    Type=Application
    Categories=Game;ActionGame;RolePlaying;
    StartupWMClass=HytaleClient
    SingleMainWindow=true
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
