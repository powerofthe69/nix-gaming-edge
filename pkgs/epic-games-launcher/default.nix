{
  appimageTools,
  buildFHSEnv,
  fetchurl,
  lib,
  source, # Source from nvfetcher
  writeShellScript,
}:

let
  pname = "epic-games-launcher";
  version = source.version;

  # Pin the versioned CDN path ("+" must be %2B or the CDN 403s)
  src = fetchurl {
    url = "https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/${
      lib.replaceStrings [ "+" ] [ "%2B" ] version
    }/Linux/EpicGamesLauncher-x86_64.AppImage";
    hash = source.src.outputHash;
  };

  extracted = appimageTools.extractType2 { inherit pname version src; };
in

buildFHSEnv (
  appimageTools.defaultFhsEnvArgs
  // {
    inherit pname version;

    targetPkgs =
      pkgs:
      appimageTools.defaultFhsEnvArgs.targetPkgs pkgs
      ++ [
        pkgs.python3
        pkgs.sdl3
      ];

    runScript = writeShellScript "epic-games-launcher-run" ''
      set -euo pipefail

      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/epic-games-launcher"
      CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/epic-games-launcher"
      APPIMAGE_PATH="$DATA_DIR/EpicGamesLauncher-x86_64.AppImage"
      SEED_STAMP="$DATA_DIR/.nix-seed-version"
      mkdir -p "$DATA_DIR" "$CACHE_DIR"

      # Reseed only when the nix-provided version changes, so self-updates survive relaunches
      if [[ ! -f "$APPIMAGE_PATH" || "$(cat "$SEED_STAMP" 2>/dev/null)" != "${version}" ]]; then
        install -m755 ${src} "$APPIMAGE_PATH.tmp"
        mv -f "$APPIMAGE_PATH.tmp" "$APPIMAGE_PATH"
        echo "${version}" > "$SEED_STAMP"
      fi

      # No FUSE inside the FHS env: extract once per AppImage revision and run from cache
      key="$(stat -c '%s-%Y' "$APPIMAGE_PATH")"
      APPDIR="$CACHE_DIR/$key"
      if [[ ! -x "$APPDIR/AppRun" ]]; then
        echo "Extracting Epic Games Launcher..." >&2
        find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        tmp="$(mktemp -d "$CACHE_DIR/.extract.XXXXXX")"
        (cd "$tmp" && "$APPIMAGE_PATH" --appimage-extract >/dev/null)
        mv "$tmp/squashfs-root" "$APPDIR"
        rmdir "$tmp"
      fi

      export APPIMAGE="$APPIMAGE_PATH" APPDIR
      export APPIMAGE_EXTRACT_AND_RUN=1
      exec "$APPDIR/AppRun" "$@"
    '';

    extraInstallCommands = ''
      install -Dm644 ${extracted}/epic-games-launcher.desktop $out/share/applications/epic-games-launcher.desktop
      substituteInPlace $out/share/applications/epic-games-launcher.desktop \
        --replace-fail 'Exec=EpicGamesLauncher' "Exec=$out/bin/epic-games-launcher"
      cp -r ${extracted}/usr/share/icons $out/share/icons
    '';

    meta = {
      description = "Official Epic Games Launcher (EGLv2 preview, native Linux AppImage)";
      homepage = "https://store.epicgames.com";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "epic-games-launcher";
    };
  }
)
