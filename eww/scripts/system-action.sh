#!/usr/bin/env bash
set -euo pipefail

domain=${1:-}
action=${2:-}
shift 2 2>/dev/null || true

nothing_cli() {
  local cli
  if command -v nothing-cli >/dev/null 2>&1; then
    cli=$(command -v nothing-cli)
  elif [[ -x $HOME/Projects/Nothing-cli/.release-venv/bin/nothing-cli ]]; then
    cli=$HOME/Projects/Nothing-cli/.release-venv/bin/nothing-cli
  else
    return 127
  fi
  flock -w 8 "${XDG_RUNTIME_DIR:-/tmp}/nothing-headphones-cli.lock" "$cli" "$@"
}

audio_target() {
  local mac needle target
  mac=$(bluetoothctl devices Connected | awk 'tolower($0) ~ /nothing headphone/ { print $2; exit }')
  [[ -n $mac ]] || { printf '@DEFAULT_AUDIO_SINK@\n'; return; }
  needle=${mac//:/_}
  target=$(wpctl status -n | awk -v needle="$needle" 'index(tolower($0), tolower(needle)) { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+\.$/) { sub(/\.$/, "", $i); print $i; exit } }')
  printf '%s\n' "${target:-@DEFAULT_AUDIO_SINK@}"
}

decode_hex() {
  [[ ${1:-} =~ ^([[:xdigit:]]{2})+$ ]] || return 2
  python3 -c 'import sys; print(bytes.fromhex(sys.argv[1]).decode(), end="")' "$1"
}

refresh_widget_state() {
  local provider variable payload config_dir last_refresh now
  config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
  case "$domain" in
    audio) provider=audio; variable=audio_state ;;
    bluetooth) provider=bluetooth; variable=bluetooth_state ;;
    network) provider=network; variable=network_state ;;
    workspaces) provider=workspaces; variable=workspace_state ;;
    power) provider=power; variable=power_state ;;
    notifications) provider=notifications; variable=notification_state ;;
    *) return ;;
  esac
  # Slider drags fire onchange rapidly; skip the expensive state refresh
  # while they are in flight and let the defpoll settle the value.
  last_refresh_file=${XDG_RUNTIME_DIR:-/tmp}/eww-refresh-${domain}.stamp
  now=$(date +%s%N)
  if [[ -r $last_refresh_file ]]; then
    last_refresh=$(<"$last_refresh_file")
    if [[ $last_refresh =~ ^[0-9]+$ ]] && (( now - last_refresh < 400000000 )); then
      printf '%s\n' "$now" >"$last_refresh_file"
      return
    fi
  fi
  printf '%s\n' "$now" >"$last_refresh_file"
  payload=$("$config_dir/scripts/system-state.py" "$provider")
  eww --force-wayland --config "$config_dir" update "$variable=$payload" >/dev/null 2>&1 || true
  if [[ $domain == audio ]]; then
    pkill -RTMIN+8 -x waybar 2>/dev/null || pkill -RTMIN+8 -x .waybar-wrapped 2>/dev/null || true
  fi
}

case "$domain:$action" in
  audio:volume)
    value=${1:-0}
    [[ $value =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 2
    target=$(audio_target)
    [[ -n $target ]] || exit 1
    wpctl set-volume "$target" "${value}%" --limit 1.0
    ;;
  audio:mute)
    target=$(audio_target)
    [[ -n $target ]] || exit 1
    wpctl set-mute "$target" toggle
    ;;
  audio:settings)
    pavucontrol >/dev/null 2>&1 &
    ;;
  audio:anc)
    nothing_cli anc "${1:-smart-1}" >/dev/null
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/nothing-headphones-status.json"
    ;;
  audio:eq)
    nothing_cli eq "${1:-balanced}" >/dev/null
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/nothing-headphones-status.json"
    ;;
  audio:spatial)
    nothing_cli spatial "${1:-off}" >/dev/null
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/nothing-headphones-status.json"
    ;;

  bluetooth:power)
    current=$(bluetoothctl show | sed -n 's/^\s*Powered: //p')
    bluetoothctl power "$([[ $current == yes ]] && printf off || printf on)" >/dev/null
    ;;
  bluetooth:scan)
    current=$(bluetoothctl show | sed -n 's/^\s*Discovering: //p')
    bluetoothctl scan "$([[ $current == yes ]] && printf off || printf on)" >/dev/null
    ;;
  bluetooth:device)
    mac=${1:-}
    [[ $mac =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || exit 2
    if bluetoothctl devices Connected | grep -Fq "Device $mac "; then
      bluetoothctl disconnect "$mac" >/dev/null
    else
      bluetoothctl connect "$mac" >/dev/null
    fi
    ;;
  bluetooth:settings)
    blueman-manager >/dev/null 2>&1 &
    ;;

  network:power)
    current=$(nmcli -t -f WIFI g)
    nmcli radio wifi "$([[ $current == enabled ]] && printf off || printf on)"
    ;;
  network:rescan)
    nmcli device wifi rescan
    ;;
  network:connect)
    ssid=$(decode_hex "${1:-}")
    [[ -n $ssid ]] || exit 2
    if nmcli -t -f NAME,TYPE connection show | grep -Fq "${ssid}:802-11-wireless"; then
      nmcli connection up id "$ssid"
    else
      nm-connection-editor >/dev/null 2>&1 &
    fi
    ;;
  network:disconnect)
    connection=$(decode_hex "${1:-}")
    [[ -n $connection ]] && nmcli connection down id "$connection"
    ;;
  network:settings)
    nm-connection-editor >/dev/null 2>&1 &
    ;;

  workspaces:switch)
    workspace=${1:-}
    [[ $workspace =~ ^[0-9]+$|^[[:alnum:]_-]+$ ]] || exit 2
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$workspace\" })" >/dev/null
    ;;

  power:brightness)
    value=${1:-0}
    [[ $value =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 2
    brightnessctl set "${value}%" >/dev/null
    ;;
  power:profile)
    profile=${1:-balanced}
    case "$profile" in performance|balanced|power-saver) tlpctl set "$profile" ;; *) exit 2 ;; esac
    ;;
  power:idle)
    "$HOME/.config/hypr/scripts/caffinate.sh"
    ;;
  power:lock)
    hyprlock >/dev/null 2>&1 &
    ;;
  power:suspend)
    systemctl suspend
    ;;
  power:logout)
    hyprctl dispatch exit
    ;;
  power:reboot)
    systemctl reboot
    ;;
  power:shutdown)
    systemctl poweroff
    ;;
  notifications:open)
    swaync-client -t -sw
    ;;
  notifications:dnd)
    swaync-client -d -sw
    ;;
  notifications:clear)
    swaync-client -C
    ;;
  *)
    printf 'Unknown widget action: %s %s\n' "$domain" "$action" >&2
    exit 2
    ;;
esac

refresh_widget_state
