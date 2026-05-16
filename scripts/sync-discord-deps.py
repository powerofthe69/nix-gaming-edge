#!/usr/bin/env python3
"""Refresh pkgs/discord/sources.json from Discord's distributions API.

The output mirrors the source-attrset shape that nixpkgs' pkgs.discord
consumes (linux-stable variant only), forcing kind="distro" so the override
hits the new code path even against older locked nixpkgs.
"""

import base64
import json
import pathlib
import urllib.request

MANIFEST_URL = "https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=linux&arch=x64"
OUT_FILE = pathlib.Path(__file__).resolve().parent.parent / "pkgs/discord/sources.json"


def sri(hex_hash: str) -> str:
    return "sha256-" + base64.b64encode(bytes.fromhex(hex_hash)).decode()


req = urllib.request.Request(MANIFEST_URL, headers={"User-Agent": "Discord-Updater/1"})
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

OUT_FILE.write_text(json.dumps(source, indent=2) + "\n")
print(f"Updated {OUT_FILE} -> Discord {source['version']}")
