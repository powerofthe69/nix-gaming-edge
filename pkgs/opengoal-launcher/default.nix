{
  buildFHSEnv,
  fetchurl,
  lib,
  source,
  stdenv,
  writeShellScript,
}:

let
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/open-goal/launcher/main/resources/icons/256.png";
    hash = "sha256-mtC930LQdtC4thaHTB23r+ORVW8i9XWE8BK9a28HmSI=";
  };

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
      gtk3
      libdrm
      libGL
      libpulseaudio
      libX11
      libXcursor
      libXext
      libXfixes
      libXi
      libXrandr
      mesa
      stdenv.cc.cc.lib
      vulkan-loader
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
    Icon=opengoal-launcher
    Terminal=false
    Type=Application
    Categories=Game;
    StartupWMClass=OpenGOAL-Launcher
    StartupNotify=true
    PrefersNonDefaultGPU=true
    EOF

    install -Dm644 ${icon} $out/share/icons/hicolor/256x256/apps/opengoal-launcher.png
  '';

  meta = {
    description = "GUI launcher for OpenGOAL";
    homepage = "https://opengoal.dev";
    license = lib.licenses.isc;
    platforms = [ "x86_64-linux" ];
    mainProgram = "opengoal-launcher";
  };
}
