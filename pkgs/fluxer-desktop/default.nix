{
  autoPatchelfHook,
  electron,
  fetchPnpmDeps,
  lib,
  libglvnd,
  libXt,
  libXtst,
  makeWrapper,
  nodejs,
  pipewire,
  pnpm_10,
  pnpmConfigHook,
  source,
  stdenv,
  systemd,
  wayland,
  wrapGAppsHook3,
}:

let
  pnpmHash = lib.fileContents ./pnpm-hash.txt;

  postUnpack = ''
    chmod u+w ${source.src.name} ${source.src.name}/package.json
    sed -i '/"packageManager"/d' ${source.src.name}/package.json
  '';
in

stdenv.mkDerivation {
  pname = "fluxer-desktop";
  inherit (source) version;
  src = source.src;

  sourceRoot = "${source.src.name}/fluxer_desktop";
  inherit postUnpack;

  pnpmDeps = fetchPnpmDeps {
    pname = "fluxer-desktop-pnpm-deps";
    inherit (source) version;
    src = source.src;
    sourceRoot = "${source.src.name}/fluxer_desktop";
    inherit postUnpack;
    pnpm = pnpm_10;
    fetcherVersion = 2;
    hash = pnpmHash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    nodejs
    pnpm_10
    pnpmConfigHook
    wrapGAppsHook3
  ];

  # Only libstdc++ for prebuilt native node addons (@electron-webauthn/native, uiohook-napi)
  buildInputs = [
    libXt
    libXtst
    stdenv.cc.cc.lib
  ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  dontWrapGApps = true;

  buildPhase = ''
    runHook preBuild
    NODE_ENV=production node scripts/build.mjs
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/fluxer-desktop
    cp package.json $out/lib/fluxer-desktop/
    cp -r dist $out/lib/fluxer-desktop/
    cp -r node_modules $out/lib/fluxer-desktop/

    mkdir -p $out/bin
    makeWrapper ${electron}/bin/electron $out/bin/fluxer \
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
      --add-flags "$out/lib/fluxer-desktop" \
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
    StartupWMClass=fluxer_desktop
    EOF

    for size in 16 24 32 48 64 128 256 512 1024; do
      icon="build_resources/icons-stable/''${size}x''${size}.png"
      if [ -f "$icon" ]; then
        install -Dm644 "$icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/fluxer.png"
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Fluxer desktop client";
    homepage = "https://fluxer.app";
    license = licenses.agpl3Only;
    mainProgram = "fluxer";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ sourceTypes.fromSource ];
  };
}
