#!/usr/bin/env bash
set -euo pipefail

action=${1:-}

lock_path="${XDG_RUNTIME_DIR:-/tmp}/eww-spotify.lock"
exec 9>"$lock_path"
flock -w 8 9 || exit 1

case "$action" in
  previous|next|play-pause|shuffle|repeat)
    case "$action" in
      shuffle) spotify_player playback shuffle ;;
      repeat) spotify_player playback repeat ;;
      *) spotify_player playback "$action" ;;
    esac
    ;;
  playlist-name)
    [[ -n ${2:-} ]] || exit 2
    playlist_id=""
    while IFS= read -r playlist; do
      playlist_name=${playlist#*: }
      if [[ "$playlist_name" == "$2" ]]; then
        playlist_id=${playlist%%: *}
        break
      fi
    done < <(spotify_player playlist list)
    [[ -n "$playlist_id" ]] || exit 1
    spotify_player playback start context --id "$playlist_id" playlist
    eww --force-wayland --config "${XDG_CONFIG_HOME:-$HOME/.config}/eww" close spotify_playlists >/dev/null 2>&1 || true
    eww --force-wayland --config "${XDG_CONFIG_HOME:-$HOME/.config}/eww" close spotify_player >/dev/null 2>&1 || true
    ;;
  *)
    printf 'Unknown Spotify action: %s\n' "$action" >&2
    exit 2
    ;;
esac
