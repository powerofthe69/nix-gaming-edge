#!/usr/bin/env bash
set -euo pipefail

# Checks which proton-cachyos variants exist in the latest GitHub release to update nvfetcher.toml
# Usage: ./scripts/sync-proton-variants.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NVFETCHER_TOML="$REPO_ROOT/nvfetcher.toml"
SOURCES_JSON="$REPO_ROOT/_sources/generated.json"
GH_REPO="CachyOS/proton-cachyos"

VARIANT_KEYS=( proton-cachyos proton-cachyos-x86_64-v2 proton-cachyos-x86_64-v3 proton-cachyos-x86_64-v4 )
declare -A VARIANT_SUFFIX=(
    [proton-cachyos]="x86_64"
    [proton-cachyos-x86_64-v2]="x86_64_v2"
    [proton-cachyos-x86_64-v3]="x86_64_v3"
    [proton-cachyos-x86_64-v4]="x86_64_v4"
)

echo "Fetching latest release from $GH_REPO..." >&2

CURL_ARGS=( -fsSL )
[[ -n "${GITHUB_TOKEN:-}" ]] && CURL_ARGS+=( -H "Authorization: token $GITHUB_TOKEN" )

RELEASE_JSON=$(curl "${CURL_ARGS[@]}" \
    "https://api.github.com/repos/$GH_REPO/releases/latest")

LATEST_TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')
mapfile -t ASSETS < <(echo "$RELEASE_JSON" | jq -r '.assets[].name')

echo "Latest release: $LATEST_TAG" >&2

cp "$NVFETCHER_TOML" "$NVFETCHER_TOML.new"

for key in "${VARIANT_KEYS[@]}"; do
    suffix="${VARIANT_SUFFIX[$key]}"

    found=false
    for asset in "${ASSETS[@]}"; do
        if [[ "$asset" =~ proton-.*-${suffix}\.tar\.xz$ ]]; then
            found=true
            break
        fi
    done

    if $found; then
        echo "  $key: found in $LATEST_TAG, tracking latest" >&2
        NEW_SRC="src.github = \"$GH_REPO\""
    else
        CURRENT_VER=$(jq -r --arg k "$key" '.[$k].version // empty' \
            "$SOURCES_JSON" 2>/dev/null || true)

        if [[ -n "$CURRENT_VER" ]]; then
            echo "  $key: NOT in $LATEST_TAG, pinning to $CURRENT_VER" >&2
            NEW_SRC="src.manual = \"$CURRENT_VER\""
        else
            echo "  $key: NOT in $LATEST_TAG and no prior version — skipping" >&2
            continue
        fi
    fi

    # Replace the src.* line immediately after this variant's [header]
    sed -i "/^\[$key\]$/{n;s|^src\..*|$NEW_SRC|}" "$NVFETCHER_TOML.new"
done

if diff -q "$NVFETCHER_TOML" "$NVFETCHER_TOML.new" >/dev/null 2>&1; then
    rm "$NVFETCHER_TOML.new"
    echo "Proton variants already up to date." >&2
else
    mv "$NVFETCHER_TOML.new" "$NVFETCHER_TOML"
    echo "Updated proton-cachyos entries in nvfetcher.toml" >&2
fi
