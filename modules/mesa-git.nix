{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.drivers.mesa-git;
  shouldEnable32Bit = pkgs.stdenv.hostPlatform.isx86_64 && pkgs.stdenv.hostPlatform.isLinux;

  findSteamLibraries = ''
    find_steam_libraries() {
      local user_home="$1"
      local libraries=""

      for config_path in \
        "$user_home/.local/share/Steam/steamapps/libraryfolders.vdf" \
        "$user_home/.steam/steam/steamapps/libraryfolders.vdf" \
        "$user_home/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf"; do

        if [ -f "$config_path" ]; then
          paths=$(${pkgs.gnugrep}/bin/grep -oP '"path"\s+"\K[^"]+' "$config_path" 2>/dev/null || true)
          for path in $paths; do
            [ -d "$path/steamapps" ] && libraries="$libraries $path/steamapps"
          done
        fi
      done

      echo "$libraries" | tr ' ' '\n' | sort -u | tr '\n' ' '
    }
  '';

  matchesAnyPattern = patterns: ''
    matches_pattern() {
      local name="$1"
      for pattern in ${lib.escapeShellArgs patterns}; do
        case "$name" in
          $pattern) return 0 ;;
        esac
      done
      return 1
    }
  '';

  mesaCacheCleanerScript = pkgs.writeShellScript "mesa-cache-cleaner" ''
    set -euo pipefail

    ${findSteamLibraries}
    ${matchesAnyPattern cfg.cacheCleanup.mesaCacheDirs}

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

      for item in "$user_home/.cache/"*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        matches_pattern "$name" && rm -rf "$item"
      done

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

  protonCacheCleanerScript = pkgs.writeShellScript "proton-cache-cleaner" ''
    set -euo pipefail

    ${findSteamLibraries}
    ${matchesAnyPattern cfg.cacheCleanup.protonCacheFiles}
    ${matchesAnyPattern cfg.cacheCleanup.protonCacheDirs}

    is_cache_file() {
      local name="$1"
      for pattern in ${lib.escapeShellArgs cfg.cacheCleanup.protonCacheFiles}; do
        case "$name" in
          $pattern) return 0 ;;
        esac
      done
      return 1
    }

    is_cache_dir() {
      local name="$1"
      for pattern in ${lib.escapeShellArgs cfg.cacheCleanup.protonCacheDirs}; do
        case "$name" in
          $pattern) return 0 ;;
        esac
      done
      return 1
    }

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

        if [ -d "$steam_lib/common" ]; then
          echo "  Scanning $steam_lib/common"
          find "$steam_lib/common" -type f | while read -r file; do
            is_cache_file "$(basename "$file")" && rm -f "$file"
          done
        fi

        if [ -d "$steam_lib/compatdata" ]; then
          echo "  Scanning $steam_lib/compatdata"
          find "$steam_lib/compatdata" -type d | while read -r dir; do
            is_cache_dir "$(basename "$dir")" && rm -rf "$dir"
          done
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
      for pattern in ${lib.escapeShellArgs cfg.steamOrphanCleanup.protectedFolders}; do
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
  options.drivers.mesa-git = {
    enable = lib.mkEnableOption "bleeding-edge Mesa drivers from Git";

    withStableFallback = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add a boot entry with stable Mesa in case of issues.";
    };

    enableCache = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add self-hosted mesa-git cache to substituters.";
    };

    cacheCleanup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatic shader cache cleanup on driver updates. Recommended to avoid stale cache.";
      };

      protonPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Proton package to track for DXVK/VKD3D cache cleanup.";
        example = lib.literalExpression "pkgs.proton-cachyos";
      };

      mesaCacheDirs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "mesa_shader_cache*"
          "radv_builtin_shaders*"
          "vulkan"
          "*GPUCache"
        ];
        description = "Glob patterns for Mesa cache directories under ~/.cache.";
      };

      protonCacheFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "*.dxvk-cache"
          "vkd3d-proton.cache*"
          "vulkan_pso_cache*"
          "shader*.cache"
        ];
        description = "Glob patterns for Proton cache files in game directories.";
      };

      protonCacheDirs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "UnityShaderCache"
          "DerivedDataCache"
          "D3DSCache"
          "ShaderCache"
          "GLCache"
        ];
        description = "Glob patterns for engine cache directories in Wine prefixes.";
      };
    };

    steamOrphanCleanup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatic cleanup of orphaned Steam prefixes and game folders.";
      };

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
    (lib.mkIf cfg.enableCache {
      nix.settings = {
        substituters = [ "https://nix-cache.tokidoki.dev/tokidoki" ];
        trusted-public-keys = [ "tokidoki:MD4VWt3kK8Fmz3jkiGoNRJIW31/QAm7l1Dcgz2Xa4hk=" ];
      };
    })

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = pkgs ? mesa-git;
          message = ''
            drivers.mesa-git requires the mesa-git overlay.
            Add to your configuration:
              nixpkgs.overlays = [ inputs.mesa-git.overlays.default ];
          '';
        }
      ];

      hardware.graphics = {
        enable = true;
        package = pkgs.mesa-git;
        enable32Bit = shouldEnable32Bit;
      }
      // lib.optionalAttrs shouldEnable32Bit {
        package32 = pkgs.mesa32-git;
      };
    })

    (lib.mkIf (cfg.enable && cfg.withStableFallback) {
      specialisation.stable-mesa.configuration = {
        system.nixos.tags = [ "stable-mesa" ];
        drivers.mesa-git.enable = lib.mkForce false;
        hardware.graphics = {
          package = lib.mkForce pkgs.mesa;
          package32 = lib.mkIf shouldEnable32Bit (lib.mkForce pkgs.pkgsi686Linux.mesa);
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.cacheCleanup.enable) {
      system.activationScripts.mesaCacheCleaner = ''
        echo "--- Checking for Mesa Driver Updates ---"
        ${mesaCacheCleanerScript} "${pkgs.mesa-git.version}"
      '';
    })

    (lib.mkIf (cfg.enable && cfg.cacheCleanup.enable && cfg.cacheCleanup.protonPackage != null) {
      system.activationScripts.protonCacheCleaner = ''
        echo "--- Checking for Proton Updates ---"
        ${protonCacheCleanerScript} "${cfg.cacheCleanup.protonPackage.version}"
      '';
    })

    (lib.mkIf (cfg.enable && cfg.steamOrphanCleanup.enable) {
      system.activationScripts.steamOrphanCleaner = ''
        ${steamOrphanCleanerScript}
      '';
    })
  ];
}
