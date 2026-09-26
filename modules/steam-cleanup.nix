{
  config,
  lib,
  pkgs,
  ...
}:

# Steam-library housekeeping, independent of the graphics driver: Proton/engine caches
# purged on Proton version changes, and folders Steam left behind after uninstalls.
let
  cfg = config.services.steam-cleanup;

  mkFindPatterns =
    patterns: lib.concatMapStringsSep " -o " (p: "-name ${lib.escapeShellArg p}") patterns;

  findSteamLibraries = import ./lib/steam-libraries.nix { inherit pkgs; };

  protonCacheCleanerScript = pkgs.writeShellScript "proton-cache-cleaner" ''
    set -euo pipefail

    ${findSteamLibraries}

    PROTON_VERSION="$1"
    TRACKER="/var/lib/shader-cache-tracker/proton.version"
    LAST=""
    [ -f "$TRACKER" ] && LAST=$(cat "$TRACKER")

    if [ "$PROTON_VERSION" = "$LAST" ]; then
      echo "Proton unchanged ($PROTON_VERSION). Skipping."
      exit 0
    fi

    echo "Proton changed: $LAST -> $PROTON_VERSION"

    for user_home in /home/*; do
      [ -d "$user_home" ] || continue
      echo "Cleaning Proton caches for $(basename "$user_home")"

      libraries=$(find_steam_libraries "$user_home")
      for steam_lib in $libraries; do
        [ -d "$steam_lib" ] || continue

        # Delete cache files in game directories
        if [ -d "$steam_lib/common" ]; then
          echo "  Cleaning cache files in $steam_lib/common"
          find "$steam_lib/common" -type f \( ${mkFindPatterns cfg.protonCache.cacheFiles} \) -delete 2>/dev/null || true
        fi

        # Delete cache directories in Wine prefixes
        if [ -d "$steam_lib/compatdata" ]; then
          echo "  Cleaning cache dirs in $steam_lib/compatdata"
          find "$steam_lib/compatdata" -type d \( ${mkFindPatterns cfg.protonCache.cacheDirs} \) -exec rm -rf {} + 2>/dev/null || true
        fi
      done
    done

    mkdir -p "$(dirname "$TRACKER")"
    echo "$PROTON_VERSION" > "$TRACKER"
    echo "Proton cache purge complete."
  '';

  steamOrphanCleanerScript = pkgs.writeShellScript "steam-orphan-cleaner" ''
    set -euo pipefail

    ${findSteamLibraries}

    is_protected() {
      local name="$1"
      for pattern in ${lib.escapeShellArgs cfg.orphans.protectedFolders}; do
        case "$name" in
          $pattern) return 0 ;;
        esac
      done
      return 1
    }

    echo "--- Scanning Steam Libraries for Orphaned Folders ---"

    ORPHANS_FOUND=0

    for user_home in /home/*; do
      [ -d "$user_home" ] || continue

      libraries=$(find_steam_libraries "$user_home")
      for steam_lib in $libraries; do
        [ -d "$steam_lib" ] || continue

        echo "Checking $steam_lib"

        valid_appids=""
        valid_dirs=""
        for manifest in "$steam_lib"/appmanifest_*.acf; do
          [ -f "$manifest" ] || continue
          appid=$(basename "$manifest" .acf | cut -d_ -f2)
          valid_appids="$valid_appids:$appid:"
          installdir=$(${pkgs.gnugrep}/bin/grep -Po '"installdir"\s+"\K[^"]+' "$manifest" || true)
          [ -n "$installdir" ] && valid_dirs="$valid_dirs:$installdir:"
        done

        if [ -d "$steam_lib/compatdata" ]; then
          for dir in "$steam_lib/compatdata/"*/; do
            [ -d "$dir" ] || continue
            dirname=$(basename "$dir")
            [ "$dirname" = "0" ] && continue
            case "$valid_appids" in
              *":$dirname:"*) ;;
              *)
                echo "Deleting orphaned Proton prefix: $dirname"
                rm -rf "$dir"
                ORPHANS_FOUND=1
                ;;
            esac
          done
        fi

        if [ -d "$steam_lib/common" ]; then
          for dir in "$steam_lib/common/"*/; do
            [ -d "$dir" ] || continue
            dirname=$(basename "$dir")
            is_protected "$dirname" && continue
            case "$valid_dirs" in
              *":$dirname:"*) ;;
              *)
                echo "Deleting orphaned game folder: $dirname"
                rm -rf "$dir"
                ORPHANS_FOUND=1
                ;;
            esac
          done
        fi
      done
    done

    [ "$ORPHANS_FOUND" -eq 1 ] && echo "Empty folder cleanup complete." || echo "No empty folders found. Skipping."
  '';
in
{
  options.services.steam-cleanup = {
    protonCache = {
      enable = lib.mkEnableOption "automatic DXVK/VKD3D/engine cache cleanup on Proton updates";

      package = lib.mkOption {
        type = lib.types.package;
        description = "Proton package whose version is tracked.";
        example = lib.literalExpression "pkgs.proton-cachyos";
      };

      cacheFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "*.dxvk-cache"
          "vkd3d-proton.cache*"
          "vulkan_pso_cache*"
          "shader*.cache"
        ];
        description = "Glob patterns for Proton cache files in game directories.";
      };

      cacheDirs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "DerivedDataCache"
          "D3DSCache"
          "*ShaderCache"
          "GLCache"
        ];
        description = "Glob patterns for engine cache directories in Wine prefixes.";
      };
    };

    orphans = {
      enable = lib.mkEnableOption "automatic cleanup of orphaned Steam prefixes and game folders";

      protectedFolders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "Steam Controller Configs"
          "Proton*"
          "SteamLinuxRuntime*"
          "Steamworks Shared"
        ];
        description = "Glob patterns for folders in steamapps/common to protect.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.protonCache.enable {
      systemd.services.proton-cache-cleaner = {
        description = "removing Proton shader caches";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${protonCacheCleanerScript} ${cfg.protonCache.package.version}";
          RemainAfterExit = true;
        };
      };
    })

    (lib.mkIf cfg.orphans.enable {
      systemd.services.steam-orphan-cleaner = {
        description = "removing orphaned Steam game folders and prefixes";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${steamOrphanCleanerScript}";
          RemainAfterExit = true;
        };
      };
    })
  ];
}
