#!/usr/bin/env bash
set -euo pipefail

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
# Refresh in the background; the existing state appears immediately and is
# replaced when the slower cross-system provider finishes.
"$config_dir/scripts/shell-action.sh" shell refresh >/dev/null 2>&1 &
exec "$config_dir/scripts/eww-popup-open.sh" \
  control_center_popup \
  --width 706 \
  --height 650 \
  --dismiss-namespace eww-control-center \
  --close preview_audio \
  --close preview_bluetooth \
  --close preview_network \
  --close preview_workspaces \
  --close preview_power \
  --close preview_notifications \
  --close calendar_popup \
  --close spotify_player \
  --close spotify_playlists
