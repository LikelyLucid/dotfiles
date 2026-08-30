#!/usr/bin/env bash
set -euo pipefail

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/eww"
cache_path="$cache_dir/spotify-playlists.json"
mkdir -p "$cache_dir"
if [[ -s "$cache_path" ]] && jq -e 'type == "array"' "$cache_path" >/dev/null 2>&1; then
  cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_path") ))
  if ((cache_age < 600)); then
    playlists=$(<"$cache_path")
    printf '%s\n' "$playlists"
    exit 0
  fi
fi

lock_path="${XDG_RUNTIME_DIR:-/tmp}/eww-spotify.lock"
exec 9>"$lock_path"
if ! flock -w 8 9; then
  printf '%s\n' '[]'
  exit 0
fi

if ! playlist_output=$(timeout 5s spotify_player playlist list 2>/dev/null); then
  playlist_output=
fi

playlists=$(jq -R -s -c '
  split("\n")
  | map(select(length > 0) | sub("^[^:]+: "; ""))
' <<< "$playlist_output")
printf '%s\n' "$playlists" >"$cache_path.tmp"
mv "$cache_path.tmp" "$cache_path"
printf '%s\n' "$playlists"
