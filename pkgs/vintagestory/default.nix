{
  lib,
  stdenv,
  makeWrapper,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  imagemagick,
  dotnet-runtime_8,
  xorg,
  libglvnd,
  openal,
  pipewire,
  wayland,
  libxkbcommon,
  cairo,
  gtk3,
  sourceData, # { src, version }
}:

stdenv.mkDerivation rec {
  pname = "vintagestory";
  inherit (sourceData) version src;

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
    copyDesktopItems
    imagemagick
  ];

  buildInputs = [
    dotnet-runtime_8
    stdenv.cc.cc.lib
    xorg.libX11
    xorg.libXi
    xorg.libXcursor
    libglvnd
    openal
    wayland
    libxkbcommon
    pipewire
    cairo
    gtk3
  ];

  # Ignore internal C# dlls, patch native libs
  autoPatchelfIgnoreMissingDeps = [
    "*.dll"
    "System.*"
    "Microsoft.*"
    "Lib.*"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/vintagestory
    cp -r * $out/share/vintagestory/

    mkdir -p $out/share/icons/hicolor/256x256/apps
    magick assets/gameicon.xpm -thumbnail 256x256 $out/share/icons/hicolor/256x256/apps/vintagestory.png

    # The Wrapper
    makeWrapper ${dotnet-runtime_8}/bin/dotnet $out/bin/vintagestory \
      --add-flags "$out/share/vintagestory/Vintagestory.dll" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --set DOTNET_ROOT "${dotnet-runtime_8}" \
      --run 'if [ -n "$WAYLAND_DISPLAY" ]; then export OPENTK_4_USE_WAYLAND=1; fi'

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "vintagestory";
      desktopName = "Vintage Story";
      exec = "vintagestory";
      icon = "vintagestory";
      comment = "Uncompromising Wilderness Survival";
      categories = [
        "Game"
        "Simulation"
      ];
    })
  ];

  meta = with lib; {
    description = "An in-depth voxel survival game";
    homepage = "https://www.vintagestory.at/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "vintagestory";
  };
}
