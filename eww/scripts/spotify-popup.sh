#!/usr/bin/env bash
set -euo pipefail

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
exec "$config_dir/scripts/eww-popup-open.sh" \
  spotify_player \
  --width 320 \
  --height 155 \
  --close spotify_playlists
