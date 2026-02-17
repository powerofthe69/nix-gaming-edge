{
  lib,
  stdenv,
  source,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libglvnd,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  wayland,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
  libXt,
  libXtst,
}:

stdenv.mkDerivation {
  pname = "fluxer-desktop";
  inherit (source) version src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libxkbcommon
    mesa
    nspr
    nss
    pango
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    libXt
    libXtst
  ];

  runtimeDependencies = map lib.getLib [
    libglvnd
    pipewire
    systemd
    wayland
  ];

  unpackPhase = ''
    runHook preUnpack
    tar xzf "$src"
    runHook postUnpack
  '';

  sourceRoot = ".";
  dontBuild = true;
  dontConfigure = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    local srcdir
    srcdir=$(find . -maxdepth 1 -type d -name 'fluxer*' | head -1)
    [ -z "$srcdir" ] && srcdir="."

    mkdir -p $out/opt/fluxer
    cp -r "$srcdir"/* $out/opt/fluxer/

    chmod +x $out/opt/fluxer/fluxer

    mkdir -p $out/bin
    makeWrapper $out/opt/fluxer/fluxer $out/bin/fluxer \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath (
          map lib.getLib [
            libglvnd
            pipewire
            systemd
            wayland
          ]
        )
      }" \
      --add-flags "\''${NIXOS_OZONE_WL:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}"

    mkdir -p $out/share/applications
    cat > $out/share/applications/fluxer.desktop <<EOF
    [Desktop Entry]
    Name=Fluxer
    Comment=A chat app that puts you first
    Exec=$out/bin/fluxer
    Icon=fluxer
    Type=Application
    Categories=Network;Chat;InstantMessaging;
    StartupWMClass=fluxer_app
    EOF

    mkdir -p $out/share/icons/hicolor/512x512/apps
    cp $out/opt/fluxer/resources/512x512.png $out/share/icons/hicolor/512x512/apps/fluxer.png

    runHook postInstall
  '';

  meta = with lib; {
    description = "Fluxer desktop client";
    homepage = "https://fluxer.app";
    license = licenses.agpl3Only;
    mainProgram = "fluxer";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
