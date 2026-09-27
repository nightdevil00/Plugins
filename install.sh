#!/usr/bin/env bash
# Install plugins from this collection.
#
#   ./install.sh                  pick one interactively
#   ./install.sh better.displays  install one
#   ./install.sh --all            install every plugin
#   ./install.sh --all --enable   install every plugin and enable it
#   ./install.sh --update better.displays   replace an installed plugin
#   ./install.sh --all --update   re-fetch every plugin from its branch
#
# NOTE: 'omarchy plugin update' does not work for these plugins. It runs
# 'git fetch origin HEAD', which resolves to main rather than the plugin's
# own branch, so the fast-forward fails. Use --update here instead.
#
# Each plugin has its own branch in this repository, named after its folder.
# That branch's root is the plugin, which is what omarchy-plugin-add requires:
# it clones a URL and reads manifest.json from the root of the clone.

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
    -h|--help)     sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)            echo "unknown option: $arg" >&2; exit 1 ;;
    *)             [[ -z $name ]] || { echo "unexpected argument: $arg" >&2; exit 1; }
                   name="$arg" ;;
  esac
done

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
command -v git >/dev/null || { echo "error: git is required" >&2; exit 1; }

list_available() {
  git ls-remote --heads "$REPO_URL" 2>/dev/null |
    sed 's|.*refs/heads/||' | grep -v '^main$' | sort
}

# install_one <branch> -> echoes the plugin id on success, nothing on skip/fail
install_one() {
  local branch="$1" stage id target
  stage="$(mktemp -d)"

  if ! git clone -q --depth 1 --branch "$branch" "$REPO_URL" "$stage/plugin" 2>/dev/null; then
    echo "  FAIL    $branch (no such branch)" >&2
    rm -rf "$stage"; return 1
  fi
  if [[ ! -f "$stage/plugin/manifest.json" ]]; then
    echo "  FAIL    $branch (no manifest.json at branch root)" >&2
    rm -rf "$stage"; return 1
  fi

  id="$(jq -r '.id // empty' "$stage/plugin/manifest.json")"
  if [[ -z $id ]]; then
    echo "  FAIL    $branch (manifest has no id)" >&2
    rm -rf "$stage"; return 1
  fi
  target="$PLUGINS_DIR/$id"
  local action="added"

  if [[ -e $target || -L $target ]]; then
    if ! $update; then
      echo "  skip    $branch (already installed as $id)" >&2
      rm -rf "$stage"; return 0
    fi
    # 'omarchy plugin update' cannot be used here: it fetches origin HEAD, which
    # is main, not this plugin's branch. Replace the checkout instead.
    rm -rf "${target}.old.$$"
    mv "$target" "${target}.old.$$"
    action="updated"
  fi

  mkdir -p "$PLUGINS_DIR"
  mv "$stage/plugin" "$target"
  rm -rf "$stage"
  rm -rf "${target}.old."* 2>/dev/null || true
  printf '  %-8s %s -> %s\n' "$action" "$branch" "$id" >&2
  printf '%s\n' "$id"
}

rescan() {
  if command -v omarchy-shell >/dev/null; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

installed_ids=()

if $all; then
  mapfile -t branches < <(list_available)
  [[ ${#branches[@]} -gt 0 ]] || { echo "error: could not list plugins from $REPO_URL" >&2; exit 1; }
  echo "Installing ${#branches[@]} plugins into $PLUGINS_DIR"
  echo
  for b in "${branches[@]}"; do
    if id="$(install_one "$b")"; then
      [[ -n $id ]] && installed_ids+=("$id")
    else
      failures=$((failures+1))
    fi
  done
  echo
  if ! rescan; then
    echo "note: omarchy-shell not on PATH, skipped plugin rescan."
  fi
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
    for id in "${installed_ids[@]}"; do
      echo "  omarchy plugin enable $id"
    done
  else
    echo "Nothing to do."
  fi
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

if [[ -z $id ]]; then
  exit 0
fi

if rescan; then
  if $enable; then
    omarchy plugin enable "$id" --section "${section:-right}" || echo "  (enable failed for $id)" >&2
  else
    echo "Now enable it:  omarchy plugin enable $id"
  fi
else
  echo "omarchy-shell not found on PATH; skipped plugin rescan."
  echo "Start Omarchy, then run:  omarchy plugin enable $id"
fi
