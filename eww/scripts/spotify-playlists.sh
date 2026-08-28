#!/usr/bin/env bash
set -euo pipefail

lock_path="${XDG_RUNTIME_DIR:-/tmp}/eww-spotify.lock"
exec 9>"$lock_path"
if ! flock -w 8 9; then
  printf '%s\n' '[]'
  exit 0
fi

playlist_output=$(timeout 5s spotify_player playlist list 2>/dev/null || true)

jq -R -s -c '
    split("\n")
    | map(select(length > 0) | sub("^[^:]+: "; ""))
  ' <<< "$playlist_output"
