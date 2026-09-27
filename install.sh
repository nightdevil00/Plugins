#!/usr/bin/env bash
# Install one plugin from this collection.
#
#   ./install.sh better.displays
#   ./install.sh            (interactive picker)
#
# Each plugin has its own branch in this repository, named after its folder.
# That branch's root is the plugin, which is what omarchy-plugin-add requires:
# it clones a URL and reads manifest.json from the root of the clone.

set -euo pipefail

REPO_URL="https://github.com/nightdevil00/Plugins.git"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

usage() {
  echo "Usage: $0 <plugin-name>" >&2
  echo >&2
  echo "Available:" >&2
  git ls-remote --heads "$REPO_URL" 2>/dev/null |
    sed 's|.*refs/heads/||' | grep -v '^main$' | sort |
    sed 's|^|  |' >&2
  exit 1
}

name="${1:-}"
if [[ -z $name ]]; then
  echo "Available plugins:" >&2
  git ls-remote --heads "$REPO_URL" 2>/dev/null |
    sed 's|.*refs/heads/||' | grep -v '^main$' | sort |
    sed 's|^|  |' >&2
  read -r -p "Plugin to install: " name
  [[ -n $name ]] || { echo "cancelled" >&2; exit 1; }
fi

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
command -v git  >/dev/null || { echo "error: git is required" >&2; exit 1; }

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

echo "Cloning $name ..."
if ! git clone -q --depth 1 --branch "$name" "$REPO_URL" "$stage/plugin"; then
  echo "error: no branch named '$name' in $REPO_URL" >&2
  echo "run '$0' with no arguments to list what is available" >&2
  exit 1
fi

[[ -f "$stage/plugin/manifest.json" ]] || {
  echo "error: branch '$name' has no manifest.json at its root" >&2
  exit 1
}

id="$(jq -r '.id' "$stage/plugin/manifest.json")"
[[ -n $id && $id != "null" ]] || { echo "error: manifest has no id" >&2; exit 1; }
target="$PLUGINS_DIR/$id"

mkdir -p "$PLUGINS_DIR"
if [[ -e $target ]]; then
  echo "error: '$id' is already installed at $target" >&2
  echo "       remove it first, or reinstall manually:" >&2
  echo "         rm -rf '$target' && $0 $name" >&2
  exit 1
fi

mv "$stage/plugin" "$target"
echo "Installed $id -> $target"

if command -v omarchy-shell >/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  echo "Now enable it:  omarchy plugin enable $id"
else
  echo "omarchy-shell not found on PATH; skipped plugin rescan."
  echo "Start Omarchy, then run:  omarchy plugin enable $id"
fi
