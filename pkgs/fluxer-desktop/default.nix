{
  lib,
  stdenv,
  addDriverRunpath,
  autoPatchelfHook,
  makeWrapper,
  unzip,
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
  libva,
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
  libXt,
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
  channel ? "stable",
  source,
}:

let
  # Per-channel artifact names; the tarball/zip + version come from nvfetcher.
  # appId = Electron desktopName (sans .desktop) = Wayland app_id; GNOME maps windows by it.
  ch =
    {
      stable = {
        appId = "app.fluxer.FluxerDesktop";
        exe = "fluxer";
        displayName = "Fluxer";
        app = "Fluxer.app";
        bundleExe = "Fluxer";
      };
      canary = {
        appId = "app.fluxer.FluxerDesktopCanary";
        exe = "fluxer-canary";
        displayName = "Fluxer Canary";
        app = "Fluxer Canary.app";
        bundleExe = "Fluxer Canary";
      };
    }
    .${channel};

  linuxAttrs = {
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
      libva
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
            libnotify
            libsecret
            libva
            pipewire
            systemd
            wayland
          ]
        }" \
        --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib" \
        --add-flags "--ozone-platform-hint=auto" \
        --add-flags "--enable-features=WaylandWindowDecorations"

      # Fail loudly if upstream renames the app_id again (window/icon mapping breaks silently)
      grep -aq '"desktopName": *"${ch.appId}.desktop"' resources/app.asar

      # Icons live under resources/icons/<size>.png (older builds used resources/<size>x<size>.png).
      for size in 16 24 32 48 64 128 256 512; do
        for cand in "resources/icons/''${size}x''${size}.png" "resources/''${size}x''${size}.png"; do
          if [ -f "$cand" ]; then
            install -Dm644 "$cand" "$out/share/icons/hicolor/''${size}x''${size}/apps/${ch.appId}.png"
            break
          fi
        done
      done

      mkdir -p $out/share/applications
      cat > "$out/share/applications/${ch.appId}.desktop" <<EOF
      [Desktop Entry]
      Name=${ch.displayName}
      Comment=A chat app that puts you first
      Exec=$out/bin/${ch.exe} %U
      Icon=${ch.appId}
      Type=Application
      Categories=Network;Chat;InstantMessaging;
      MimeType=x-scheme-handler/fluxer;
      StartupWMClass=${ch.appId}
      EOF

      runHook postInstall
    '';
  };

  # Install the signed .app untouched (dontFixup keeps the upstream signature valid).
  darwinAttrs = {
    nativeBuildInputs = [
      makeWrapper
      unzip
    ];

    # $src is named just "zip" (URL ends in /latest/zip), so the default unpacker can't dispatch it.
    unpackPhase = ''
      runHook preUnpack
      unzip -q "$src"
      runHook postUnpack
    '';
    sourceRoot = ".";
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications $out/bin
      cp -R "${ch.app}" $out/Applications/
      makeWrapper "$out/Applications/${ch.app}/Contents/MacOS/${ch.bundleExe}" "$out/bin/${ch.exe}"

      runHook postInstall
    '';
  };
in

stdenv.mkDerivation (
  {
    inherit (source) pname version src;

    meta = {
      description = "Fluxer desktop client (upstream prebuilt)";
      homepage = "https://fluxer.app";
      license = lib.licenses.agpl3Only;
      mainProgram = ch.exe;
      platforms = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
  // (if stdenv.hostPlatform.isDarwin then darwinAttrs else linuxAttrs)
)
