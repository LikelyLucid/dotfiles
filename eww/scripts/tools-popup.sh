#!/usr/bin/env bash
set -euo pipefail

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
"$config_dir/scripts/shell-action.sh" shell refresh >/dev/null 2>&1 &
exec "$config_dir/scripts/eww-popup-open.sh" \
  tools_popup \
  --width 360 \
  --height 480 \
  --dismiss-namespace eww-tools \
  --close preview_audio \
  --close preview_bluetooth \
  --close preview_network \
  --close preview_workspaces \
  --close preview_power \
  --close preview_notifications \
  --close calendar_popup \
  --close spotify_player \
  --close spotify_playlists
