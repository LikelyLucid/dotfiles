#!/usr/bin/env bash
set -euo pipefail

battery=/sys/class/power_supply/BAT0
capacity=$(<"$battery/capacity")
status=$(<"$battery/status")

case "$capacity" in
  8[0-9]|9[0-9]|100) icon="" ;;
  6[0-9]|7[0-9]) icon="" ;;
  4[0-9]|5[0-9]) icon="" ;;
  2[0-9]|3[0-9]) icon="" ;;
  *) icon="" ;;
esac

case "$status" in
  Charging) icon="" ;;
  Full|"Not charging") icon="" ;;
esac

remaining="Estimate unavailable"
current=$(<"$battery/current_now")
if (( current > 0 )); then
  if [[ $status == "Charging" ]] && [[ -r "$battery/charge_full" ]]; then
    charge=$(( $(<"$battery/charge_full") - $(<"$battery/charge_now") ))
    label="until full"
  else
    charge=$(<"$battery/charge_now")
    label="remaining"
  fi

  if (( charge >= 0 )); then
    minutes=$(( charge * 60 / current ))
    remaining="$(( minutes / 60 ))h $(( minutes % 60 ))min $label"
  fi
fi

printf '{"text":"%s %s%%","tooltip":"%s","class":"%s"}\n' \
  "$icon" "$capacity" "$remaining" "${status,,}"
