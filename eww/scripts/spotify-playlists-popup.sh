#!/usr/bin/env bash
set -euo pipefail

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
exec "$config_dir/scripts/eww-popup-open.sh" \
  spotify_playlists \
  --width 320 \
  --height 320 \
  --dismiss-namespace eww-spotify-playlists \
  --close spotify_player
