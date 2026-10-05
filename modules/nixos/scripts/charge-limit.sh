#!/usr/bin/env bash
# Use the kernel's battery interface; never issue raw EC commands.
set -euo pipefail

supply_root=$1
limit=$2
if [[ ! $limit =~ ^[0-9]+$ ]] || (( 10#$limit < 1 || 10#$limit > 100 )); then
  echo "Charge limit must be an integer from 1 to 100." >&2
  exit 2
fi

found=false
for battery in "$supply_root"/BAT*; do
  [[ -f "$battery/type" && $(cat "$battery/type") == Battery ]] || continue
  threshold="$battery/charge_control_end_threshold"
  [[ -f "$threshold" ]] || continue
  printf '%s\n' "$limit" > "$threshold"
  actual=$(cat "$threshold")
  if [[ $actual != "$limit" ]]; then
    echo "Battery rejected charge limit $limit (reports $actual): $battery" >&2
    exit 1
  fi
  echo "Charge limit set to $actual%: $battery"
  found=true
done
if [[ $found == false ]]; then
  echo "No supported BAT* charge-control interface found; inspect the Framework driver and firmware." >&2
  exit 1
fi
