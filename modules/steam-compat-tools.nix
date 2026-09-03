# Home-manager module: link Steam compat tools into compatibilitytools.d for use outside of Steam.
{
  config,
  lib,
  osConfig,
  ...
}:

let
  cfg = config.programs.steam-compat-tools;
in
{
  options.programs.steam-compat-tools = {
    enable = (lib.mkEnableOption "linking Steam compat tools into compatibilitytools.d") // {
      default = true;
      example = false;
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = lib.optionals (osConfig != null) (osConfig.programs.steam.extraCompatPackages or [ ]);
      defaultText = lib.literalExpression "osConfig.programs.steam.extraCompatPackages or [ ]";
      example = lib.literalExpression "[ pkgs.proton-cachyos-x86_64-v3 pkgs.proton-ge-bin ]";
      description = "Compat tool packages to link; defaults to NixOS's `programs.steam.extraCompatPackages` when available. A package's steamcompattool output is used when present.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.dataFile = lib.listToAttrs (
      map (pkg: {
        name = "Steam/compatibilitytools.d/${lib.getName pkg}";
        value.source = pkg.steamcompattool or pkg;
      }) cfg.packages
    );
  };
}
