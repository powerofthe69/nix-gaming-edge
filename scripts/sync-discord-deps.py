#!/usr/bin/env python3
"""Refresh pkgs/discord/sources{,-darwin}.json from Discord's distributions API.

Each output mirrors the source-attrset shape that nixpkgs' pkgs.discord
consumes (stable branch only), forcing kind="distro" so the override hits
the new code path even against older locked nixpkgs. Linux tracks the x64
distro; darwin tracks the universal one (the API returns it for any arch).
"""

import base64
import json
import pathlib
import urllib.request

API = "https://updates.discord.com/distributions/app/manifests/latest?channel=stable"
PKG_DIR = pathlib.Path(__file__).resolve().parent.parent / "pkgs/discord"
TARGETS = {
    "sources.json": "platform=linux&arch=x64",
    "sources-darwin.json": "platform=osx&arch=universal",
}


def sri(hex_hash: str) -> str:
    return "sha256-" + base64.b64encode(bytes.fromhex(hex_hash)).decode()


for out_name, query in TARGETS.items():
    req = urllib.request.Request(f"{API}&{query}", headers={"User-Agent": "Discord-Updater/1"})
    with urllib.request.urlopen(req) as r:
        manifest = json.load(r)

    source = {
        "kind": "distro",
        "version": ".".join(str(x) for x in manifest["full"]["host_version"]),
        "distro": {
            "url": manifest["full"]["url"],
            "hash": sri(manifest["full"]["package_sha256"]),
        },
        "modules": {
            name: {
                "url": mod["full"]["url"],
                "hash": sri(mod["full"]["package_sha256"]),
                "version": mod["full"]["module_version"],
            }
            for name, mod in manifest["modules"].items()
        },
    }

    out_file = PKG_DIR / out_name
    out_file.write_text(json.dumps(source, indent=2, sort_keys=True) + "\n")
    print(f"Updated {out_file} -> Discord {source['version']}")
