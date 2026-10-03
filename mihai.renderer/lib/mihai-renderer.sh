#!/bin/bash
# =============================================================================
# mihai-renderer.sh - which GPU renders this Omarchy desktop
# =============================================================================
# The whole chain lives in one script:
#
#   detection      sysfs + pci.ids only (no lspci, no jq, no root)
#   stable names   a /dev/dri/<vendor>-<igpu|dgpu> name per GPU, plus an
#                  optional udev rule file keyed on the PCI address (needs
#                  root; the script works fine without it)
#   your choice    one PCI address per line in the order file; the first one
#                  renders, the rest stay available for their monitors, and an
#                  empty file means "automatic" (Aquamarine decides)
#   generated Lua  a hook in the Omarchy Hyprland toggle directory that sets
#                  AQ_DRM_DEVICES before the compositor creates its backends
#   this session   the running order comes from Hyprland's own log
#
# Nothing here assumes a particular machine, a particular Hyprland config
# layout, or a particular home directory. Every path is derived from the
# environment and every one of them can be overridden (see OVERRIDES below) so
# the script can be exercised against fixtures.
#
# OVERRIDES (all optional)
#   MIHAI_RENDERER_SYSFS      default /sys
#   MIHAI_RENDERER_PCI_IDS    default /usr/share/hwdata/pci.ids, then
#                            /usr/share/misc/pci.ids
#   MIHAI_RENDERER_ORDER_FILE default $XDG_CONFIG_HOME/mihai.renderer/order
#   MIHAI_RENDERER_HOOK       default
#                            $XDG_STATE_HOME/omarchy/toggles/hypr/mihai-renderer-gpus.lua
#   MIHAI_RENDERER_UDEV_DIR   default /etc/udev/rules.d
#   MIHAI_RENDERER_RULES      default $MIHAI_RENDERER_UDEV_DIR/90-mihai-renderer-gpus.rules
#   MIHAI_RENDERER_HYPR_LOG   default this session's hyprland.log
#
# COMMANDS
#   status                 human readable summary
#   json                   everything the panel needs, as one JSON object
#   order <pci>...         save an explicit order and regenerate the hook
#   auto                   clear the saved order (automatic)
#   write                  regenerate the hook from the saved order
#   preset <igpu|dgpu|auto|only-igpu|only-dgpu>
#   hook                   print the hook the saved order would produce
#   links                  print the udev rules the current hardware needs
#   links-install          write them (re-execs through pkexec by itself)
#   links-remove           delete them (re-execs through pkexec by itself)
#
# Reading it: detect fills the GPU_* arrays, assign_links names the stable
# paths, hook_render prints the Lua, and everything else is a thin layer on
# top of those three.
# =============================================================================

set -uo pipefail

# --- paths -------------------------------------------------------------------

if [[ -z ${HOME:-} ]]; then
  # pkexec and sudo hand us a root HOME; prefer the invoking user's home.
  for owner in ${PKEXEC_UID:-} ${SUDO_UID:-}; do
    if [[ -n $owner ]]; then
      HOME="$(getent passwd "$owner" 2>/dev/null | cut -d: -f6)"
      break
    fi
  done
  HOME="${HOME:-$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)}"
fi

config_home() { printf '%s' "${XDG_CONFIG_HOME:-${HOME}/.config}"; }
state_home() { printf '%s' "${XDG_STATE_HOME:-${HOME}/.local/state}"; }

order_file() { printf '%s' "${MIHAI_RENDERER_ORDER_FILE:-$(config_home)/mihai.renderer/order}"; }
hook_file() { printf '%s' "${MIHAI_RENDERER_HOOK:-$(state_home)/omarchy/toggles/hypr/mihai-renderer-gpus.lua}"; }
udev_dir() { printf '%s' "${MIHAI_RENDERER_UDEV_DIR:-/etc/udev/rules.d}"; }
rules_file() { printf '%s' "${MIHAI_RENDERER_RULES:-$(udev_dir)/90-mihai-renderer-gpus.rules}"; }

sysfs_root() { printf '%s' "${MIHAI_RENDERER_SYSFS:-/sys}"; }

pci_ids_file() {
  if [[ -n ${MIHAI_RENDERER_PCI_IDS:-} ]]; then
    printf '%s' "$MIHAI_RENDERER_PCI_IDS"
    return
  fi
  local candidate
  for candidate in /usr/share/hwdata/pci.ids /usr/share/misc/pci.ids; do
    [[ -r $candidate ]] && {
      printf '%s' "$candidate"
      return
    }
  done
  printf '%s' /usr/share/hwdata/pci.ids
}

# --- detection ---------------------------------------------------------------
#
# Same variables as gpu_detect below, one entry per GPU:
#   GPU_PCI       0000:01:00.0 - the stable identity, the only thing stored
#   GPU_IDS       10de:1f95
#   GPU_VENDOR    intel | amd | nvidia | virtual | other
#   GPU_BRAND     Intel | AMD | NVIDIA | ...
#   GPU_NAME      GeForce GTX 1650 Ti Mobile (the bracketed pci.ids name)
#   GPU_CHIP      TU117M (what came before it)
#   GPU_KIND      integrated | dedicated | virtual
#   GPU_ARCH      NVIDIA generation: turing, ampere...   ("" otherwise)
#   GPU_FAMILY    NVIDIA driver branch that supports it: open | 580xx | none
#   GPU_DRIVER    kernel driver bound right now
#   GPU_DRV_FLAVOUR  open module | proprietary module | in-tree | ""
#   GPU_DRV_VERSION  what that driver calls itself: 610.57.04 for NVIDIA,
#                    "kernel <release>" for one that lives in the kernel tree
#   GPU_MODESET   1 when the compositor started a DRM backend for this GPU this
#                 session, 0 when it did not, "" when there is no log to say
#   GPU_BOOT_VGA  1 when the firmware used it at boot
#   GPU_CARD      card1 - renumbers between boots, so never stored
#   GPU_OUTPUTS   "eDP-1:connected DP-1:disconnected"
#   GPU_LINK      the stable /dev/dri name for this GPU ("" when virtual)
#   GPU_NODE      the /dev/dri path that exists right now ("" when absent)
# and:
#   GPU_COUNT, GPU_HYBRID (an integrated and a dedicated GPU),
#   GPU_INTERNAL (index of the GPU with a built-in panel, -1 when none)

