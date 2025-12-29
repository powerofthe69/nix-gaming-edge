# nix-gaming-edge

After Chaotic-Nyx archived themselves in the middle of December 2025, I decided to step up and host my own flake for installing proton-cachyos into Steam, mostly for personal reasons. Since getting an itch for it, I've created a few flakes (one of my most important being the mesa-git module) and it's been getting a little unwieldy managing all the flakes in separate repositories. This repository is meant to rein it all in and allow me a single point of management. The existing repositories will be archived sometime soon, but their contents have already been migrated here.

**What all is included in this repo?**

The largest ones that most will probably want to use are:

- `proton-cachyos` (or its "optimized" variants): to install proton-cachyos into Steam and keep updated automatically

- `mesa-git`: a module to install the latest Mesa drivers compiled straight from the official Gitlab

Others that were mostly for me:

- `pokemmo`: this installs PokeMMO differently than the nixpkgs version, which piggybacked off of `pokemmo-installer`. This grabs the client directly from the official website, which I believe is more "nix"-esque since it's straight from the source.

- `pseudoregalia-rando`: this installs the latest release of the pseudoregalia randomizer mod. Niche.

- `vintagestory` or `vintagestory-stable`: this installs the latest release of Vintage Story regardless of whether it's stable or not. The nixpkgs version does not currently automatically update, and this will swap between the stable and unstable channels as necessary depending on the release. Those that don't want to use the unstable channel at all can install `vintagestory-stable` instead.

**NixOS Installation:**

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
        {
          nixpkgs.overlays = [ nix-gaming-edge.overlays.default ];
          drivers.mesa-git.enable = true;
          
          environment.systemPackages = with pkgs; [
            vintagestory
            pseudoregalia-rando
          ];
        
          programs.steam = {
            enable = true;
            extraCompatPackages = with pkgs; [
              proton-cachyos # proton-cachyos-x86_64-v2 proton-cachyos-x86_64-v3 proton-cachyos-x86_64-v4
            ];
          }
        }
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
