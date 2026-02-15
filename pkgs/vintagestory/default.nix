{
  vintagestory, # from nixpkgs
  source,
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

  # Auto-detect Wayland at runtime instead of upstream's waylandSupport flag
  preFixup =
    builtins.replaceStrings
      [ ''--set-default OPENTK_4_USE_WAYLAND 1 \'' ]
      [ ''--run 'if [ -n "$WAYLAND_DISPLAY" ]; then export OPENTK_4_USE_WAYLAND=1; fi' \'' ]
      old.preFixup;
})
