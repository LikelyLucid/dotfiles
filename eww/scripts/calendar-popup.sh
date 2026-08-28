#!/usr/bin/env bash
set -euo pipefail

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
exec "$config_dir/scripts/eww-popup-open.sh" \
  calendar_popup \
  --width 390 \
  --height 500 \
  --duration "${EWW_CALENDAR_DURATION:-30s}" \
  --close spotify_player \
  --close spotify_playlists
