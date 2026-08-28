#!/usr/bin/env bash
set -euo pipefail

widget=${1:-}
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
case "$widget" in
  audio) window=preview_audio; namespace=eww-preview-audio; width=340; height=390 ;;
  bluetooth) window=preview_bluetooth; namespace=eww-preview-bluetooth; width=360; height=380 ;;
  wifi|network) window=preview_network; namespace=eww-preview-network; width=360; height=410 ;;
  workspaces) window=preview_workspaces; namespace=eww-preview-workspaces; width=360; height=320 ;;
  power) window=preview_power; namespace=eww-preview-power; width=340; height=430 ;;
  notifications) window=preview_notifications; namespace=eww-preview-notifications; width=340; height=260 ;;
  *)
    printf 'Usage: %s audio|bluetooth|wifi|workspaces|power|notifications\n' "$0" >&2
    exit 2
    ;;
esac

close_args=()
for competing in preview_audio preview_bluetooth preview_network preview_workspaces preview_power preview_notifications calendar_popup spotify_player spotify_playlists; do
  [[ $competing == "$window" ]] || close_args+=(--close "$competing")
done

exec "$config_dir/scripts/eww-popup-open.sh" "$window" \
  --width "$width" \
  --height "$height" \
  --dismiss-namespace "$namespace" \
  "${close_args[@]}"
