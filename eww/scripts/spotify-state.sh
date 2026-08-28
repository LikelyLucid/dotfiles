#!/usr/bin/env bash
set -euo pipefail

lock_path="${XDG_RUNTIME_DIR:-/tmp}/eww-spotify.lock"
exec 9>"$lock_path"
if ! flock -w 8 9; then
  printf '%s\n' '{"track":"Nothing playing","artist":"","album":"","status":"Paused","icon":"󰐊","has_track":false,"has_art":false,"cover_path":"/home/lucid/.config/eww/assets/transparent.svg","shuffle":false,"repeat_mode":"off","repeat_active":false,"repeat_icon":"󰑖","playlists":[]}'
  exit 0
fi

if ! playback=$(timeout 2s spotify_player get key playback 2>/dev/null); then
  playback=null
fi

[[ -n "$playback" ]] || playback=null
if ! jq -e . >/dev/null 2>&1 <<< "$playback"; then
  playback=null
fi

if ! playlist_output=$(timeout 5s spotify_player playlist list 2>/dev/null); then
  playlist_output=
fi

playlists=$(jq -R -s -c '
  split("\n")
  | map(select(length > 0) | sub("^[^:]+: "; ""))
' <<< "$playlist_output")

track="Nothing playing"
artist=""
album=""
cover_path="${XDG_CONFIG_HOME:-$HOME/.config}/eww/assets/transparent.svg"
has_track=false
has_art=false

if [[ "$(jq -r 'if .item? then "true" else "false" end' <<< "$playback")" == "true" ]]; then
  track=$(jq -r '.item.name // "Nothing playing"' <<< "$playback")
  artist=$(jq -r '[.item.artists[]?.name] | join(", ")' <<< "$playback")
  album=$(jq -r '.item.album.name // ""' <<< "$playback")
  album_id=$(jq -r '.item.album.id // ""' <<< "$playback")
  has_track=true

  if [[ -n "$album_id" ]]; then
    image_cache="${XDG_CACHE_HOME:-$HOME/.cache}/spotify-player/image"
    album_prefix=${album_id:0:6}
    shopt -s nullglob
    cover_candidates=("$image_cache"/*"-cover-${album_prefix}.jpg")
    for candidate in "${cover_candidates[@]}"; do
      if [[ -s "$candidate" ]]; then
        cover_path="$candidate"
        has_art=true
        break
      fi
    done
  fi
fi

jq -c \
  --arg track "$track" \
  --arg artist "$artist" \
  --arg album "$album" \
  --arg cover_path "$cover_path" \
  --argjson has_track "$has_track" \
  --argjson has_art "$has_art" \
  --argjson playlists "$playlists" \
  '{
    track: $track,
    artist: $artist,
    album: $album,
    status: (if (.is_playing? // false) then "Playing" else "Paused" end),
    icon: (if (.is_playing? // false) then "󰏤" else "󰐊" end),
    has_track: $has_track,
    has_art: $has_art,
    cover_path: $cover_path,
    shuffle: (.shuffle_state? // false),
    repeat_mode: (if ((.repeat_state? // "off") | IN("off", "context", "track")) then (.repeat_state // "off") else "off" end),
    repeat_active: ((.repeat_state? // "off") != "off"),
    repeat_icon: (if (.repeat_state? // "off") == "track" then "󰑘" else "󰑖" end),
    playlists: $playlists
  }' <<< "$playback"
