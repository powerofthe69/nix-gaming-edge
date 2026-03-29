{
  dotnet-runtime_10,
  dotnet-runtime_8, # to match current upstream reference
  lib,
  source,
  vintagestory, # from nixpkgs
}:
let
  version =
    let
      v = source.version;
      match = builtins.match ".*vs_client_linux-x64_(.*)" v;
    in
    if match != null then builtins.elemAt match 0 else v;
in
(vintagestory.override { waylandSupport = true; }).overrideAttrs (old: {
  inherit version;
  inherit (source) src;

  # RC tarball ships gameicon.png instead of gameicon.xpm
  nativeBuildInputs = builtins.filter (p: (p.pname or "") != "imagemagick") old.nativeBuildInputs;

  installPhase =
    builtins.replaceStrings
      [
        "magick $out/share/vintagestory/assets/gameicon.xpm $out/share/icons/hicolor/512x512/apps/vintagestory.png"
      ]
      [
        "cp $out/share/vintagestory/assets/gameicon.png $out/share/icons/hicolor/512x512/apps/vintagestory.png"
      ]
      old.installPhase;

  preFixup =
    let
      dotnet8exe = lib.meta.getExe dotnet-runtime_8;
      dotnet10exe = lib.meta.getExe dotnet-runtime_10;
      withDotnet10 = builtins.replaceStrings [ dotnet8exe ] [ dotnet10exe ] old.preFixup;
    in
    builtins.replaceStrings
      [ ''--set-default OPENTK_4_USE_WAYLAND 1 \'' ]
      [ ''--run 'if [ -n "$WAYLAND_DISPLAY" ]; then export OPENTK_4_USE_WAYLAND=1; fi' \'' ]
      withDotnet10;
})
