{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.drivers.mesa-git;
  shouldEnable32Bit = pkgs.stdenv.hostPlatform.isx86_64 && pkgs.stdenv.hostPlatform.isLinux;

  # Legacy options. To be deprecated in favor of the newly split modules per issue #33.
  legacy = lib.attrValues cfg.cacheCleanup ++ lib.attrValues cfg.steamOrphanCleanup;
  legacyOpt =
    type: description:
    lib.mkOption {
      type = lib.types.nullOr type;
      default = null;
      visible = false;
      inherit description;
    };
  strs = lib.types.listOf lib.types.str;
  setIf = v: lib.mkIf (v != null) (lib.mkDefault v);
in
{
  imports = [
    ./mesa-cache-cleanup.nix
    ./steam-cleanup.nix
  ];

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

    # Deprecated: use services.mesa-cache-cleanup / services.steam-cleanup instead.
    cacheCleanup = {
      enable = legacyOpt lib.types.bool "Deprecated alias for services.mesa-cache-cleanup.enable (and steam-cleanup.protonCache.enable when protonPackage is set).";
      protonPackage = legacyOpt lib.types.package "Deprecated alias for services.steam-cleanup.protonCache.package.";
      mesaCacheDirs = legacyOpt strs "Deprecated alias for services.mesa-cache-cleanup.cacheDirs.";
      protonCacheFiles = legacyOpt strs "Deprecated alias for services.steam-cleanup.protonCache.cacheFiles.";
      protonCacheDirs = legacyOpt strs "Deprecated alias for services.steam-cleanup.protonCache.cacheDirs.";
    };
    steamOrphanCleanup = {
      enable = legacyOpt lib.types.bool "Deprecated alias for services.steam-cleanup.orphans.enable.";
      protectedFolders = legacyOpt strs "Deprecated alias for services.steam-cleanup.orphans.protectedFolders.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable (
      lib.mkMerge [
        {
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

          # No LD_PRELOAD or buildFHSEnv overlay needed: libdrm-git ships private SONAMEs.
        }

        (lib.mkIf cfg.enableCache {
          nix.settings = {
            substituters = [ "https://nix-cache.tokidoki.dev/tokidoki" ];
            trusted-public-keys = [ "tokidoki:MD4VWt3kK8Fmz3jkiGoNRJIW31/QAm7l1Dcgz2Xa4hk=" ];
          };
        })

        (lib.mkIf cfg.withStableFallback {
          specialisation.stable-mesa.configuration = {
            system.nixos.tags = [ "stable-mesa" ];
            drivers.mesa-git.enable = lib.mkForce false;
            hardware.graphics = {
              package = lib.mkForce pkgs.mesa;
              package32 = lib.mkIf shouldEnable32Bit (lib.mkForce pkgs.pkgsi686Linux.mesa);
            };
          };
        })
      ]
    ))

    {
      warnings =
        lib.optional (lib.any (v: v != null) legacy)
          "drivers.mesa-git.cacheCleanup / steamOrphanCleanup are deprecated; use services.mesa-cache-cleanup and services.steam-cleanup.";

      services.mesa-cache-cleanup = {
        enable = setIf cfg.cacheCleanup.enable;
        cacheDirs = setIf cfg.cacheCleanup.mesaCacheDirs;
      };
      services.steam-cleanup = {
        protonCache = {
          enable = lib.mkIf (cfg.cacheCleanup.enable != null && cfg.cacheCleanup.protonPackage != null) (
            lib.mkDefault cfg.cacheCleanup.enable
          );
          package = setIf cfg.cacheCleanup.protonPackage;
          cacheFiles = setIf cfg.cacheCleanup.protonCacheFiles;
          cacheDirs = setIf cfg.cacheCleanup.protonCacheDirs;
        };
        orphans = {
          enable = setIf cfg.steamOrphanCleanup.enable;
          protectedFolders = setIf cfg.steamOrphanCleanup.protectedFolders;
        };
      };
    }
  ];
}
