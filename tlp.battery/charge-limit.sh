#!/bin/bash
# TLP charge-limit control for the omarchy power widget (tlp.battery clone).
# The ThinkBook's lenovo charge_type is binary:
#   0 = Standard (charge to 100%)    1 = Long_Life (conservation cap)
# Usage: charge-limit.sh show|set100|setcap
#
# set100/setcap persist the choice in the TLP drop-in (so it survives the
# next `tlp start`/boot) and apply it immediately via `tlp setcharge`.
set -euo pipefail

DROPIN=/etc/tlp.d/10-omarchy-charge.conf
cmd="${1:-show}"

current_type() {
  awk '{for (i=1; i<=NF; i++) if (substr($i,1,1)=="[") { print substr($i,2,length($i)-2); exit }}' \
    /sys/class/power_supply/BAT0/charge_types 2>/dev/null || true
}

apply() {
  local stop="$1"
  sudo tee "$DROPIN" >/dev/null <<EOF
# Omarchy: drive the ThinkBook's lenovo charge_type through TLP.
# 0 = Standard (charge to 100%), 1 = Long_Life (conservation cap).
START_CHARGE_THRESH_BAT0=0
STOP_CHARGE_THRESH_BAT0=${stop}
EOF
  sudo tlp setcharge 0 "${stop}" BAT0 >/dev/null 2>&1
}

case "$cmd" in
  show)
    type=$(current_type)
    if [[ $type == "Long_Life" ]]; then
      echo cap
    else
      echo standard
    fi
    ;;
  set100) apply 0 ;;
  setcap) apply 1 ;;
  *) echo "usage: charge-limit.sh show|set100|setcap" >&2; exit 2 ;;
esac