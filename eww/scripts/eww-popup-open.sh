#!/usr/bin/env bash
set -euo pipefail

# Open an eww popup below the clicked module, or at a fixed position.
# Usage: eww-popup-open.sh WINDOW [options]

if (($# == 0)); then
  printf 'Usage: %s WINDOW [--width N] [--height N] [--gap N] [--align center|left|right] [--duration DURATION] [--fixed-screen N --fixed-x N [--fixed-y N]] [--open] [--close WINDOW]\n' "$0" >&2
  exit 2
fi

window=$1
shift

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
width=320
height=155
gap=${EWW_POPUP_GAP:-8}
align="center"
fixed_screen=""
fixed_x=""
fixed_y=""
duration=""
close_windows=()
toggle=true

action_usage() {
  printf 'Usage: %s WINDOW [--width N] [--height N] [--gap N] [--align center|left|right] [--duration DURATION] [--fixed-screen N --fixed-x N [--fixed-y N]] [--open] [--close WINDOW]\n' "$0" >&2
}

while (($# > 0)); do
  case "$1" in
    --width|--height|--gap|--align)
      (($# >= 2)) || { action_usage; exit 2; }
      case "$1" in
        --width) width=$2 ;;
        --height) height=$2 ;;
        --gap) gap=$2 ;;
        --align) align=$2 ;;
      esac
      shift 2
      ;;
    --duration)
      (($# >= 2)) || { action_usage; exit 2; }
      duration=$2
      shift 2
      ;;
    --fixed-screen)
      (($# >= 2)) || { action_usage; exit 2; }
      fixed_screen=$2
      shift 2
      ;;
    --fixed-x)
      (($# >= 2)) || { action_usage; exit 2; }
      fixed_x=$2
      shift 2
      ;;
    --fixed-y)
      (($# >= 2)) || { action_usage; exit 2; }
      fixed_y=$2
      shift 2
      ;;
    --close)
      (($# >= 2)) || { action_usage; exit 2; }
      close_windows+=("$2")
      shift 2
      ;;
    --open)
      toggle=false
      shift
      ;;
    --help|-h)
      action_usage
      exit 0
      ;;
    *)
      action_usage
      exit 2
      ;;
  esac
done

eww_cmd=(eww --force-wayland --config "$config_dir")

if [[ $("${eww_cmd[@]}" ping 2>/dev/null) != "pong" ]]; then
  "${eww_cmd[@]}" daemon >/dev/null 2>&1 &
  for _ in {1..20}; do
    [[ $("${eww_cmd[@]}" ping 2>/dev/null) == "pong" ]] && break
    sleep 0.05
  done
fi

position_args=(
  --width "$width"
  --height "$height"
  --gap "$gap"
  --align "$align"
)
if [[ -n "$fixed_screen" ]]; then
  position_args+=(--fixed-screen "$fixed_screen")
fi
if [[ -n "$fixed_x" ]]; then
  position_args+=(--fixed-x "$fixed_x")
fi
if [[ -n "$fixed_y" ]]; then
  position_args+=(--fixed-y "$fixed_y")
fi

read -r screen popup_x popup_y < <(
  "$config_dir/scripts/eww-popup-position.sh" "${position_args[@]}"
)

for close_window in "${close_windows[@]}"; do
  "${eww_cmd[@]}" close "$close_window" >/dev/null 2>&1 || true
done

open_args=(
  open
  --screen "$screen"
  --anchor "top left"
  --pos "${popup_x}x${popup_y}"
)
if [[ "$toggle" == true ]]; then
  open_args+=(--toggle)
fi
if [[ -n "$duration" ]]; then
  open_args+=(--duration "$duration")
fi
open_args+=("$window")

"${eww_cmd[@]}" "${open_args[@]}"
