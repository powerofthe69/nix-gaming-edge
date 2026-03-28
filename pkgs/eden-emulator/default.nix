{
  lib,
  llvmPackages,
  callPackage,
  cmake,
  pkg-config,
  ninja,
  git,
  qt6,
  wrapGAppsHook3,
  gsettings-desktop-schemas,
  glib,
  gtk3,
  boost,
  fmt,
  nlohmann_json,
  lz4,
  zlib,
  zstd,
  openssl,
  httplib,
  ffmpeg-headless,
  libopus,
  cubeb,
  SDL2,
  vulkan-headers,
  vulkan-loader,
  vulkan-memory-allocator,
  vulkan-utility-libraries,
  spirv-tools,
  spirv-headers,
  glslang,
  libusb1,
  gamemode,
  catch2,
  enet,
  version,
  src,
}:

let
  cpm = callPackage ./_dependencies/generated.nix { };

  # CPM packages that need source paths
  cpmSources = {
    DiscordRPC = cpm.discord-rpc.src;
    SimpleIni = cpm.simpleini.src;
    sirit = cpm.sirit.src;
    oaknut = cpm.oaknut.src;
    xbyak = cpm.xbyak.src;
    cpp-jwt = cpm.cpp-jwt.src;
    libadrenotools = cpm.libadrenotools.src;
    unordered_dense = cpm.unordered-dense.src;
    QuaZip-Qt6 = cpm.quazip.src;
    frozen = cpm.frozen.src;
    biscuit = cpm.biscuit.src;
  };

  cpmFlags = lib.mapAttrsToList (name: src: "-DCPM_${name}_SOURCE=${src}") cpmSources;
in
llvmPackages.stdenv.mkDerivation {
  pname = "eden-emulator";
  inherit version src;

  nativeBuildInputs = [
    cmake
    pkg-config
    ninja
    git
    glslang
    qt6.wrapQtAppsHook
    wrapGAppsHook3
  ];

  buildInputs = [
    gsettings-desktop-schemas
    glib
    gtk3
    boost
    fmt
    nlohmann_json
    lz4
    zlib
    zstd
    openssl
    httplib
    ffmpeg-headless
    libopus
    cubeb
    SDL2
    vulkan-headers
    vulkan-loader
    vulkan-memory-allocator
    vulkan-utility-libraries
    spirv-tools
    spirv-headers
    libusb1
    gamemode
    catch2
    enet
    qt6.qtbase
    qt6.qtcharts
    qt6.qtmultimedia
    qt6.qtwayland
    qt6.qttools
  ];

  cmakeFlags = [
    "-DENABLE_QT=ON"
    "-DENABLE_SDL2=ON"
    "-DUSE_DISCORD_PRESENCE=ON"

    "-DYUZU_USE_BUNDLED_SDL2=OFF"
    "-DYUZU_USE_EXTERNAL_SDL2=OFF"
    "-DYUZU_USE_BUNDLED_FFMPEG=OFF"
    "-DSIRIT_USE_SYSTEM_SPIRV_HEADERS=ON"

    "-DYUZU_USE_CPM=OFF"
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