# AMD APUs, by the codename pci.ids gives their GPU
GPU_AMD_APU_RE='^(Wrestler|Sumo|SuperSumo|Trinity|Richland|Kaveri|Godavari|Kabini|Kalindi|Mullins|Beema|Carrizo|Bristol|Stoney|Wani|Raven|Picasso|Dali|Pollock|Renoir|Lucienne|Cezanne|Barcelo|Rembrandt|Mendocino|VanGogh|Van Gogh|Sephiroth|Aerith|Phoenix|HawkPoint|Hawk Point|Raphael|Granite Ridge|Strix|Krackan)'

# A PCI address, strictly. Nothing else is ever written to the hook.
_is_pci() { [[ $1 =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; }

# A /dev/dri link basename, strictly. Same reason.
_is_link() { [[ $1 =~ ^[a-z0-9][a-z0-9-]*$ ]]; }

# The name pci.ids gives a PCI device, or nothing.
pci_name() {
  local ids
  ids="$(pci_ids_file)"
  [[ -r $ids ]] || return 0
  awk -v V="$1" -v D="$2" '
    index($0, V "  ") == 1 { v = 1; next }
    /^[0-9a-f][0-9a-f][0-9a-f][0-9a-f] / { if (v) exit; next }
    v && index($0, "\t" D "  ") == 1 { print substr($0, 8); exit }
  ' "$ids"
}

# NVIDIA generation from the chip code, then from device id ranges when
# pci.ids does not know the card.
nvidia_arch() {
  local chip=$1 id=$((16#$2))
  case "$chip" in
  GB*) echo blackwell ;;
  GH*) echo hopper ;;
  AD*) echo ada ;;
  GA*) echo ampere ;;
  TU*) echo turing ;;
  GV*) echo volta ;;
  GP*) echo pascal ;;
  GM*) echo maxwell ;;
  GK*) echo kepler ;;
  GF*) echo fermi ;;
  G[0-9]* | GT[0-9]* | NV* | MCP* | C[0-9]*) echo tesla ;;
  *)
    if ((id >= 0x2900)); then echo blackwell
    elif ((id >= 0x2600)); then echo ada
    elif ((id >= 0x2300 && id <= 0x233f)); then echo hopper
    elif ((id >= 0x2200 || (id >= 0x2080 && id <= 0x20ff))); then echo ampere
    elif ((id >= 0x1e00)); then echo turing
    elif ((id == 0x1d81 || (id >= 0x1db0 && id <= 0x1dbf))); then echo volta
    elif ((id >= 0x1b00 || (id >= 0x15f0 && id <= 0x15ff))); then echo pascal
    elif ((id >= 0x1340)); then echo maxwell
    elif ((id >= 0x0fc0)); then echo kepler
    else echo fermi
    fi
    ;;
  esac
}

# The NVIDIA driver branch that still supports a generation.
nvidia_family() {
  case "$1" in
  turing | ampere | ada | hopper | blackwell) echo open ;;
  maxwell | pascal | volta) echo 580xx ;;
  kepler) echo 470xx ;;
  *) echo none ;;
  esac
}

