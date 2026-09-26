{
  config,
  lib,
  pkgs,
  ...
}:

# Purges driver-derived shader caches whenever the tracked Mesa version changes.
# Steam's shadercache dirs are included because their pipeline caches are driver-specific.
let
  cfg = config.services.mesa-cache-cleanup;

  mkFindPatterns =
    patterns: lib.concatMapStringsSep " -o " (p: "-name ${lib.escapeShellArg p}") patterns;

  findSteamLibraries = import ./lib/steam-libraries.nix { inherit pkgs; };

  mesaCacheCleanerScript = pkgs.writeShellScript "mesa-cache-cleaner" ''
    set -euo pipefail

    ${findSteamLibraries}

    MESA_VERSION="$1"
    TRACKER="/var/lib/shader-cache-tracker/mesa.version"
    LAST=""
    [ -f "$TRACKER" ] && LAST=$(cat "$TRACKER")

    if [ "$MESA_VERSION" = "$LAST" ]; then
      echo "Mesa unchanged ($MESA_VERSION). Skipping."
      exit 0
    fi

    echo "Mesa changed: $LAST -> $MESA_VERSION"

    for user_home in /home/*; do
      [ -d "$user_home" ] || continue
      echo "Cleaning Mesa caches for $(basename "$user_home")"

      # Clean ~/.cache directories matching patterns
      if [ -d "$user_home/.cache" ]; then
        find "$user_home/.cache" -maxdepth 1 -type d \( ${mkFindPatterns cfg.cacheDirs} \) -exec rm -rf {} + 2>/dev/null || true
      fi

      # Clean Steam shader caches
      libraries=$(find_steam_libraries "$user_home")
      for steam_lib in $libraries; do
        [ -d "$steam_lib/shadercache" ] && {
          echo "  Clearing $steam_lib/shadercache"
          rm -rf "$steam_lib/shadercache/"*
        }
      done
    done

    mkdir -p "$(dirname "$TRACKER")"
    echo "$MESA_VERSION" > "$TRACKER"
    echo "Mesa cache purge complete."
  '';
in
{
  options.services.mesa-cache-cleanup = {
    enable = lib.mkEnableOption "automatic Mesa shader cache cleanup on driver updates";

    package = lib.mkOption {
      type = lib.types.package;
      # hardware.graphics.package is only defined once hardware.graphics.enable is set.
      default = if config.hardware.graphics.enable then config.hardware.graphics.package else pkgs.mesa;
      defaultText = lib.literalExpression "config.hardware.graphics.package";
      description = "Mesa package whose version is tracked. Defaults to the system graphics driver.";
      example = lib.literalExpression "pkgs.mesa-git";
    };

    cacheDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "mesa_shader_cache*"
        "radv_builtin_shaders*"
        "vulkan"
        "*GPUCache"
      ];
      description = "Glob patterns for Mesa cache directories under ~/.cache.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mesa-cache-cleaner = {
      description = "removing Mesa shader caches";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${mesaCacheCleanerScript} ${cfg.package.version}";
        RemainAfterExit = true;
      };
    };
  };
}
