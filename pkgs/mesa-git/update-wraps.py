#!/usr/bin/env python3
# Adapted from nixpkgs pkgs/development/libraries/mesa/update-wraps.py.
# Regenerates wraps.json (crates.io meson wraps) from mesa source.
import base64
import binascii
import configparser
import json
import pathlib
import sys
import urllib.parse


def to_sri(hash: str):
    raw = binascii.unhexlify(hash)
    b64 = base64.b64encode(raw).decode()
    return f"sha256-{b64}"


def main(dir: str):
    result = []
    for file in sorted((pathlib.Path(dir) / "subprojects").glob("*.wrap")):
        parser = configparser.ConfigParser()
        _ = parser.read(file)
        if "wrap-file" not in parser.sections():
            continue

        url = parser.get("wrap-file", "source_url")
        if "crates.io" not in url:
            continue

        path = [p for p in urllib.parse.urlparse(url).path.split("/") if p]
        result.append({
            "pname": path[-3],
            "version": path[-2],
            "hash": to_sri(parser.get("wrap-file", "source_hash")),
        })

    here = pathlib.Path(__file__).parent
    with (here / "wraps.json").open("w") as fd:
        json.dump(result, fd, indent=4)
        _ = fd.write("\n")


if __name__ == "__main__":
    main(*sys.argv[1:])
