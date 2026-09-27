#!/usr/bin/env bash
# Install plugins from this collection.
#
#   ./install.sh                  pick one interactively
#   ./install.sh better.displays  install one
#   ./install.sh --all            install every plugin
#   ./install.sh --all --enable   install every plugin and enable it
#   ./install.sh --update better.displays   replace an installed plugin
#   ./install.sh --all --update   re-copy every plugin
#
# Plugins live as subdirectories of this repository. Each one is copied into
# ~/.config/omarchy/plugins/<id>, which is the layout omarchy expects and the
# same one 'omarchy plugin add' produces.

set -euo pipefail

REPO_URL="https://github.com/nightdevil00/Plugins.git"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

all=false
enable=false
update=false
section=""
name=""

for arg in "$@"; do
  case "$arg" in
    --all|-all|-a) all=true ;;
    --enable|-e)   enable=true ;;
    --update|-u)   update=true ;;
    --section)     shift; section="${1:-}" ;;
    -h|--help)     sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)            echo "unknown option: $arg" >&2; exit 1 ;;
    *)             [[ -z $name ]] || { echo "unexpected argument: $arg" >&2; exit 1; }
                   name="$arg" ;;
  esac
done

command -v git >/dev/null || { echo "error: git is required" >&2; exit 1; }

# Names of the plugin subdirectories, read straight from the remote's main
# branch so this works before anyone has cloned the repo.
list_available() {
  local tmp
  tmp="$(mktemp -d)"
  git clone -q --depth 1 --filter=blob:none --no-checkout "$REPO_URL" "$tmp" 2>/dev/null || {
    rm -rf "$tmp"; return 1
  }
  git -C "$tmp" ls-tree -d --name-only HEAD |
    grep -v '^\.' | grep . | sort
  rm -rf "$tmp"
}

# install_one <name> -> echoes the plugin id on success
install_one() {
  local branch="$1" tmp id target action="added"
  tmp="$(mktemp -d)"

  if ! git clone -q --depth 1 --filter=blob:none --sparse "$REPO_URL" "$tmp/repo" 2>/dev/null; then
    echo "  FAIL    could not clone $REPO_URL" >&2
    rm -rf "$tmp"; return 1
  fi
  git -C "$tmp/repo" sparse-checkout set --no-cone "$branch" >/dev/null 2>&1 || {
    echo "  FAIL    no plugin named '$branch'" >&2
    rm -rf "$tmp"; return 1
  }
  git -C "$tmp/repo" checkout -q 2>/dev/null

  local src="$tmp/repo/$branch"
  if [[ ! -d $src ]]; then
    echo "  FAIL    no plugin named '$branch'" >&2
    rm -rf "$tmp"; return 1
  fi
  if [[ ! -f "$src/manifest.json" ]]; then
    echo "  FAIL    $branch has no manifest.json" >&2
    rm -rf "$tmp"; return 1
  fi

  id="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$src/manifest.json" | head -1)"
  if [[ -z $id ]]; then
    echo "  FAIL    $branch has no id in its manifest" >&2
    rm -rf "$tmp"; return 1
  fi
  target="$PLUGINS_DIR/$id"

  if [[ -e $target || -L $target ]]; then
    if ! $update; then
      echo "  skip    $branch (already installed as $id)" >&2
      rm -rf "$tmp"; return 0
    fi
    rm -rf "${target}.old.$$"
    mv "$target" "${target}.old.$$"
    action="updated"
  fi

  mkdir -p "$PLUGINS_DIR"
  cp -a "$src" "$target"
  rm -rf "$tmp" "${target}.old."* 2>/dev/null || true
  printf '  %-8s %s -> %s\n' "$action" "$branch" "$id" >&2
  printf '%s\n' "$id"
}

rescan() {
  command -v omarchy-shell >/dev/null || return 1
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  return 0
}

installed_ids=()
failures=0

if $all; then
  mapfile -t names < <(list_available)
  [[ ${#names[@]} -gt 0 ]] || { echo "error: could not list plugins from $REPO_URL" >&2; exit 1; }
  echo "Installing ${#names[@]} plugins into $PLUGINS_DIR"
  echo
  for n in "${names[@]}"; do
    if id="$(install_one "$n")"; then
      [[ -n $id ]] && installed_ids+=("$id")
    else
      failures=$((failures+1))
    fi
  done
  echo
  rescan || echo "note: omarchy-shell not on PATH, skipped plugin rescan." >&2
  if [[ ${#installed_ids[@]} -gt 0 ]] && $enable; then
    echo "Enabling ${#installed_ids[@]} plugins..."
    for id in "${installed_ids[@]}"; do
      if omarchy plugin enable "$id" --section "${section:-right}" >/dev/null 2>&1; then
        echo "  enabled $id"
      else
        echo "  FAILED  $id" >&2
      fi
    done
  elif [[ ${#installed_ids[@]} -gt 0 ]]; then
    echo "Enable them with:"
    for id in "${installed_ids[@]}"; do echo "  omarchy plugin enable $id"; done
  else
    echo "Nothing to do."
  fi
  [[ $failures -eq 0 ]] || echo "$failures plugin(s) failed." >&2
  exit 0
fi

if [[ -z $name ]]; then
  echo "Available plugins:" >&2
  list_available | sed 's|^|  |' >&2
  read -r -p "Plugin to install: " name
  [[ -n $name ]] || { echo "cancelled" >&2; exit 1; }
fi

if ! id="$(install_one "$name")"; then
  echo "run '$0' with no arguments to list what is available" >&2
  exit 1
fi
[[ -n $id ]] || exit 0

if rescan; then
  if $enable; then
    omarchy plugin enable "$id" --section "${section:-right}" || echo "  (enable failed for $id)" >&2
  else
    echo "Now enable it:  omarchy plugin enable $id"
  fi
else
  echo "omarchy-shell not found on PATH; skipped plugin rescan." >&2
  echo "Start Omarchy, then run:  omarchy plugin enable $id"
fi
