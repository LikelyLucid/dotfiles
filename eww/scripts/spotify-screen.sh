#!/usr/bin/env bash
set -euo pipefail

cursor=$(hyprctl cursorpos 2>/dev/null || printf '0,0')
IFS=, read -r cursor_x cursor_y <<< "$cursor"

screen=$(hyprctl monitors -j 2>/dev/null \
  | jq -r --argjson x "${cursor_x:-0}" --argjson y "${cursor_y:-0}" '
      first(.[]
        | select(
            $x >= .x
            and $x < (.x + .width)
            and $y >= .y
            and $y < (.y + .height)
          )
        | .id
      ) // 0
    ' 2>/dev/null || printf '0')

[[ "$screen" =~ ^[0-9]+$ ]] || screen=0
printf '%s\n' "$screen"
