#!/usr/bin/env bash
set -euo pipefail

action=${1:-}
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/eww"

lock_path="${XDG_RUNTIME_DIR:-/tmp}/eww-spotify.lock"
exec 9>"$lock_path"
flock -w 8 9 || exit 1

previous_mode=""
if [[ "$action" == "shuffle" || "$action" == "repeat" ]]; then
  playback=$(timeout 2s spotify_player get key playback 2>/dev/null || printf 'null')
  if [[ "$action" == "shuffle" ]]; then
    previous_mode=$(jq -r '.shuffle_state? // false' <<< "$playback")
  else
    previous_mode=$(jq -r '.repeat_state? // "off"' <<< "$playback")
  fi
fi

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

if [[ "$action" == "previous" || "$action" == "next" || "$action" == "play-pause" || "$action" == "shuffle" || "$action" == "repeat" ]]; then
  if [[ -n "$previous_mode" ]] && current_state=$(eww --force-wayland --config "$config_dir" get spotify_state 2>/dev/null); then
    if [[ "$action" == "shuffle" ]]; then
      optimistic_state=$(jq -c --argjson enabled "$([[ "$previous_mode" == "true" ]] && printf false || printf true)" '.shuffle = $enabled' <<< "$current_state")
    else
      case "$previous_mode" in
        off) next_mode=track ;;
        track) next_mode=context ;;
        *) next_mode=off ;;
      esac
      optimistic_state=$(jq -c --arg mode "$next_mode" '
        .repeat_mode = $mode
        | .repeat_active = ($mode != "off")
        | .repeat_icon = (if $mode == "track" then "󰑘" else "󰑖" end)
      ' <<< "$current_state")
    fi
    eww --force-wayland --config "$config_dir" update "spotify_state=$optimistic_state" >/dev/null 2>&1 || true
  fi
  flock -u 9
  if [[ -z "$previous_mode" ]] && spotify_state=$("$config_dir/scripts/spotify-state.sh"); then
    eww --force-wayland --config "$config_dir" update "spotify_state=$spotify_state" >/dev/null 2>&1 || true
  fi
fi
