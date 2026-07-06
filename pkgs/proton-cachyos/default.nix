{
  pkgs,
  renameInternalName ? true,
  source,
  variant,
}:

let
  # Used to set folder name of tool
  folderName = if variant == "base" then "proton-cachyos" else "proton-cachyos-${variant}";
  # Used to set display name of tool in Steam
  steamName = if variant == "base" then "Proton CachyOS" else "Proton CachyOS ${variant}";

  # FSR4 DLLs extracted from AMD Adrenalin installers (managed in fsr4-dll.nix)
  fsr4Dlls = import ./fsr4-dll.nix { inherit pkgs; };

in
pkgs.stdenv.mkDerivation {
  pname = folderName;
  version = pkgs.lib.removePrefix "cachyos-" source.version;

  inherit (source) src;

  nativeBuildInputs = [ pkgs.xz ];
  outputs = [
    "out"
    "steamcompattool"
  ];

  # dead symlinks in upstream, ignore them
  dontCheckForBrokenSymlinks = true;

  installPhase = ''
    runHook preInstall

    # Create the steamcompat directory
    mkdir -p $steamcompattool
    cp -r ./* $steamcompattool/

    # Modify the display name
    sed -i -r "s|\"display_name\".*|\"display_name\" \"${steamName}\"|" \
      $steamcompattool/compatibilitytool.vdf

    ${pkgs.lib.optionalString renameInternalName ''
      sed -i -r 's|"proton-cachyos-[^"]*"(\s*// Internal name)|"${steamName}"\1|' $steamcompattool/compatibilitytool.vdf
    ''}

    # Seed store: FSR4 DLLs extracted from AMD Adrenalin installers
    mkdir -p $steamcompattool/fsr4-cache
    ${pkgs.lib.concatMapStringsSep "\n" (dll: ''
      cp ${dll}/*.dll $steamcompattool/fsr4-cache/
    '') fsr4Dlls}

    # Create a real folder so that Steam doesn't require reselecting compatibility tool on update
    mkdir -p $out/share/

    # Create a real folder so that Steam doesn't require reselecting compatibility tool on update
    mkdir -p $out/share/steam/compatibilitytools.d/${folderName}

    #Symlink the files INSIDE, not the folder itself. Oopsie
    ln -s $steamcompattool/* $out/share/steam/compatibilitytools.d/${folderName}/

    runHook postInstall
  '';

  # Wrap the proton entry point so the store's FSR4 DLLs are seeded (copy-if-missing)
  # into the user's protonfixes cache before the real proton runs
  postFixup = ''
    mv $steamcompattool/proton $steamcompattool/proton.real
    cat > $steamcompattool/proton <<'WRAPPER'
    #!/usr/bin/env bash
    # seed AMD FSR4 DLLs into the protonfixes upscaler cache
    # (copy-if-missing, so user overrides are preserved), then hand off to real proton.
    here="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"
    seed="$here/fsr4-cache"
    if [ -d "$seed" ]; then
    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/protonfixes/upscalers"
    mkdir -p "$cache" 2>/dev/null || true
    for dll in "$seed"/*.dll; do
    [ -e "$dll" ] || continue
    dest="$cache/$(basename -- "$dll")"
    [ -e "$dest" ] && continue
    # Copy read-only store DLL, then make it user-writable so it can be overwritten
    # like a vanilla proton-cachyos download (which lands as 0644).
    cp -- "$dll" "$dest" 2>/dev/null && chmod u+w "$dest" 2>/dev/null || true
    done
    fi
    exec "$here/proton.real" "$@"
    WRAPPER
    chmod +x $steamcompattool/proton
  '';

  meta = with pkgs.lib; {
    description = "${steamName}";
    homepage = "https://github.com/CachyOS/proton-cachyos";
    license = licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
