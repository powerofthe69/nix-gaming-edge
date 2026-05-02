# A Nix user repository providing the 'essential' bleeding-edge packages like mesa-git and proton-cachyos alongside a collection of random, 'niche' gaming packages such as pokemmo, vintagestory (latest), and more to come.

**Before Building:**

Most packages here (mesa-git, eden, proton-cachyos, etc.) are pre-built and served from a binary cache. If you don't wire it up, your first build will compile everything from source. You can either pass it ad-hoc on a single rebuild:

```bash
sudo nixos-rebuild boot --flake .#<hostname> \
  --option substituters "https://nix-cache.tokidoki.dev/tokidoki" \
  --option trusted-public-keys "tokidoki:MD4VWt3kK8Fmz3jkiGoNRJIW31/QAm7l1Dcgz2Xa4hk="
```

Or, you can add it declaratively to your NixOS config so every rebuild uses it automatically (shown in the `nix.settings` block in the example below)

**Background:**

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
    
      - Default List: `[ "DerivedDataCache" "D3DSCache" "*ShaderCache" "GLCache" ]`
    
    - `protonCacheFiles` : for specifying a list of Proton cache files found within the games' installation directories ( under `steamapps/common` )
    
      - Default List: `[ "*.dxvk-cache" "*.vkd3d-proton.cache*" "vulkan_pso_cache*" "shader*.cache" ]`
    
  - `steamOrphanCleanup` : for purging folders that were left behind by Steam when uninstalling games ( checks against `libraryfolders.vdf` ) - defaults to `false`
  
    - `protectedFolders` : for declaring folders that should not be purged - this has sane defaults, but if you wish to keep specific game folders that may have mods within from being purged, then all should be declared
    
      - Default List: `[ "Steam Controller Configs" "Proton*" "SteamLinuxRuntime*" "Steamworks Shared" ]`

Other packages that were mostly for me:

- `discord` (and `vencord`): this installs stable Discord with a nightly build of Vencord injected. I started maintaining this myself after the 0.121 Discord update broke Vencord and the nixpkgs version lagged behind upstream's fix. Pulled directly from the official Discord tarball and the Vencord git repo.

- `eden` or `eden-emulator`: this installs the Eden emulator, an emulator forked from the popular Yuzu. This grabs the latest commits nightly and compiles them on my local server before backing up on my cache server, similar to mesa-git. Builds are not guaranteed to be stable, but should usually be functional and receive the latest performance improvements. This is not associated with the official project. Do not report issues to them.

- `fluxer-desktop`: this installs the Fluxer desktop client straight from the upstream git repo. Fluxer is an alternative chat service to Discord that can be self-hosted. I intend to use it over Discord when the refactor is complete.

- `hytale` or `hytale-launcher`: this installs the official Hytale launcher inside its own FHSenv. As of now, it's a static version of the launcher, because it self-updates

- `millennium-steam`: this exposes the Millennium plugin/theming framework for Steam. It's just re-exported from the official Millennium flake so I have a single point of installation alongside everything else here.

- `modengine3` or `me3`: this installs me3, a framework for modding and instrumenting FROMSOFTWARE games (Elden Ring, Dark Souls, etc.). Tracks the upstream releases.

- `opengoal-launcher`: this installs the official OpenGOAL launcher (Jak and Daxter native port) inside its own FHSenv, since the launcher downloads arbitrary versions of the tooling.

- `pokemmo`: this installs PokeMMO differently than the nixpkgs version, which piggybacked off of `pokemmo-installer`. This grabs the client directly from the official website, which I believe is more "nix"-esque since it's straight from the source.

- `pseudoregalia-rando`: this installs the latest release of the pseudoregalia randomizer mod. Niche.

- `shipwright` and `_2ship2harkinian`: these expose the Ship of Harkinian (Ocarina of Time) and 2 Ship 2 Harkinian (Majora's Mask) PC ports. Re-exported straight from Nixpkgs so they're built and cached, since otherwise they'd be compiled from source on every nixpkgs bump.

- `vintagestory`: this installs the latest release of Vintage Story, even unstable release candidates. Those that don't want to use the unstable channel at all can use the official nixpkgs version instead.

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
          nix.settings = { # set the binary cache declaratively - optional
            substituters = [ "https://nix-cache.tokidoki.dev/tokidoki" ];
            trusted-public-keys = [ "tokidoki:MD4VWt3kK8Fmz3jkiGoNRJIW31/QAm7l1Dcgz2Xa4hk=" ];
          };

          nixpkgs.overlays = [
            nix-gaming-edge.overlays.default
            # nix-gaming-edge.overlays.mesa-git
            # nix-gaming-edge.overlays.proton-cachyos
            # nix-gaming-edge.overlays.vintagestory
            # etc.  
          ];
          
          drivers.mesa-git = {
            enable = true;
            cacheCleanup = { # protonPackage is null by default - thus Proton caches are not cleaned by default. Must define a protonPackage to clear Proton / engine caches
              enable = true;
              protonPackage = pkgs.proton-cachyos; # or variation
            
              mesaCacheDirs = [ # optional - default lists pre-configured
                "mesa_shader_cache*"
                "radv_builtin_shaders*"
                # etc.
              ];
              
              protonCacheFiles = [ # optional - default lists pre-configured
                "vkd3d-proton.cache*"
                "shader*.cache"
                # etc.
              ];
            
              protonCacheDirs = [ # optional - default lists pre-configured
                "*ShaderCache*"
                "D3DSCache*"
                # etc.
              ];
            };
            steamOrphanCleanup = {
              enable = true;
              protectedFolders = [ # folders to not treat as orphans for deletion ( optional, pre-configured with smart defaults )
                "Proton*"
                "Steam Controller Configs"
                # etc.
              ];
            };
          };
          
          environment.systemPackages = with pkgs; [ # or per-user equivalent
            (discord.override {
              withVencord = true; # latest Vencord build managed in here
            })
            eden
            fluxer-desktop
            hytale
            opengoal-launcher
            pokemmo
            pseudoregalia-rando
            shipwright
            _2ship2harkinian
            vintagestory
          ];
        
          hardware.steam-hardware.enable = true; # controller / Steam Deck input udev rules
          programs.steam = {
            # package = pkgs.millennium-steam
            enable = true;
            extraCompatPackages = with pkgs; [
              proton-cachyos
              # proton-cachyos-x86_64-v3
            ];
          };
        })
      ];
    };
  };
}
```

**Setting up modengine3 ( me3 ):**

`modengine3` needs two things to actually be usable from Steam: the `me3` binary has to live inside Steam's FHS sandbox so games can exec it, and me3 has to be able to find a Proton install to launch the game under. The latter is done by exposing a small `linkFarm` of compat tools and adding it to `STEAM_EXTRA_COMPAT_TOOLS_PATHS`.

Pull the compat-tools `linkFarm` out into a `let` binding so it stays readable, then override the Steam package to inject `me3` and point at it:

```nix
{ pkgs, lib, ... }:

let
  compatToolsDir = pkgs.linkFarm "me3-compat-tools" [
    {
      name = "proton-cachyos"; # me3 looks for the proton by this name
      path = pkgs.proton-cachyos.steamcompattool; # or whichever variant
    }
  ];
in
{
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [
      proton-cachyos
    ];
    package = pkgs.steam.override {
      extraPkgs = fpkgs: [ pkgs.modengine3 ];
      extraEnv = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = lib.concatStringsSep ":" [
          "${compatToolsDir}" # for ME3 / modengine3
          (lib.makeSearchPathOutput "steamcompattool" "" [ pkgs.proton-cachyos ])
        ];
      };
    };
  };
}
```
