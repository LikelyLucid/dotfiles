#!/usr/bin/env bash
set -euo pipefail

domain=${1:-}
action=${2:-}
shift 2 2>/dev/null || true
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
runtime_dir=${XDG_RUNTIME_DIR:-/tmp}

hex_decode() {
  [[ ${1:-} =~ ^([[:xdigit:]]{2})+$ ]] || return 2
  python3 -c 'import sys; print(bytes.fromhex(sys.argv[1]).decode(), end="")' "$1"
}

refresh_async() {
  (
    payload=$("$config_dir/scripts/shell-state.py")
    eww --force-wayland --config "$config_dir" update "shell_state=$payload" >/dev/null 2>&1 || true
  ) >/dev/null 2>&1 &
}

case "$domain:$action" in
  shell:page)
    page=${1:-home}
    [[ $page =~ ^[a-z-]+$ ]] || exit 2
    eww --force-wayland --config "$config_dir" update "shell_page=$page"
    exit 0
    ;;
  shell:refresh)
    payload=$("$config_dir/scripts/shell-state.py")
    eww --force-wayland --config "$config_dir" update "shell_state=$payload"
    exit 0
    ;;
  quick:*)
    exec "$config_dir/scripts/system-action.sh" "${action%%-*}" "${action#*-}" "$@"
    ;;
  clipboard:copy)
    id=${1:-}
    [[ $id =~ ^[0-9]+$ ]] || exit 2
    cliphist decode "$id" | wl-copy
    ;;
  clipboard:search)
    selection=$(cliphist list | rofi -dmenu -i -p 'Clipboard')
    [[ -n $selection ]] && printf '%s\n' "$selection" | cliphist decode | wl-copy
    ;;
  clipboard:clear)
    cliphist wipe
    ;;
  media:play-pause|media:next|media:previous)
    player=$(hex_decode "${1:-}")
    playerctl -p "$player" "${action/play-pause/play-pause}"
    ;;
  window:focus)
    address=$(hex_decode "${1:-}")
    [[ $address =~ ^0x[[:xdigit:]]+$ ]] || exit 2
    hyprctl dispatch "hl.dsp.focus({ window = { address = \"$address\" } })" >/dev/null
    ;;
  file:open)
    path=$(hex_decode "${1:-}")
    [[ $path == "$HOME"/* ]] || exit 2
    xdg-open "$path" >/dev/null 2>&1 &
    ;;
  calendar:open)
    url=$(hex_decode "${1:-}")
    [[ $url == https://* ]] || exit 2
    xdg-open "$url" >/dev/null 2>&1 &
    ;;
  calendar:create)
    xdg-open 'https://calendar.google.com/calendar/u/0/r/eventedit' >/dev/null 2>&1 &
    ;;
  display:night-light)
    if pgrep -x hyprsunset >/dev/null; then pkill -x hyprsunset; else hyprsunset -t 4500 >/dev/null 2>&1 & fi
    ;;
  display:appearance)
    wallust run "$HOME/dotfiles/media/wallpapers/wallpaper.jpg" >/dev/null 2>&1 &
    ;;
  focus:start)
    minutes=${1:-25}
    [[ $minutes =~ ^(15|25|45|60)$ ]] || exit 2
    dnd=$("$config_dir/scripts/system-state.py" notifications | jq -r .dnd)
    idle=$("$config_dir/scripts/system-state.py" power | jq -r .idle_active)
    printf '{"ends":%s,"restore_dnd":%s,"restore_idle":%s}\n' "$(( $(date +%s) + minutes * 60 ))" "$dnd" "$idle" >"$runtime_dir/eww-focus-session.json"
    [[ $dnd == true ]] || swaync-client -d -sw
    [[ $idle == false ]] || "$HOME/.config/hypr/scripts/caffinate.sh"
    ;;
  focus:stop)
    if [[ -r $runtime_dir/eww-focus-session.json ]]; then
      restore_dnd=$(jq -r .restore_dnd "$runtime_dir/eww-focus-session.json")
      restore_idle=$(jq -r .restore_idle "$runtime_dir/eww-focus-session.json")
      current_dnd=$("$config_dir/scripts/system-state.py" notifications | jq -r .dnd)
      current_idle=$("$config_dir/scripts/system-state.py" power | jq -r .idle_active)
      [[ $restore_dnd == "$current_dnd" ]] || swaync-client -d -sw
      [[ $restore_idle == "$current_idle" ]] || "$HOME/.config/hypr/scripts/caffinate.sh"
      rm -f "$runtime_dir/eww-focus-session.json"
    fi
    ;;
  network:diagnostics)
    ghostty -e bash -lc 'printf "Network diagnostics\n\n"; ip address; printf "\nRoutes\n"; ip route; printf "\nConnectivity\n"; ping -c 4 1.1.1.1; read -r -p "Press Enter to close"' >/dev/null 2>&1 &
    ;;
  storage:unmount)
    device=${1:-}
    [[ $device =~ ^/dev/[[:alnum:]_.-]+$ ]] || exit 2
    udisksctl unmount -b "$device"
    ;;
  notifications:open)
    swaync-client -t -sw
    ;;
  settings:audio) pavucontrol >/dev/null 2>&1 & ;;
  settings:bluetooth) blueman-manager >/dev/null 2>&1 & ;;
  settings:network) nm-connection-editor >/dev/null 2>&1 & ;;
  settings:disks) gnome-disks >/dev/null 2>&1 & ;;
  nixos:*|power:reboot|power:shutdown|power:logout)
    # Deliberately disabled until the user reviews these controls.
    exit 0
    ;;
  *)
    printf 'Unknown shell action: %s %s\n' "$domain" "$action" >&2
    exit 2
    ;;
esac

refresh_async
