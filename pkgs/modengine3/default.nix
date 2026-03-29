{
  autoPatchelfHook,
  gcc,
  lib,
  makeWrapper,
  openssl,
  source,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "modengine3";
  version = source.version;

  inherit (source) src;

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    gcc.cc.lib
    openssl
  ];

  installPhase = ''
    runHook preInstall

    install -Dpm 0755 bin/me3 $out/bin/.me3-unwrapped
    install -Dpm 0644 -t $out/share/me3/windows-bin bin/win64/me3-launcher.exe bin/win64/me3_mod_host.dll
    install -Dpm 0644 -t $out/share/applications dist/me3-launch.desktop
    install -Dpm 0644 -t $out/share/mime/packages dist/me3.xml
    install -Dpm 0644 -t $out/share/icons/hicolor/128x128/apps dist/me3.png
    install -Dpm 0644 -t $out/share/me3/profiles ./*.me3

    makeWrapper $out/bin/.me3-unwrapped $out/bin/me3 \
      --add-flags "--windows-binaries-dir $out/share/me3/windows-bin" \
      --run '
        _me3_confdir="''${XDG_CONFIG_HOME:-$HOME/.config}/me3/profiles"
        if [ ! -d "$_me3_confdir" ]; then
          mkdir -p "$_me3_confdir"
          cp '"$out"'/share/me3/profiles/*.me3 "$_me3_confdir/"
          for game in eldenring-mods nightreign-mods sekiro-mods; do
            mkdir -p "$_me3_confdir/$game"
          done
        fi
      '

    runHook postInstall
  '';

  meta = {
    description = "A framework for modding and instrumenting FROMSOFTWARE games";
    homepage = "https://github.com/garyttierney/me3";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "me3";
  };
}
