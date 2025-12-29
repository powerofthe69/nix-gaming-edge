{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.drivers.mesa-git;
  shouldEnable32Bit = pkgs.stdenv.hostPlatform.isx86_64 && pkgs.stdenv.hostPlatform.isLinux;
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
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enableCache {
      nix.settings = {
        substituters = [ "https://nix-cache.tokidoki.dev/mesa-git" ];
        trusted-public-keys = [ "mesa-git:QdQcgcLR80ALQIG0hR0YZaPbbdrBvHy7R+zwMjYWUyw=" ];
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
  ];
}
