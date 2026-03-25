# Extracts amdxcffx64.dll (FSR4) from AMD Adrenalin Edition installers.

# To add a new Adrenalin version:
#   1. Download the installer from AMD
#   2. Compute the hash: nix hash file <installer.exe>
#   3. Find the FSR4 version string from upscalers.py's __get_fsr4_dlls()
#   4. Add an entry to the adrenalinSources list below

{ pkgs }:

let
  # Each entry maps an Adrenalin installer to the FSR4 DLL version it contains.
  # fsr4Version must match the version string in upscalers.py's __get_fsr4_dlls().
  adrenalinSources = [

    # AMD Adrenalin 25.3.1 — contains FSR 4.0.0
    {
      url = "https://drivers.amd.com/drivers/whql-amd-software-adrenalin-edition-25.3.1-win10-win11-march-rdna.exe";
      hash = "sha256-y/KwLsUZoiNbB/XBV+2SWE+6Iz6ltE0Ddq2917MWgWI=";
      name = "amd-adrenalin-25.3.1.exe";
      version = "25.3.1";
      fsr4Version = "4.0.0_67A4D2BC10ad000";
    }

    # AMD Adrenalin 25.4.1 — contains FSR 4.0.1
    {
      url = "https://drivers.amd.com/drivers/amd-software-adrenalin-edition-25.4.1-win10-win11-apr22-rdna.exe";
      hash = "sha256-y5b5BQIQBRwdb0xZD5U3LjVFbYUw3VIJrbY3ZbB6brM=";
      name = "amd-adrenalin-25.4.1.exe";
      version = "25.4.1";
      fsr4Version = "4.0.1_67D435F7d97000";
    }

    # AMD Adrenalin 25.9.1 — contains FSR 4.0.2
    {
      url = "https://drivers.amd.com/drivers/whql-amd-software-adrenalin-edition-25.9.1-win10-win11-sep-rdna.exe";
      hash = "sha256-4mtjP8cwiE79VnB0HYBBY07+r28K6AKgFzA4XHT++9M=";
      name = "amd-adrenalin-25.9.1.exe";
      version = "25.9.1";
      fsr4Version = "4.0.2_68840348eb8000";
    }

    # AMD Adrenalin 25.12.1 (Win11) — contains FSR 4.0.3
    {
      url = "https://drivers.amd.com/drivers/whql-amd-software-adrenalin-edition-25.12.1-win11-b.exe";
      hash = "sha256-xKJsWBoGwSorcJLu8i5ys60MDmARn3sVzlcVxRrtkiw=";
      name = "amd-adrenalin-25.12.1.exe";
      version = "25.12.1";
      fsr4Version = "4.0.3_6930960536b9000";
    }

    # AMD Adrenalin 26.3.1 (Win11) — contains FSR 4.1.0
    {
      url = "https://drivers.amd.com/drivers/whql-amd-software-adrenalin-edition-26.3.1-win11-b.exe";
      hash = "sha256-DSzWDGOQo5z3rQoQjFvMYQhBTBKMwzJDxaM3Z9kop84=";
      name = "amd-adrenalin-26.3.1.exe";
      version = "26.3.1";
      fsr4Version = "4.1.0_69A0952A304a000";
    }
  ];

  extractFsr4Dll =
    {
      url,
      hash,
      name,
      version,
      fsr4Version,
    }:
    pkgs.stdenv.mkDerivation {
      pname = "amdxcffx64";
      inherit version;

      src = pkgs.fetchurl {
        inherit url hash name;
        curlOptsList = [
          "--user-agent"
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
          "--referer"
          "https://www.amd.com/en/support/download/drivers.html"
        ];
      };

      nativeBuildInputs = [ pkgs.p7zip ];

      dontUnpack = true;

      buildPhase = ''
        runHook preBuild
        # 7z must decompress through the solid block, but only writes the matching file to disk
        7z x "$src" -o./extracted 'amdxcffx64.dll' -r -y
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        find ./extracted -name 'amdxcffx64.dll' -exec cp {} "$out/amdxcffx64_v${fsr4Version}.dll" \;
        test -f "$out/amdxcffx64_v${fsr4Version}.dll" || (echo "amdxcffx64.dll not found in archive" && exit 1)
        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "AMD FidelityFX Super Resolution 4 (FSR4) DLL v${fsr4Version}";
        homepage = "https://www.amd.com/en/products/software/adrenalin.html";
        license = licenses.unfree;
        platforms = [ "x86_64-linux" ];
      };
    };

in
map extractFsr4Dll adrenalinSources
