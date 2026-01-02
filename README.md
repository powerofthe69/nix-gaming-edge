# A Nix user repository providing the 'essential' bleeding-edge packages like mesa-git and proton-cachyos alongside a collection of random, 'niche' gaming packages such as pokemmo, vintagestory (latest), and more to come.

After Chaotic-Nyx archived themselves in the middle of December 2025, I decided to step up and host my own flake for installing proton-cachyos into Steam, mostly for personal reasons. Since getting an itch for it, I've created a few flakes (one of my most important being the mesa-git module) and it's been getting a little unwieldy managing all the flakes in separate repositories. This repository is meant to rein it all in and allow me a single point of management. The existing repositories will be archived sometime soon, but their contents have already been migrated here.

**What all is included in this repo?**

The largest ones that most will probably want to use are:

- `proton-cachyos` (or its "optimized" variants): to install proton-cachyos into Steam and keep updated automatically

- `mesa-git`: a module to install the latest Mesa drivers compiled straight from the official Gitlab. Optional flags include:

  - `cacheCleanup` : for automatically purging previous Mesa shader cache on version updates - defaults to `false`
  
    - `protonPackage` : for specifying a Proton package to track for cacheCleanup to clear old proton caches on updates - defaults to `null`
    
    - `mesaCacheDirs` : for specifying a list of Mesa shader cache directories ( under `~/.cache` ) to purge on version updates
    
      - Default List: `[ "mesa_shader_cache*" "radv_builtin_shaders*" "vulkan" "*GPUCache" ]`
    
    - `protonCacheDirs` : for specifying a list of shader cache directories that might be found within Proton's prefixes ( under `steamapps/compatdata` )
    
      - Default List: `[ "UnityShaderCache" "DerivedDataCache" "D3DSCache" "ShaderCache" "GLCache" ]`
    
    - `protonCacheFiles` : for specifying a list of Proton cache files found within the games' installation directories ( under `steamapps/common` )
    
      - Default List: `[ "*.dxvk-cache" "*.vkd3d-proton.cache*" "vulkan_pso_cache*" "shader*.cache" ]`
    
  - `steamOrphanCleanup` : for purging folders that were left behind by Steam when uninstalling games ( checks against `libraryfolders.vdf` ) - defaults to `false`
  
    - `protectedFolders` : for declaring folders that should not be purged - this has sane defaults, but if you wish to keep specific game folders that may have mods within from being purged, then all should be declared
    
      - Default List: `[ "Steam Controller Configs" "Proton*" "SteamLinuxRuntime*" "Steamworks Shared" ]`

Other packages that were mostly for me:

- `pokemmo`: this installs PokeMMO differently than the nixpkgs version, which piggybacked off of `pokemmo-installer`. This grabs the client directly from the official website, which I believe is more "nix"-esque since it's straight from the source.

- `pseudoregalia-rando`: this installs the latest release of the pseudoregalia randomizer mod. Niche.

- `vintagestory` or `vintagestory-stable`: this installs the latest release of Vintage Story regardless of whether it's stable or not. The nixpkgs version does not currently automatically update, and this will swap between the stable and unstable channels as necessary depending on the release. Those that don't want to use the unstable channel at all can install `vintagestory-stable` instead.

**NixOS Installation:**

proton-cachyos is **only** intended to be installed using the `extraCompatPackages` option for the Steam program, similar to the proton-ge-bin package from the official Nixpkgs repository. I have not tested this otherwise. If anyone tries it and manages to get it working, please let me know or submit a PR with instructions or changes to facilitate it.

Each provided package or package set (if multiple variations) has its own overlay if someone prefers, for example, the Nixpkgs maintained versions of PokeMMO or Vintage Story and does not wish to replace them. These overlays follow a common declaration scheme:

- nix-gaming-edge.overlays.mesa-git
- nix-gaming-edge.overlays.proton-cachyos
- etc.

mesa-git can be activated using either the mesa-git module or the default module (they are the same for now). These are declared as either:

- nix-gaming-edge.nixosModules.default
- nix-gaming-edge.nixosModules.mesa-git

Here is a minimal representation of what your configuration might look like:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-gaming-edge = {
      url = "github:powerofthe69/nix-gaming-edge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-gaming-edge, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nix-gaming-edge.nixosModules.default
        # nix-gaming-edge.nixosModules.mesa-git
        ({ pkgs, ... }: { # destructure module args by 'importing' pkgs - only needed when defining a protonPackage
          nixpkgs.overlays = [
            nix-gaming-edge.overlays.default
            #nix-gaming-edge.overlays.mesa-git
            #nix-gaming-edge.overlays.proton-cachyos
            #nix-gaming-edge.overlays.vintagestory
            #etc.  
          ];
          
          drivers.mesa-git = {
            enable = true;
            cacheCleanup = { # protonPackage is null by default - thus Proton caches are not cleaned by default. Must define a protonPackage to clear Proton / engine caches
              enable = true;
              protonPackage = pkgs.proton-cachyos; # or variation
            
              mesaCacheDirs = [ # optional - default lists pre-configured
                "mesa_shader_cache*"
                "radv_builtin_shaders*"
                #etc.
              ];
              
              protonCacheFiles = [ # optional - default lists pre-configured
                "vkd3d-proton.cache*"
                "shader*.cache"
                #etc.
              ];
            
              protonCacheDirs = [ # optional - default lists pre-configured
                "*ShaderCache*"
                "D3DSCache*"
                #etc.
              ];
            };
            steamOrphanCleanup = {
              enable = true;
              protectedFolders = [ # folders to not treat as orphans for deletion ( optional, pre-configured with smart defaults )
                "Proton*"
                "Steam Controller Configs"
                #etc.
              ];
            };
          };
          
          environment.systemPackages = with pkgs; [ # or per-user equivalent
            pokemmo
            vintagestory
            pseudoregalia-rando
          ];
        
          programs.steam = {
            enable = true;
            extraCompatPackages = with pkgs; [
              proton-cachyos
              # proton-cachyos-x86_64-v2
              # proton-cachyos-x86_64-v3
              # proton-cachyos-x86_64-v4
            ];
          };
        })
      ];
    };
  };
}
```

To use the cache on your first build (and subsequent rebuilds), you can use the `--option` flag with `nixos-rebuild`:

```bash
sudo nixos-rebuild boot --flake .#<hostname> \
--option substituters "https://nix-cache.tokidoki.dev/tokidoki" \
--option trusted-public-keys "tokidoki:MD4VWt3kK8Fmz3jkiGoNRJIW31/QAm7l1Dcgz2Xa4hk="
```

If you don't configure the cache, then the build will compile from source on your first build. However, subsequent builds will use the cache, as the cache is configured to be used by default.
