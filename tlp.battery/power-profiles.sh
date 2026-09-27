#!/bin/bash
# Lists TLP power profiles in the tab format the power panel's picker
# expects (parseProfiles): "name\t<0|1>" where 1 marks the active one.
# Backs the picker with TLP because power-profiles-daemon has no profile
# interface on this firmware (/sys/firmware/acpi/platform_profile missing).
set -euo pipefail

probe=$(sudo -n tlp-stat -s 2>/dev/null || true)
active=$(grep -m1 "TLP profile" <<<"$probe" | awk -F= '{v=$2; sub(/\/.*$/,"",v); gsub(/ /,"",v); print v}')

for p in performance balanced power-saver; do
  if [[ $p == "$active" ]]; then
    printf '%s\t1\n' "$p"
  else
    printf '%s\t0\n' "$p"
  fi
done