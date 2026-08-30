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
for competing in preview_audio preview_bluetooth preview_network preview_workspaces preview_power preview_notifications calendar_popup spotify_player spotify_playlists tools_popup; do
  [[ $competing == "$window" ]] || close_args+=(--close "$competing")
done

# Refresh the matching domain state in the background so the popup shows
# current values immediately instead of waiting for the next defpoll tick.
refresh_domains=(audio bluetooth network workspaces power notifications)
for domain in "${refresh_domains[@]}"; do
  (
    payload=$("$config_dir/scripts/system-state.py" "$domain" 2>/dev/null) || exit 0
    [[ -n $payload ]] || exit 0
    case "$domain" in
      audio) variable=audio_state ;;
      bluetooth) variable=bluetooth_state ;;
      network) variable=network_state ;;
      workspaces) variable=workspace_state ;;
      power) variable=power_state ;;
      notifications) variable=notification_state ;;
    esac
    eww --force-wayland --config "$config_dir" update "${variable}=$payload" >/dev/null 2>&1 || true
  ) &
done

exec "$config_dir/scripts/eww-popup-open.sh" "$window" \
  --width "$width" \
  --height "$height" \
  --dismiss-namespace "$namespace" \
  "${close_args[@]}"
