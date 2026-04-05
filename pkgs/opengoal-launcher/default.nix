{
  buildFHSEnv,
  lib,
  source,
  stdenv,
  writeShellScript,
}:

let
  unwrapped = stdenv.mkDerivation {
    pname = "opengoal-launcher-unwrapped";
    version = source.version;
    src = source.src;
    dontUnpack = true;
    dontStrip = true;
    dontPatchELF = true;
    installPhase = ''
      install -Dm755 $src $out/bin/opengoal-launcher
    '';
  };
in
buildFHSEnv {
  name = "opengoal-launcher";

  targetPkgs =
    pkgs: with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      glib-networking
      gsettings-desktop-schemas
      gtk3
      harfbuzz
      hicolor-icon-theme
      libdrm
      libGL
      libpulseaudio
      libX11
      libxcb
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXinerama
      libxkbcommon
      libXrandr
      libXrender
      libXScrnSaver
      libxshmfence
      libXtst
      mesa
      nasm
      nspr
      nss
      openssl
      pango
      vulkan-loader
      wayland
      webkitgtk_4_1
      xdg-utils
      zlib
    ];

  # Run the fully portable AppImage directly
  runScript = writeShellScript "opengoal-launcher-run" ''
    set -euo pipefail
    exec ${unwrapped}/bin/opengoal-launcher "$@"
  '';

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/opengoal-launcher.desktop << EOF
    [Desktop Entry]
    Name=OpenGOAL
    Comment=Launcher for OpenGOAL
    Exec=$out/bin/opengoal-launcher %U
    Terminal=false
    Type=Application
    Categories=Game;
    StartupWMClass=OpenGOAL-Launcher
    StartupNotify=true
    PrefersNonDefaultGPU=true
    EOF
  '';

  meta = {
    description = "GUI launcher for OpenGOAL";
    homepage = "https://opengoal.dev";
    license = lib.licenses.isc;
    platforms = [ "x86_64-linux" ];
    mainProgram = "opengoal-launcher";
  };
}
