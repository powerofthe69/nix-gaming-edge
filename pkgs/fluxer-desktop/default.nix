{
  lib,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  # chromium / electron runtime
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libX11,
  libXScrnSaver,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXt, # stable's uiohook-napi
  libXtst,
  libxcb,
  libxkbcommon,
  libxshmfence,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  wayland,
  # nvfetcher entry (nvSources.fluxer-desktop / .fluxer-desktop-canary): provides
  # the prebuilt tarball src + version, with the hash managed by nvfetcher.
  source,
  # "stable" or "canary"
  channel ? "canary",
}:

let
  # Per-channel runtime bits; the tarball + version come from nvfetcher (source).
  channelMeta = {
    stable = {
      exe = "fluxer";
      displayName = "Fluxer";
    };
    canary = {
      exe = "fluxer-canary";
      displayName = "Fluxer Canary";
    };
  };
  ch = channelMeta.${channel};
in

stdenv.mkDerivation {
  inherit (source) pname version src;

  # Tarball extracts to a single dir whose name contains spaces + version.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p app
    tar xf "$src" -C app --strip-components=1
    runHook postUnpack
  '';
  sourceRoot = "app";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  # Patched into the bundled Electron + its .so/.node native addons.
  buildInputs = [
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
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXt
    libXtst
    libxcb
    libxkbcommon
    libxshmfence
    nspr
    nss
    pango
    pipewire # @fluxer/linux-{audio,screen}-capture
    systemd # @fluxer/linux-evdev (libudev)
    stdenv.cc.cc
  ];

  # dlopen'd at runtime (not in DT_NEEDED), so autoPatchelf needs the hint.
  runtimeDependencies = [ (lib.getLib systemd) ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/fluxer
    cp -r . $out/opt/fluxer

    # The bundled chrome-sandbox needs to be setuid-root, which a store path
    # can't be. Remove it so Electron falls back to the user-namespace sandbox
    # (enabled by default on NixOS).
    rm -f $out/opt/fluxer/chrome-sandbox

    mkdir -p $out/bin
    makeWrapper "$out/opt/fluxer/${ch.exe}" "$out/bin/${ch.exe}" \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libglvnd
          pipewire
          systemd
          wayland
        ]
      }" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations"

    # Canary keeps icons under resources/icons/<size>.png; stable only ships
    # resources/512x512.png.
    for size in 16 24 32 48 64 128 256 512; do
      for cand in "resources/icons/''${size}x''${size}.png" "resources/''${size}x''${size}.png"; do
        if [ -f "$cand" ]; then
          install -Dm644 "$cand" "$out/share/icons/hicolor/''${size}x''${size}/apps/${source.pname}.png"
          break
        fi
      done
    done

    mkdir -p $out/share/applications
    cat > "$out/share/applications/${source.pname}.desktop" <<EOF
    [Desktop Entry]
    Name=${ch.displayName}
    Comment=A chat app that puts you first
    Exec=$out/bin/${ch.exe} %U
    Icon=${source.pname}
    Type=Application
    Categories=Network;Chat;InstantMessaging;
    StartupWMClass=${ch.exe}
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Fluxer desktop client (${channel}, upstream prebuilt)";
    homepage = "https://fluxer.app";
    license = lib.licenses.agpl3Only;
    mainProgram = ch.exe;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
