#!/usr/bin/env bash
set -euo pipefail

# Calculate a monitor-relative eww position from the current cursor location,
# or from a fixed monitor-relative position when requested.
# Output: <monitor-id> <x> <y>

popup_width=320
popup_height=155
gap=${EWW_POPUP_GAP:-8}
# Keep extra horizontal breathing room for GTK borders, shadows, and rounded
# corners. This is deliberately independent from the vertical Waybar gap.
edge_gap=${EWW_POPUP_EDGE_GAP:-20}
align="center"
fixed_screen=""
fixed_x=""
fixed_y=""

usage() {
  printf 'Usage: %s [--width N] [--height N] [--gap N] [--align center|left|right] [--fixed-screen N --fixed-x N [--fixed-y N]]\n' "$0" >&2
}

while (($# > 0)); do
  case "$1" in
    --width)
      (($# >= 2)) || { usage; exit 2; }
      popup_width=$2
      shift 2
      ;;
    --height)
      (($# >= 2)) || { usage; exit 2; }
      popup_height=$2
      shift 2
      ;;
    --gap)
      (($# >= 2)) || { usage; exit 2; }
      gap=$2
      shift 2
      ;;
    --align)
      (($# >= 2)) || { usage; exit 2; }
      align=$2
      shift 2
      ;;
    --fixed-screen)
      (($# >= 2)) || { usage; exit 2; }
      fixed_screen=$2
      shift 2
      ;;
    --fixed-x)
      (($# >= 2)) || { usage; exit 2; }
      fixed_x=$2
      shift 2
      ;;
    --fixed-y)
      (($# >= 2)) || { usage; exit 2; }
      fixed_y=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

is_non_negative_integer() {
  [[ ${1:-} =~ ^[0-9]+$ ]]
}

is_non_negative_integer "$popup_width" || { usage; exit 2; }
is_non_negative_integer "$popup_height" || { usage; exit 2; }
is_non_negative_integer "$gap" || { usage; exit 2; }
is_non_negative_integer "$edge_gap" || { usage; exit 2; }
if [[ -n "$fixed_screen" ]]; then
  is_non_negative_integer "$fixed_screen" || { usage; exit 2; }
fi
if [[ -n "$fixed_x" ]]; then
  is_non_negative_integer "$fixed_x" || { usage; exit 2; }
fi
if [[ -n "$fixed_y" ]]; then
  is_non_negative_integer "$fixed_y" || { usage; exit 2; }
fi
if [[ -n "$fixed_screen" && -z "$fixed_x" ]] || [[ -n "$fixed_x" && -z "$fixed_screen" ]]; then
  usage
  exit 2
fi
case "$align" in
  center|left|right) ;;
  *) usage; exit 2 ;;
esac

if [[ -n "$fixed_screen" ]]; then
  monitor_info=$(hyprctl monitors -j 2>/dev/null \
    | jq -r --argjson id "$fixed_screen" '
        first(.[] | select(.id == $id))
        | if . then [.id, .x, .y, .width, .height] | @tsv else empty end
      ' 2>/dev/null || true)
else
  cursor=$(hyprctl cursorpos 2>/dev/null || printf '0,0')
  cursor=${cursor//[[:space:]]/}
  IFS=, read -r cursor_x cursor_y <<< "$cursor"
  is_non_negative_integer "${cursor_x#-}" || cursor_x=0
  is_non_negative_integer "${cursor_y#-}" || cursor_y=0

  monitor_info=$(hyprctl monitors -j 2>/dev/null \
    | jq -r --argjson x "$cursor_x" --argjson y "$cursor_y" '
        (first(.[]
          | select(
              $x >= .x
              and $x < (.x + .width)
              and $y >= .y
              and $y < (.y + .height)
            )) // first(.[]))
        | if . then [.id, .x, .y, .width, .height] | @tsv else empty end
      ' 2>/dev/null || true)
fi

if [[ -z "$monitor_info" ]]; then
  printf '0 0 %s\n' "$gap"
  exit 0
fi

read -r screen monitor_x monitor_y monitor_width monitor_height <<< "$monitor_info"
for value in "$screen" "$monitor_x" "$monitor_y" "$monitor_width" "$monitor_height"; do
  [[ "$value" =~ ^-?[0-9]+$ ]] || {
    printf '0 0 %s\n' "$gap"
    exit 0
  }
done

if [[ -n "$fixed_x" ]]; then
  popup_x=$fixed_x
else
  cursor_relative_x=$((cursor_x - monitor_x))

  case "$align" in
    center)
      popup_x=$((cursor_relative_x - popup_width / 2))
      ;;
    left)
      popup_x=$cursor_relative_x
      ;;
    right)
      popup_x=$((cursor_relative_x - popup_width))
      ;;
  esac
fi

if (( popup_width + 2 * edge_gap >= monitor_width )); then
  popup_x=0
else
  (( popup_x < edge_gap )) && popup_x=$edge_gap
  max_x=$((monitor_width - popup_width - edge_gap))
  (( popup_x > max_x )) && popup_x=$max_x
fi

# Waybar's exclusive top region is already accounted for by eww. Keep the
# popup at a fixed gap below the bar. Fixed callers can override the gap when
# they need a different monitor-relative y position.
popup_y=${fixed_y:-$gap}

if (( popup_height + 2 * gap >= monitor_height )); then
  popup_y=0
else
  max_y=$((monitor_height - popup_height - gap))
  (( popup_y > max_y )) && popup_y=$max_y
fi

printf '%s %s %s %s %s\n' "$screen" "$popup_x" "$popup_y" "$popup_width" "$popup_height"
