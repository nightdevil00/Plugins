#!/bin/bash
# TLP-backed battery status for the omarchy power widget (tlp.battery clone).
# Farms numbers from `tlp-stat -b` (TLP drives the charge policy) and emits
# the same tab-separated fields the panel parses:
#   percentage  state  rate  size  time  cycles  threshold
#
# TLP prints energy in mWh / power in mW; the sysfs fallback is µWh / µW.

set -euo pipefail

battery=""
for b in /sys/class/power_supply/BAT[0-9]*; do
  [[ -r $b/present && -r $b/status ]] || continue
  if [[ $(<"$b/present") == "1" ]]; then
    battery=$b
    break
  fi
done
[[ -n $battery ]] || exit 0

base=${battery##*/}
out=$(sudo -n tlp-stat -b 2>/dev/null || true)

# Pull "value [unit]" from tlp-stat for <var>, returning numeric value and
# unit via the mirrored *_unit var. Uses the battery sysfs path on the line.
pick() {
  local var="$1" unit="${1}_unit"
  local line value
  line=$(sed -n "s#^$battery/$var *= *##p;T;q" <<<"$out")
  if [[ -n $line ]]; then
    value=${line%% *}
    printf -v "$var" '%s' "$value"
    [[ $line == *"["*"]"* ]] && printf -v "$unit" '%s' "$(sed -n 's/.*\[\(.*\)\].*/\1/p' <<<"$line")" || printf -v "$unit" ''
    return
  fi
  # sysfs fallback: raw µWh / µW
  if [[ -r $battery/$var ]]; then
    printf -v "$var" '%s' "$(cat "$battery/$var")"
    printf -v "$unit" 'uW'
    return
  fi
  printf -v "$var" ''
  printf -v "$unit" ''
}

energy_full=""; energy_full_unit=""
energy_now="";  energy_now_unit=""
power_now="";   power_now_unit=""
cycle_count=""; cycle_count_unit=""
pick energy_full
pick energy_now
pick power_now
pick cycle_count
cycles=$cycle_count
status=$(sed -n "s#^$battery/status *= *##p;T;q" <<<"$out")
charge_types=$(sed -n "s#^$battery/charge_types *= *##p;T;q" <<<"$out")
[[ -n $status ]] || status=$(cat "$battery/status" 2>/dev/null || true)
charge=$(sed -n 's/^Charge *= *//p;T;q' <<<"$out")
pure_charge=${charge%%[!0-9.]*}
[[ -z $pure_charge ]] && pure_charge=0

# No tlp-stat output at all (e.g. daemon down) -> fall back to sysfs units.
fallback_units() {
  [[ $energy_full_unit == uW ]] || energy_full_unit="mWh"
  [[ $energy_now_unit == uW ]] || energy_now_unit="mWh"
  [[ $power_now_unit == uW ]] || power_now_unit="mW"
}
if [[ -z $out ]]; then
  energy_full=$(cat "$battery/energy_full" 2>/dev/null || true)
  energy_now=$(cat "$battery/energy_now" 2>/dev/null || true)
  power_now=$(cat "$battery/power_now" 2>/dev/null || true)
  energy_full_unit="uWh"; energy_now_unit="uWh"; power_now_unit="uW"
fi

# Normalize to Wh / W.
to_wh() { awk -v v="$1" -v u="$2" 'BEGIN { if (u=="uWh") printf "%.1f", v/1e6; else printf "%.1f", v/1000 }'; }
to_w()  { awk -v v="$1" -v u="$2" 'BEGIN { if (u=="uW") printf "%.1f", v/1e6; else printf "%.1f", v/1000 }'; }

size=$(to_wh "$energy_full" "$energy_full_unit")
size_trim=$(awk -v s="$size" 'BEGIN { sub(/\.0$/, "", s); print s }')
power=$(to_w "$power_now" "$power_now_unit")
power_trim=$(awk -v r="$power" 'BEGIN { sub(/\.0$/, "", r); print r }')
# Keep raw mWh/mW in sync for time math.
efull_wh=$(to_wh "$energy_full" "$energy_full_unit")
enow_wh=$(to_wh "$energy_now" "$energy_now_unit")
epow_w=$(to_w "$power_now" "$power_now_unit")

# "Fast [Standard] Long_Life" -> the bracketed one is active.
active_type=""
if [[ -n $charge_types ]]; then
  active_type=$(awk '{ for (i=1; i<=NF; i++) if (substr($i,1,1)=="[") { g=substr($i,2,length($i)-2); if (g ~ /^(Fast|Standard|Long_Life)$/) active=g } } END { print active }' <<<"$charge_types")
fi
cap_active=false
[[ $active_type == "Long_Life" ]] && cap_active=true

charge_holding=false
if [[ $cap_active == true ]] && [[ $status != "Charging" ]] && [[ $status != "Discharging" ]]; then
  charge_holding=true
fi

pure_int=$(awk -v c="$pure_charge" 'BEGIN { printf "%.0f", c }')
rich_state="idle"
case "$status" in
  Charging)
    if (( pure_int >= 99 )); then rich_state="fully-charged"; else rich_state="charging"; fi
    ;;
  Discharging)
    (( pure_int >= 99 )) && rich_state="fully-charged" || rich_state="discharging"
    ;;
  Full) rich_state="fully-charged" ;;
  *)   [[ $charge_holding == true ]] && rich_state="holding" || rich_state="idle" ;;
esac

time_val="-"
case "$rich_state" in
  charging)
    if awk -v r="$epow_w" 'BEGIN { exit !(r > 0.2) }'; then
      time_val=$(awk -v full="$efull_wh" -v now="$enow_wh" -v w="$epow_w" \
        'BEGIN { if (w <= 0) { print "-"; exit } m=((full - now) / w) * 60; h=int(m/60); mn=int(m%60); if (h>0) printf "%dh %dm", h, mn; else printf "%dm", mn }')
    fi
    ;;
  discharging)
    if awk -v r="$epow_w" 'BEGIN { exit !(r > 0.2) }'; then
      time_val=$(awk -v now="$enow_wh" -v w="$epow_w" \
        'BEGIN { if (w <= 0) { print "-"; exit } m=(now / w) * 60; h=int(m/60); mn=int(m%60); if (h>0) printf "%dh %dm", h, mn; else printf "%dm", mn }')
    fi
    ;;
esac

printf 'percentage\t%s%%\n' "$pure_int"
printf 'state\t%s\n' "$rich_state"
printf 'rate\t%sW\n' "$power_trim"
printf 'size\t%sWh\n' "$size_trim"
printf 'time\t%s\n' "$time_val"
[[ -n $cycles ]] && printf 'cycles\t%s\n' "$cycles"
if [[ $charge_holding == true ]]; then
  printf 'threshold\t%s\n' "$active_type"
fi