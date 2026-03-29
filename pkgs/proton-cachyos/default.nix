{
  baseSource,
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

    # Pre-cache FSR4 DLLs extracted from AMD Adrenalin installers
    mkdir -p $steamcompattool/fsr4-cache
    ${pkgs.lib.concatMapStringsSep "\n" (dll: ''
      cp ${dll}/*.dll $steamcompattool/fsr4-cache/
    '') fsr4Dlls}

    # Extract upscalers.py from the base proton-cachyos source and patch it to replace in all versions
    tar -xf ${baseSource.src} --wildcards '*/protonfixes/upscalers.py' -O > $steamcompattool/protonfixes/upscalers.py

    substituteInPlace $steamcompattool/protonfixes/upscalers.py \
      --replace-fail \
        'def __dll_download_exists(url: str) -> bool:' \
        $'def __dll_download_exists(url: str) -> bool:\n    _nix_cache = Path(__file__).resolve().parent.parent / "fsr4-cache"\n    if _nix_cache.is_dir():\n        _url_id = Path(unquote(urlparse(url).path)).parent.name\n        if any(_url_id in _f.name for _f in _nix_cache.iterdir()):\n            log.info(f\x27Nix-cached DLL matches URL {url}\x27)\n            return True' \
      --replace-fail \
        "version = '4.0.3'" \
        'version = next(reversed(__fsr4_dlls))' \
      --replace-fail \
        'def __download_fsr4(file: dict, cache: Path, dst: Path) -> None:' \
        $'def __download_fsr4(file: dict, cache: Path, dst: Path) -> None:\n    _nix_cache = Path(__file__).resolve().parent.parent / "fsr4-cache"\n    if _nix_cache.is_dir():\n        _url_path = Path(unquote(urlparse(file["download_url"]).path))\n        _nix_cached = _nix_cache / (_url_path.stem + f\x27_v{file["version"]}\x27 + _url_path.suffix)\n        if _nix_cached.is_file():\n            dst.parent.mkdir(parents=True, exist_ok=True)\n            shutil.copy(_nix_cached, dst)\n            log.info(f\x27Using Nix-cached FSR4 DLL: {_nix_cached.name}\x27)\n            return'

    # Create a real folder so that Steam doesn't require reselecting compatibility tool on update
    mkdir -p $out/share/

    # Create a real folder so that Steam doesn't require reselecting compatibility tool on update
    mkdir -p $out/share/steam/compatibilitytools.d/${folderName}

    #Symlink the files INSIDE, not the folder itself. Oopsie
    ln -s $steamcompattool/* $out/share/steam/compatibilitytools.d/${folderName}/

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "${steamName}";
    homepage = "https://github.com/CachyOS/proton-cachyos";
    license = licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
