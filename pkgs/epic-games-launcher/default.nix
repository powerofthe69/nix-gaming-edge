{
  appimageTools,
  buildFHSEnv,
  dpkg,
  lib,
  source, # Source from nvfetcher
  stdenvNoCC,
}:

let
  pname = "epic-games-launcher";
  # nvfetcher emits the URL-encoded version; decode it for display
  version = lib.replaceStrings [ "%2B" ] [ "+" ] source.version;

  # Unpacked .deb; FHS maps its bin/ and lib/ to /usr, where Tauri resolves its resource dir
  unpacked = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;
    inherit (source) src;

    nativeBuildInputs = [ dpkg ];

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r usr/* $out/
      runHook postInstall
    '';

    dontFixup = true;
  };
in

buildFHSEnv (
  appimageTools.defaultFhsEnvArgs
  // {
    inherit pname version;

    targetPkgs =
      pkgs:
      appimageTools.defaultFhsEnvArgs.targetPkgs pkgs
      ++ [
        unpacked
        # .deb Depends: (the old AppImage bundled these)
        pkgs.glib-networking
        pkgs.gtk3
        pkgs.libayatana-appindicator
        pkgs.libsoup_3
        pkgs.python3
        pkgs.sdl3
        pkgs.webkitgtk_4_1
      ];

    runScript = "/usr/bin/EpicGamesLauncher";

    extraInstallCommands = ''
      install -Dm644 ${unpacked}/share/applications/epic-games-launcher.desktop $out/share/applications/epic-games-launcher.desktop
      substituteInPlace $out/share/applications/epic-games-launcher.desktop \
        --replace-fail 'Exec=EpicGamesLauncher' "Exec=$out/bin/epic-games-launcher"
      cp -r ${unpacked}/share/icons $out/share/icons
    '';

    meta = {
      description = "Official Epic Games Launcher (EGLv2 preview, native Linux .deb)";
      homepage = "https://store.epicgames.com";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "epic-games-launcher";
    };
  }
)
