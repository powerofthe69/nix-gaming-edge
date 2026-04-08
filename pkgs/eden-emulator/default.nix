{
  boost,
  callPackage,
  catch2,
  cmake,
  cubeb,
  enet,
  ffmpeg-headless,
  fmt,
  gamemode,
  git,
  glib,
  glslang,
  gsettings-desktop-schemas,
  gtk3,
  lib,
  libopus,
  libusb1,
  llvmPackages,
  lz4,
  ninja,
  nlohmann_json,
  openssl,
  pkg-config,
  qt6,
  SDL2,
  spirv-headers,
  spirv-tools,
  src,
  version,
  vulkan-headers,
  vulkan-loader,
  vulkan-memory-allocator,
  vulkan-utility-libraries,
  wrapGAppsHook3,
  zlib,
  zstd,
}:

let
  cpm = callPackage ./_dependencies/generated.nix { };

  # Vendored CPM sources, populated from eden's upstream cpmfile.json
  # Everything between AUTO-CPM-SOURCES is regenerated
  cpmSources = {
    # >>> AUTO-CPM-SOURCES
    cpp-jwt = cpm.cpp-jwt.src;
    DiscordRPC = cpm.discord-rpc.src;
    frozen = cpm.frozen.src;
    httplib = cpm.httplib.src;
    QuaZip-Qt6 = cpm.quazip.src;
    SimpleIni = cpm.simpleini.src;
    sirit = cpm.sirit.src;
    unordered_dense = cpm.unordered-dense.src;
    xbyak = cpm.xbyak.src;
    # <<< AUTO-CPM-SOURCES
  };

  cpmFlags = lib.mapAttrsToList (name: src: "-DCPM_${name}_SOURCE=${src}") cpmSources;
in
llvmPackages.stdenv.mkDerivation {
  pname = "eden-emulator";
  inherit version src;

  nativeBuildInputs = [
    cmake
    git
    glslang
    ninja
    pkg-config
    qt6.wrapQtAppsHook
    wrapGAppsHook3
  ];

  buildInputs = [
    boost
    catch2
    cubeb
    enet
    ffmpeg-headless
    fmt
    gamemode
    glib
    gsettings-desktop-schemas
    gtk3
    libopus
    libusb1
    lz4
    nlohmann_json
    openssl
    qt6.qtbase
    qt6.qtcharts
    qt6.qtmultimedia
    qt6.qttools
    qt6.qtwayland
    SDL2
    spirv-headers
    spirv-tools
    vulkan-headers
    vulkan-loader
    vulkan-memory-allocator
    vulkan-utility-libraries
    zlib
    zstd
  ];

  cmakeFlags = [
    "-DENABLE_QT=ON"
    "-DUSE_DISCORD_PRESENCE=ON"

    "-DYUZU_USE_BUNDLED_SDL2=OFF"
    "-DYUZU_USE_EXTERNAL_SDL2=OFF"
    "-DYUZU_USE_BUNDLED_FFMPEG=OFF"
    "-DSIRIT_USE_SYSTEM_SPIRV_HEADERS=ON"

    "-DCPM_USE_LOCAL_PACKAGES=ON"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DYUZU_USE_BUNDLED_SIRIT=ON"
  ]
  ++ cpmFlags;

  preConfigure = ''
    # Extract timezone database
    mkdir -p externals/nx_tzdb_data
    tar xf ${cpm.nx_tzdb.src} -C externals/nx_tzdb_data --strip-components=1
    cmakeFlagsArray+=("-DYUZU_TZDB_PATH=$(pwd)/externals/nx_tzdb_data")
  '';

  postPatch = ''
    # Set version info for nightly builds
    echo "nightly-${builtins.substring 0 7 version}" > GIT-TAG
    echo "${version}" > GIT-RELEASE
    echo "nightly" > GIT-REFSPEC
    echo "${version}" > GIT-COMMIT
  '';

  dontWrapGApps = true;

  postFixup = ''
    wrapProgram $out/bin/eden \
      "''${gappsWrapperArgs[@]}" \
      "''${qtWrapperArgs[@]}"
  '';

  meta = {
    description = "Nintendo Switch emulator";
    homepage = "https://git.eden-emu.dev/eden-emu/eden";
    license = lib.licenses.gpl3Plus;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "eden";
  };
}
