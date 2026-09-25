#!/usr/bin/env bash
# Install the plugins that init.lua loads with packadd().
#
# Plugins live in Neovim's package directory, which is outside this git repo,
# so a fresh clone of the config needs this script run once.
set -euo pipefail

PACK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/core/opt"

# name                     upstream                                ref
PLUGINS=(
  "nerdcommenter           https://github.com/preservim/nerdcommenter.git  a462bbda1e26f44fb3d3eb9d9d1c6a07aa98e665"
  "leap.nvim               https://codeberg.org/andyg/leap.nvim         32bde2e932417e8a065f039f00f0cebdd0da4710"
)

mkdir -p "$PACK_DIR"

for entry in "${PLUGINS[@]}"; do
  read -r name url ref <<<"$entry"
  dest="$PACK_DIR/$name"

  if [[ -d "$dest/.git" ]]; then
    echo "==> $name already installed, updating"
    git -C "$dest" fetch --quiet origin
  else
    echo "==> $name cloning from $url"
    git clone --quiet "$url" "$dest"
  fi

  git -C "$dest" checkout --quiet "$ref"
  echo "    $name at $(git -C "$dest" rev-parse --short HEAD)"
done

echo
echo "Done. Plugins are in $PACK_DIR"