detect() {
  local sysfs dir rows=()
  sysfs="$(sysfs_root)"

  GPU_PCI=() GPU_IDS=() GPU_VENDOR=() GPU_BRAND=() GPU_NAME=() GPU_CHIP=()
  GPU_KIND=() GPU_ARCH=() GPU_FAMILY=() GPU_DRIVER=()
  GPU_DRV_FLAVOUR=() GPU_DRV_VERSION=() GPU_MODESET=() GPU_BOOT_VGA=()
  GPU_CARD=() GPU_OUTPUTS=() GPU_LINK=() GPU_NODE=()
  GPU_COUNT=0 GPU_HYBRID=0 GPU_INTERNAL=-1

  for dir in "$sysfs"/bus/pci/devices/*; do
    [[ -r $dir/class ]] || continue
    # 0x03xxxx: display controllers (VGA, 3D, other display)
    [[ "$(<"$dir/class")" == 0x03* ]] || continue

    local pci vendor device full chip name kind brand vtag arch="" family="" driver=""
    pci="$(basename "$dir")"
    vendor="$(<"$dir/vendor")"
    device="$(<"$dir/device")"
    vendor="${vendor#0x}"
    device="${device#0x}"
    full="$(pci_name "$vendor" "$device")"
    if [[ $full == *"["*"]"* ]]; then
      chip="${full%% \[*}"
      name="${full#*\[}"
      name="${name%\]*}"
    else
      chip=$full
      name=$full
    fi

    case "$vendor" in
    8086)
      vtag=intel
      brand=Intel
      kind=integrated
      # Arc cards are dedicated; Meteor Lake's integrated GPU is called Arc
      # too, hence matching on the device id rather than the name.
      local id=$((16#$device))
      if ((id >= 0x4905 && id <= 0x4909)) || ((id >= 0x5690 && id <= 0x56cf)) ||
        ((id >= 0xe200 && id <= 0xe2ff)); then
        kind=dedicated
      fi
      ;;
    1002)
      vtag=amd
      brand=AMD
      kind=dedicated
      if [[ $chip =~ $GPU_AMD_APU_RE ]]; then
        kind=integrated
      elif [[ -z $full && -r $dir/mem_info_vram_total ]]; then
        # Unknown to pci.ids: an APU reserves far less memory than a card.
        (($(<"$dir/mem_info_vram_total") <= 1073741824)) && kind=integrated
      fi
      ;;
    10de)
      vtag=nvidia
      brand=NVIDIA
      kind=dedicated
      arch="$(nvidia_arch "$chip" "$device")"
      family="$(nvidia_family "$arch")"
      ;;
    1af4 | 1b36 | 1234 | 15ad | 80ee)
      vtag=virtual
      brand=Virtual
      kind=virtual
      ;;
    *)
      vtag=other
      brand="PCI $vendor"
      kind=dedicated
      ;;
    esac
    [[ -n $name ]] || name="GPU $vendor:$device"
    [[ -L $dir/driver ]] && driver="$(basename "$(readlink "$dir/driver")")"

    local card="" outputs="" conn
    for conn in "$dir"/drm/card*; do
      [[ -d $conn ]] || continue
      card="$(basename "$conn")"
      break
    done
    if [[ -n $card ]]; then
      for conn in "$dir/drm/$card/$card"-*; do
        [[ -r $conn/status ]] || continue
        outputs+="${conn##*/"$card"-}:$(<"$conn/status") "
      done
    fi

    # Integrated first, virtual last: this is the order the panel lists them in.
    local rank=2
    [[ $kind == integrated ]] && rank=1
    [[ $kind == virtual ]] && rank=3
    # "|" never appears in any of these values
    rows+=("$rank $pci|$pci|$vendor:$device|$vtag|$brand|$name|$chip|$kind|$arch|$family|$driver|$(cat "$dir/boot_vga" 2>/dev/null || echo 0)|$card|${outputs% }")
  done

  local i=0 integrated=0 dedicated=0
  gpu_real_count=0
  while IFS='|' read -r _ GPU_PCI[i] GPU_IDS[i] GPU_VENDOR[i] GPU_BRAND[i] GPU_NAME[i] GPU_CHIP[i] \
    GPU_KIND[i] GPU_ARCH[i] GPU_FAMILY[i] GPU_DRIVER[i] GPU_BOOT_VGA[i] GPU_CARD[i] GPU_OUTPUTS[i]; do
    [[ ${GPU_KIND[i]} == integrated ]] && integrated=1
    [[ ${GPU_KIND[i]} == dedicated ]] && dedicated=1
    [[ ${GPU_KIND[i]} != virtual ]] && gpu_real_count=$((gpu_real_count + 1))
    i=$((i + 1))
  done < <(((${#rows[@]})) && printf '%s\n' "${rows[@]}" | sort)
  GPU_COUNT=$i

  # The built-in screen: a connected eDP/LVDS/DSI output, failing that any of
  # them (some boards list an eDP that is never plugged in).
  local pattern
  for pattern in ':connected' ':'; do
    for ((i = 0; i < GPU_COUNT; i++)); do
      if [[ " ${GPU_OUTPUTS[i]}" =~ \ (eDP|LVDS|DSI)-[^[:space:]:]*$pattern ]]; then
        GPU_INTERNAL=$i
        break 2
      fi
    done
  done
  ((integrated && dedicated)) && GPU_HYBRID=1

  assign_links
  assign_drivers
  return 0
}

# Stable /dev/dri names: vendor plus -igpu/-dgpu, with -2, -3 for a second GPU
# of the same kind. Virtual GPUs get none: they cannot render.
assign_links() {
  GPU_LINK=()
  GPU_NODE=()
  local i name n link card_path
  local -A used=()
  for ((i = 0; i < GPU_COUNT; i++)); do
    if [[ ${GPU_KIND[i]} == virtual ]]; then
      GPU_LINK[i]=""
      GPU_NODE[i]=""
      continue
    fi
    case "${GPU_VENDOR[i]}" in
    intel | amd | nvidia) name=${GPU_VENDOR[i]} ;;
    *) name=gpu ;;
    esac
    [[ ${GPU_KIND[i]} == integrated ]] && name+=-igpu || name+=-dgpu
    link=$name
    n=1
    while [[ -n ${used[$link]:-} ]]; do
      n=$((n + 1))
      link="$name-$n"
    done
    used[$link]=1
    GPU_LINK[i]=$link

    # What exists right now: the stable name when udev made it, the card node
    # otherwise. Both are only used for reporting; the hook resolves freshly.
    if [[ -e /dev/dri/$link ]]; then
      GPU_NODE[i]="/dev/dri/$link"
    elif [[ -n ${GPU_CARD[i]} && -e /dev/dri/${GPU_CARD[i]} ]]; then
      GPU_NODE[i]="/dev/dri/${GPU_CARD[i]}"
    else
      GPU_NODE[i]=""
    fi
    unset card_path
  done
}

# Driver facts, which is what actually decides whether a monitor lights up.
#
#   flavour   open module / proprietary module for NVIDIA, in-tree for a driver
#             that ships with the kernel, nothing at all when none is bound
#   version   the version that driver reports for itself. A driver inside the
#             kernel tree has none, so the kernel release is what it runs as.
#   modeset   whether the compositor opened a DRM backend on the card this
#             session. This is the one that matters when a screen is plugged in
#             and stays black: the kernel can see the connector and still have
#             no driver allowed to modeset it, and only the compositor's own log
#             records which cards it bothered with.
nvidia_module_flavour() {
  local raw
  [[ -r /proc/driver/nvidia/version ]] || return 0
  raw="$(<//proc/driver/nvidia/version)"
  if [[ $raw == *"Open Kernel Module"* ]]; then
    echo "open module"
  elif [[ $raw == *"Kernel Module"* ]]; then
    echo "proprietary module"
  fi
}

nvidia_module_version() {
  [[ -r /proc/driver/nvidia/version ]] || return 0
  grep -aoE '[0-9]+\.[0-9]+\.[0-9]+' /proc/driver/nvidia/version 2>/dev/null | head -1
}

# "<pci> <driver>" for every DRM backend the compositor started this session.
running_backends() {
  local log card drv dev sysfs
  log="$(hypr_log)"
  [[ -r $log ]] || return 0
  sysfs="$(sysfs_root)"
  while read -r card drv; do
    dev="$(readlink -e "$sysfs/class/drm/$card/device" 2>/dev/null)" || continue
    printf '%s %s\n' "${dev##*/}" "$drv"
  done < <(grep -aoE 'Starting backend for /dev/dri/card[0-9]+, with driver [a-z0-9_-]+' "$log" 2>/dev/null |
    sed -E 's|.*/(card[0-9]+), with driver ([a-z0-9_-]+).*|\1 \2|')
}

assign_drivers() {
  local i pci drv backend kernel backends=()
  GPU_DRV_FLAVOUR=()
  GPU_DRV_VERSION=()
  GPU_MODESET=()
  kernel="$(uname -r 2>/dev/null)"
  mapfile -t backends < <(running_backends)

  for ((i = 0; i < GPU_COUNT; i++)); do
    drv="${GPU_DRIVER[i]}"
    case "$drv" in
    nvidia | nvidia_modeset)
      GPU_DRV_FLAVOUR[i]="$(nvidia_module_flavour)"
      GPU_DRV_VERSION[i]="$(nvidia_module_version)"
      ;;
    nouveau | '')
      GPU_DRV_FLAVOUR[i]=""
      GPU_DRV_VERSION[i]=""
      ;;
    *)
      GPU_DRV_FLAVOUR[i]="in-tree"
      GPU_DRV_VERSION[i]="kernel $kernel"
      ;;
    esac

    # No log means no answer, which is not the same as "no backend".
    GPU_MODESET[i]=""
    if ((${#backends[@]})); then
      pci="${GPU_PCI[i]}"
      GPU_MODESET[i]=0
      for backend in "${backends[@]}"; do
        [[ $backend == "$pci "* ]] && {
          GPU_MODESET[i]=1
          break
        }
      done
    fi
  done
}

gpu_index_of_pci() {
  local i
  for ((i = 0; i < GPU_COUNT; i++)); do
    [[ ${GPU_PCI[i]} == "$1" ]] && {
      printf '%s' "$i"
      return 0
    }
  done
  return 1
}

# GPUs a human can pick from: everything with a stable name.
gpu_real() {
  local i
  for ((i = 0; i < GPU_COUNT; i++)); do
    [[ ${GPU_KIND[i]} != virtual ]] && printf '%s\n' "$i"
  done
}

# 2+ GPUs a person could pick from, as "1" or "0".
gpu_multi() {
  ((gpu_real_count >= 2)) && printf '1' || printf '0'
  return 0
}

# How many GPUs there are a person could actually pick.
gpu_real_count=0

gpu_connected() {
  local out list=()
  for out in ${GPU_OUTPUTS[$1]}; do
    [[ $out == *:connected ]] && list+=("${out%:*}")
  done
  printf '%s' "${list[*]}"
}

gpu_label() {
  local i=$1
  printf '%s' "${GPU_BRAND[i]} ${GPU_NAME[i]}"
}

# --- order -------------------------------------------------------------------
#
# One PCI address per line in the order file. The first renders, the rest stay
# available for whatever is plugged into them, and anything absent from the file
# is not used at all. An empty file (or no file) means automatic: Aquamarine
# picks, putting the GPU with the built-in screen first.

order_saved() {
  local file line
  file="$(order_file)"
  [[ -r $file ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    _is_pci "$line" && printf '%s\n' "$line"
  done <"$file"
}

order_write() {
  local file tmp
  file="$(order_file)"
  mkdir -p "$(dirname "$file")" || return 1
  tmp="$(mktemp "${file}.XXXXXX")" || return 1
  {
    printf '# Which GPU renders this desktop - written by the mihai.renderer plugin.\n'
    printf '# One PCI address per line; the first one renders, the rest stay in use\n'
    printf '# for the monitors plugged into them. Empty (or this file removed) means\n'
    printf '# automatic. A change is picked up at the next login.\n'
    # No addresses at all is a valid order: automatic.
    if (($#)); then printf '%s\n' "$@"; fi
  } >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  chmod 644 "$tmp" && mv "$tmp" "$file"
}

# preset <igpu|dgpu|auto|only-igpu|only-dgpu> -> PCI addresses on stdout
order_resolve_preset() {
  local spec=${1:-auto} i out=()
  case "$spec" in
  auto) return 0 ;;
  igpu | dgpu | only-igpu | only-dgpu)
    local first=integrated
    [[ $spec == *dgpu ]] && first=dedicated
    for ((i = 0; i < GPU_COUNT; i++)); do
      [[ ${GPU_KIND[i]} == "$first" && -n ${GPU_LINK[i]} ]] && out+=("${GPU_PCI[i]}")
    done
    if [[ $spec == only-* ]]; then
      ((${#out[@]})) && out=("${out[0]}")
    else
      for ((i = 0; i < GPU_COUNT; i++)); do
        [[ ${GPU_KIND[i]} != "$first" && -n ${GPU_LINK[i]} ]] && out+=("${GPU_PCI[i]}")
      done
    fi
    ;;
  *)
    printf 'mihai-renderer: unknown preset %s\n' "$spec" >&2
    return 1
    ;;
  esac
  ((${#out[@]})) || {
    printf 'mihai-renderer: no %s GPU on this machine\n' "$first" >&2
    return 1
  }
  printf '%s\n' "${out[@]}"
}

# Every real GPU, primary first, with the rest in detection order. What the
# order list in the panel shows when nothing has been saved yet.
order_default() {
  local i first=""
  for ((i = 0; i < GPU_COUNT; i++)); do
    [[ ${GPU_KIND[i]} != integrated ]] && continue
    [[ -n ${GPU_LINK[i]} ]] || continue
    printf '%s\n' "${GPU_PCI[i]}"
    first=1
  done
  for ((i = 0; i < GPU_COUNT; i++)); do
    [[ ${GPU_KIND[i]} == integrated ]] && continue
    [[ -n ${GPU_LINK[i]} ]] || continue
    printf '%s\n' "${GPU_PCI[i]}"
  done
  unset first
}

# --- the Hyprland hook -------------------------------------------------------
#
# Omarchy requires every *.lua in ~/.local/state/omarchy/toggles/hypr while it
# reads its config, which is the one hook point that needs no edit to anything
# the user owns. Hyprland reads this before it creates a DRM backend, so
# AQ_DRM_DEVICES lands in the compositor's environment in time for Aquamarine.
#
# The records are "<stable name> <pci address>" lines, both validated by
# _is_link/_is_pci before they ever get here. Each address is resolved at
# startup rather than baked in, because /dev/dri/cardN renumbers between boots
# and the stable name only exists once the optional udev rules are installed.

hook_content() {
  local pci i records=() label
  for pci in "$@"; do
    _is_pci "$pci" || continue
    i="$(gpu_index_of_pci "$pci")" || continue
    _is_link "${GPU_LINK[i]}" || continue
    records+=("/dev/dri/${GPU_LINK[i]} $pci")
  done
  label="${*:-automatic}"

  cat <<'HEADER'
-- Generated by the mihai.renderer Omarchy plugin - edits are overwritten.
HEADER
  printf -- '-- Order file: %s\n' "$(order_file)"
  cat <<'HEADER'
--
-- Sets AQ_DRM_DEVICES for Hyprland and its children before Aquamarine creates
-- a backend, which is why a change only shows up at the next login: the DRM
-- backends are made once per session. The first GPU listed renders, the rest
-- stay available for the monitors plugged into them, and a GPU left out is not
-- used at all (its monitors stay dark). With nothing listed below, no variable
-- is set and Aquamarine chooses for itself, GPU with the built-in screen first.
--
-- Each line is "<device name> <PCI address>". The address is what decides: the
-- device name is used when it exists (the optional udev rules make it), and
-- otherwise the card is looked up through sysfs, so renumbering between boots
-- does not matter. A GPU that is turned off in the firmware is skipped, and if
-- nothing is left the variable is not set at all - no variable beats a broken
-- one.
HEADER

  if ((${#records[@]})); then
    printf '\nlocal records = {\n'
    local record
    for record in "${records[@]}"; do
      printf '  "%s",\n' "$record"
    done
    printf '}\n'
    cat <<'RESOLVER'

local function read_lines(pipe)
  local lines = {}
  if not pipe then return lines end
  for line in (pipe:read("*a") or ""):gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end
  pipe:close()
  return lines
end

local devices = {}
local seen = {}
for _, device in ipairs(read_lines(io.popen([[
while read -r link pci; do
  [ -n "$link" ] || continue
  if [ -e "$link" ]; then
    printf '%s\n' "$link"
  else
    for node in /sys/bus/pci/devices/"$pci"/drm/card*; do
      if [ -e "$node" ]; then printf '/dev/dri/%s\n' "${node##*/}"; fi
      break
    done
  fi
done <<'MIHAI_RENDERER_EOF'
RESOLVER
    printf '%s\n' "${records[@]}"
    cat <<'RESOLVER'
MIHAI_RENDERER_EOF
]]))) do
  if not seen[device] then
    seen[device] = true
    devices[#devices + 1] = device
  end
end

if #devices > 0 then
  hl.env("AQ_DRM_DEVICES", table.concat(devices, ":"))
end
RESOLVER
  else
    cat <<'AUTOMATIC'

-- Automatic: nothing to set, Aquamarine picks the GPU with the built-in
-- screen first.
AUTOMATIC
  fi

  printf '\n_G.mihai_renderer_order = "%s"\n' "$label"
}

hook_render() { hook_content "$@"; }

# ok | missing | stale
hook_state() {
  local hook
  hook="$(hook_file)"
  [[ -f $hook ]] || {
    printf 'missing'
    return 1
  }
  if hook_render "$@" | cmp -s - "$hook"; then
    printf 'ok'
    return 0
  fi
  printf 'stale'
  return 1
}

# The hook is written with one rename so Hyprland, which reloads on every write
# under local/ and toggles/, can never read half of it.
hook_write() {
  local hook tmp
  hook="$(hook_file)"
  # Automatic means Aquamarine decides, which it already does when no variable
  # is set. Leaving an inert file behind would only be there to be explained,
  # so the automatic state has no file at all.
  if (($# == 0)); then
    rm -f "$hook"
    return 0
  fi
  mkdir -p "$(dirname "$hook")" || return 1
  tmp="$(mktemp "${hook}.XXXXXX")" || return 1
  hook_render "$@" >"$tmp" && chmod 644 "$tmp" && mv "$tmp" "$hook" || {
    rm -f "$tmp"
    return 1
  }
}

# --- udev rules --------------------------------------------------------------
#
# /dev/dri/cardN renumbers between boots, so a stable name is nice to have. It
# is keyed on the PCI address of the parent device rather than the card number,
# and it lives in a 90- file so udev's own by-path links already exist by the
# time it runs. Optional: the hook resolves addresses through sysfs on its own.

rules_content() {
  local i
  printf '# GPU links by PCI address, written by the mihai.renderer Omarchy plugin.\n'
  printf '# /dev/dri/card* numbers change between boots; these names do not.\n'
  for ((i = 0; i < GPU_COUNT; i++)); do
    [[ -n ${GPU_LINK[i]} ]] || continue
    printf '# %s\n' "$(gpu_label "$i")"
    printf 'KERNEL=="card*", KERNELS=="%s", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/%s"\n' \
      "${GPU_PCI[i]}" "${GPU_LINK[i]}"
  done
}

# other | missing | changed | ok
rules_state() {
  local file content
  file="$(rules_file)"
  content="$(rules_content)"
  [[ -f $file ]] || {
    printf 'missing'
    return 1
  }
  if [[ "$(cat "$file" 2>/dev/null)" == "$content" ]]; then
    printf 'ok'
    return 0
  fi
  printf 'changed'
  return 1
}

# Rules files other than ours whose every rule makes one of our links for the
# same GPU: leftovers from setting this up by hand, which then fight over the
# same symlink.
rules_duplicates() {
  local dir file line pci link i dup
  dir="$(udev_dir)"
  for file in "$dir"/*.rules; do
    [[ -f $file && $file != "$(rules_file)" ]] || continue
    dup=0
    while IFS= read -r line || [[ -n $line ]]; do
      [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
      # continuation lines (the wiki's example splits rules across lines)
      while [[ $line == *\\ ]] && IFS= read -r line; do
        line="${line%\\}$line"
      done
      pci=""
      link=""
      [[ $line =~ KERNELS==\"([^\"]+)\" ]] && pci=${BASH_REMATCH[1]}
      [[ $line =~ SYMLINK\+=\"dri/([^\"]+)\" ]] && link=${BASH_REMATCH[1]}
      if [[ -n $pci && -n $link ]] && i="$(gpu_index_of_pci "$pci")" &&
        [[ ${GPU_LINK[i]} == "$link" ]]; then
        dup=1
      else
        dup=0
        break
      fi
    done <"$file"
    ((dup)) && printf '%s\n' "$file"
  done
  return 0
}

# --- this session ------------------------------------------------------------
#
# The DRM backends are created once, when the compositor starts, and the log is
# the only place that records what it did. Those card numbers belong to this
# boot, so sysfs still maps them back to PCI addresses.

hypr_log() {
  local log="${MIHAI_RENDERER_HYPR_LOG:-}"
  if [[ -z $log && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    log="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/hyprland.log"
  fi
  printf '%s' "$log"
}

running_order() {
  local log card dev sysfs
  log="$(hypr_log)"
  [[ -r $log ]] || return 0
  sysfs="$(sysfs_root)"
  local -A seen=()
  while read -r card; do
    [[ -n ${seen[$card]:-} ]] && continue
    seen[$card]=1
    dev="$(readlink -e "$sysfs/class/drm/$card/device" 2>/dev/null)" || continue
    printf '%s\n' "${dev##*/}"
  done < <(grep -aoE 'drm: Starting backend for /dev/dri/card[0-9]+' "$log" 2>/dev/null |
    grep -oE 'card[0-9]+$')
}

# 1 when the running Hyprland got an explicit list (AQ_DRM_DEVICES).
running_explicit() {
  local log
  log="$(hypr_log)"
  if [[ -r $log ]] && grep -qa 'drm: Explicit device list' "$log"; then
    printf '1'
  else
    printf '0'
  fi
  return 0
}

# Anything else that sets AQ_DRM_DEVICES would win or lose depending on load
# order, which is the kind of thing worth saying out loud.
stray_setters() {
  local ch root file
  ch="$(config_home)"
  for root in "$ch/hypr" "$ch/uwsm/env.d" "$ch/environment.d"; do
    [[ -d $root ]] || continue
    while IFS= read -r file; do
      [[ $file == "$(hook_file)" ]] && continue
      printf '%s\n' "$file"
    done < <(grep -rlZ --include='*.lua' --include='*.sh' --include='*.conf' \
      --include='environment' 'AQ_DRM_DEVICES' "$root" 2>/dev/null | tr '\0' '\n')
  done
  for file in /etc/environment; do
    [[ -r $file ]] || continue
    grep -q 'AQ_DRM_DEVICES' "$file" 2>/dev/null && printf '%s\n' "$file"
  done
  return 0
}

# --- JSON --------------------------------------------------------------------

json_str() {
  local s=$1
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  # anything else below 0x20 has no business being in a name
  s="$(printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037')"
  printf '"%s"' "$s"
}

json_bool() { [[ $1 == 1 || $1 == true ]] && printf 'true' || printf 'false'; }

emit_json() {
  local i j out first
  local order=() running=() strays=() dups=()
  mapfile -t order < <(order_saved)
  mapfile -t running < <(running_order)
  mapfile -t strays < <(stray_setters)
  mapfile -t dups < <(rules_duplicates)

  printf '{'
  printf '"multi":%s,' "$(json_bool "$(gpu_multi)")"
  printf '"hybrid":%s,' "$(json_bool "$GPU_HYBRID")"
  printf '"internal":%d,' "$GPU_INTERNAL"
  printf '"auto":%s,' "$(json_bool "$((${#order[@]} == 0))")"

  printf '"paths":{"order":%s,"hook":%s,"rules":%s},' \
    "$(json_str "$(order_file)")" "$(json_str "$(hook_file)")" "$(json_str "$(rules_file)")"
  printf '"log":%s,' "$(json_str "$(hypr_log)")"

  printf '"order":['
  for ((j = 0; j < ${#order[@]}; j++)); do
    ((j)) && printf ','
    json_str "${order[j]}"
  done
  printf '],'

  printf '"default":['
  mapfile -t default_order < <(order_default)
  for ((j = 0; j < ${#default_order[@]}; j++)); do
    ((j)) && printf ','
    json_str "${default_order[j]}"
  done
  printf '],'

  printf '"running":['
  for ((j = 0; j < ${#running[@]}; j++)); do
    ((j)) && printf ','
    json_str "${running[j]}"
  done
  printf '],'
  printf '"runningExplicit":%s,' "$(json_bool "$(running_explicit)")"

  printf '"hook":%s,' "$(json_str "$(hook_state "${order[@]}")")"
  printf '"rules":%s,' "$(json_str "$(rules_state)")"

  printf '"duplicates":['
  for ((j = 0; j < ${#dups[@]}; j++)); do
    ((j)) && printf ','
    json_str "${dups[j]}"
  done
  printf '],'

  printf '"stray":['
  for ((j = 0; j < ${#strays[@]}; j++)); do
    ((j)) && printf ','
    json_str "${strays[j]}"
  done
  printf '],'

  printf '"gpus":['
  for ((i = 0; i < GPU_COUNT; i++)); do
    ((i)) && printf ','
    printf '{"pci":%s,"ids":%s,"vendor":%s,"brand":%s,"name":%s,"chip":%s,' \
      "$(json_str "${GPU_PCI[i]}")" "$(json_str "${GPU_IDS[i]}")" \
      "$(json_str "${GPU_VENDOR[i]}")" "$(json_str "${GPU_BRAND[i]}")" \
      "$(json_str "${GPU_NAME[i]}")" "$(json_str "${GPU_CHIP[i]}")"
    printf '"kind":%s,"arch":%s,"family":%s,' \
      "$(json_str "${GPU_KIND[i]}")" "$(json_str "${GPU_ARCH[i]}")" \
      "$(json_str "${GPU_FAMILY[i]}")"
    printf '"driver":%s,"driverFlavour":%s,"driverVersion":%s,' \
      "$(json_str "${GPU_DRIVER[i]}")" "$(json_str "${GPU_DRV_FLAVOUR[i]}")" \
      "$(json_str "${GPU_DRV_VERSION[i]}")"
    if [[ -n ${GPU_MODESET[i]} ]]; then
      printf '"modeset":%s,' "$(json_bool "${GPU_MODESET[i]}")"
    else
      printf '"modeset":null,'
    fi
    printf '"bootVga":%s,"card":%s,"link":%s,"device":%s,' \
      "$(json_bool "${GPU_BOOT_VGA[i]}")" \
      "$(json_str "${GPU_CARD[i]}")" "$(json_str "${GPU_LINK[i]}")" \
      "$(json_str "${GPU_NODE[i]}")"
    printf '"connected":%s,' "$(json_str "$(gpu_connected "$i")")"
    printf '"outputs":['
    first=1
    for out in ${GPU_OUTPUTS[i]}; do
      ((first)) || printf ','
      first=0
      printf '{"name":%s,"connected":%s}' "$(json_str "${out%:*}")" \
        "$(json_bool "$([[ $out == *:connected ]] && echo 1)")"
    done
    printf ']}'
  done
  printf ']}'
  printf '\n'
}

# --- commands ----------------------------------------------------------------

cmd_status() {
  local i
  printf 'Graphics: '
  if ((GPU_COUNT == 0)); then
    printf 'no display controller found in sysfs\n'
    return 0
  fi
  if [[ $(gpu_multi) == 1 ]]; then
    printf '%d GPUs' "$gpu_real_count"
    ((GPU_HYBRID)) && printf ' (hybrid'
    if ((GPU_INTERNAL >= 0)); then
      printf ', built-in screen on the %s GPU' "${GPU_BRAND[GPU_INTERNAL]}"
    fi
    ((GPU_HYBRID)) && printf ')'
  else
    printf 'one GPU'
  fi
  printf '\n'

  for ((i = 0; i < GPU_COUNT; i++)); do
    printf '  %-7s %s\n' "${GPU_BRAND[i]}" "${GPU_NAME[i]}"
    printf '     driver %s' "${GPU_DRIVER[i]:-none bound}"
    [[ -n ${GPU_DRV_FLAVOUR[i]} ]] && printf ' (%s)' "${GPU_DRV_FLAVOUR[i]}"
    [[ -n ${GPU_DRV_VERSION[i]} ]] && printf ' %s' "${GPU_DRV_VERSION[i]}"
    case "${GPU_MODESET[i]}" in
    1) printf ' · modeset by the compositor' ;;
    0) printf ' · no backend this session' ;;
    esac
    printf '\n'
    if [[ -z ${GPU_LINK[i]} ]]; then
      printf '     no stable name, cannot be picked\n'
    else
      printf '     name %s' "/dev/dri/${GPU_LINK[i]}"
      [[ -n ${GPU_NODE[i]} ]] && printf ' (present: %s)' "${GPU_NODE[i]}"
      printf '\n'
    fi
    local connected
    connected="$(gpu_connected "$i")"
    [[ -n $connected ]] && printf '     outputs on: %s\n' "$connected"
  done

  printf '\nSaved order: '
  local order=()
  mapfile -t order < <(order_saved)
  local pci sep=""
  for pci in "${order[@]}"; do
    printf '%s' "$sep"
    sep=', '
    i="$(gpu_index_of_pci "$pci")" || {
      printf '%s (not present)' "$pci"
      continue
    }
    printf '%s' "$(gpu_label "$i")"
  done
  ((${#order[@]})) || printf 'automatic'
  ((GPU_HYBRID && ${#order[@]} > 1)) && printf ' — the first one renders'
  printf '\n'

  printf 'Running now: '
  local running=()
  mapfile -t running < <(running_order)
  if ((${#running[@]} == 0)); then
    printf 'unknown (no Hyprland log)\n'
  else
    sep=""
    for pci in "${running[@]}"; do
      printf '%s' "$sep"
      sep=' → '
      i="$(gpu_index_of_pci "$pci")" || {
        printf '%s (not present)' "$pci"
        continue
      }
      printf '%s' "$(gpu_label "$i")"
    done
    # An explicit list that the compositor actually honoured, otherwise the
    # compositor chose the order itself and the saved one is only a request for
    # the next login. Comparing against the detection order here used to claim
    # Aquamarine had the last word even when the hook had set the list.
    if [[ $(running_explicit) == 1 ]]; then
      printf ' (explicit list)'
    else
      printf ' — chosen by Aquamarine'
    fi
    printf '\n'
  fi

  printf 'Hook: %s (%s)\n' "$(hook_state "${order[@]}")" "$(hook_file)"
  if [[ $(gpu_multi) == 1 ]]; then
    printf 'Udev links: %s (%s)\n' "$(rules_state)" "$(rules_file)"
  fi
}

cmd_order() {
  detect
  local pci resolved=()
  if (($# == 0)); then
    order_write || return 1
  else
    for pci in "$@"; do
      _is_pci "$pci" || {
        printf 'mihai-renderer: not a PCI address: %s\n' "$pci" >&2
        return 1
      }
      gpu_index_of_pci "$pci" >/dev/null || {
        printf 'mihai-renderer: no GPU at %s\n' "$pci" >&2
        return 1
      }
      resolved+=("$pci")
    done
    order_write "${resolved[@]}" || return 1
  fi
  hook_write $(order_saved) || {
    printf 'mihai-renderer: could not write %s\n' "$(hook_file)" >&2
    return 1
  }
  cmd_status
}

cmd_write() {
  detect
  hook_write $(order_saved)
}

# The udev rules live in /etc, so writing them needs root. Rather than making
# every caller think about it, re-exec through pkexec, which puts Omarchy's
# polkit agent in front of the user. pkexec scrubs the environment, so the
# MIHAI_RENDERER_* overrides are deliberately not forwarded: a root-side write
# has to land in the real /etc, not in a test fixture.
escalate() {
  local self
  self="$(readlink -f -- "$0" 2>/dev/null || printf '%s' "$0")"
  if ! command -v pkexec >/dev/null 2>&1; then
    printf 'mihai-renderer: %s needs root and pkexec is not installed; run it with sudo\n' \
      "$(dirname "$(rules_file)")" >&2
    return 1
  fi
  pkexec "$self" "$@"
}

cmd_links_install() {
  local dir
  dir="$(dirname "$(rules_file)")"
  if [[ ! -w $dir && $(id -u) -ne 0 ]]; then
    escalate links-install "$@"
    return $?
  fi
  detect
  local file
  file="$(rules_file)"
  mkdir -p "$dir" || return 1
  rules_content >"$file" || return 1
  chmod 644 "$file"
  # Only DRM: the links show up now and nothing else is disturbed. The running
  # session does not care - it reads the order at the next login anyway.
  udevadm control --reload >/dev/null 2>&1
  udevadm trigger --subsystem-match=drm >/dev/null 2>&1
  printf 'wrote %s\n' "$file"
  local i
  for ((i = 0; i < GPU_COUNT; i++)); do
    [[ -n ${GPU_LINK[i]} ]] && printf '  /dev/dri/%s\n' "${GPU_LINK[i]}"
  done
}

cmd_links_remove() {
  local dir
  dir="$(dirname "$(rules_file)")"
  if [[ ! -w $dir && $(id -u) -ne 0 ]]; then
    escalate links-remove "$@"
    return $?
  fi
  local file
  file="$(rules_file)"
  [[ -f $file ]] || {
    printf '%s does not exist\n' "$file"
    return 0
  }
  rm -f "$file"
  udevadm control --reload >/dev/null 2>&1
  udevadm trigger --subsystem-match=drm >/dev/null 2>&1
  printf 'removed %s\n' "$file"
}

usage() {
  # The header comment is the documentation; print all of it, stopping at the
  # first line that is not a comment.
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 && NF { exit }' "$0"
}

main() {
  local cmd=${1:-status}
  shift || true
  case "$cmd" in
  status)
    detect
    cmd_status
    ;;
  json)
    detect
    emit_json
    ;;
  order)
    cmd_order "$@"
    ;;
  auto)
    cmd_order
    ;;
  preset)
    detect
    local resolved
    resolved=($(order_resolve_preset "${1:-auto}")) || exit 1
    cmd_order ${resolved[@]+"${resolved[@]}"}
    ;;
  write)
    cmd_write "$@"
    ;;
  hook)
    detect
    hook_render $(order_saved)
    ;;
  links)
    detect
    rules_content
    ;;
  links-install)
    cmd_links_install "$@"
    ;;
  links-remove)
    cmd_links_remove "$@"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    printf 'mihai-renderer: unknown command %s (try --help)\n' "$cmd" >&2
    exit 1
    ;;
  esac
}

main "$@"