#!/usr/bin/env bash
set -euo pipefail

cli_command=${NOTHING_CLI_COMMAND:-nothing-cli}
if [[ "$cli_command" == nothing-cli ]] && ! command -v nothing-cli >/dev/null 2>&1; then
  local_cli=/home/lucid/Projects/Nothing-cli/.release-venv/bin/nothing-cli
  [[ -x "$local_cli" ]] && cli_command=$local_cli
fi

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
lock_file=$runtime_dir/nothing-headphones-cli.lock
script_lock=$runtime_dir/nothing-headphones-script.lock
status_cache=$runtime_dir/nothing-headphones-status.json
status_cache_ttl=10

run_cli() {
  flock --exclusive "$lock_file" "$cli_command" "$@"
}

refresh_waybar() {
  pkill -RTMIN+8 -x waybar 2>/dev/null || pkill -RTMIN+8 -x .waybar-wrapped 2>/dev/null || true
}

show_menu() {
  local prompt=$1
  shift
  printf '%s\n' "$@" | rofi -dmenu -i -p "$prompt"
}

set_setting() {
  local attempt broker_status
  if "$cli_command" broker set "$@" >/dev/null 2>&1; then
    rm -f "$status_cache"
    refresh_waybar
    return 0
  else
    broker_status=$?
  fi
  (( broker_status == 2 )) || return "$broker_status"
  for attempt in 1 2 3 4 5 6 7 8; do
    if run_cli "$@" >/dev/null 2>&1; then
      rm -f "$status_cache"
      refresh_waybar
      return 0
    fi
    sleep 0.75
  done
  return 1
}

headphones_connected() {
  bluetoothctl devices Connected 2>/dev/null | grep -qi 'nothing headphone'
}

volume_state() {
  local volume_info volume muted icon
  volume_info=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
  volume=$(awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+\.[0-9]+$/) { printf "%d", $i * 100; exit } }' <<<"$volume_info")
  volume=${volume:-0}
  muted=false
  if grep -q '\[MUTED\]' <<<"$volume_info"; then
    muted=true
    icon='󰝟'
  elif (( volume < 34 )); then
    icon='󰕿'
  elif (( volume < 67 )); then
    icon='󰖀'
  else
    icon='󰕾'
  fi
  printf '%s\t%s\t%s\n' "$volume" "$muted" "$icon"
}

pretty_value() {
  case "$1" in
    true) printf 'On' ;;
    false) printf 'Off' ;;
    *) printf '%s' "$1" | sed -E 's/(^|-)\w/\U&/g; s/-/ /g' ;;
  esac
}

emit_disconnected_audio() {
  local volume muted icon
  IFS=$'\t' read -r volume muted icon < <(volume_state)
  local tooltip
  tooltip=$(printf 'Volume: %s%%%s\n\nLeft click: mute / unmute\nScroll: adjust volume' \
    "$volume" "$([[ "$muted" == true ]] && printf ' (muted)')")
  jq -cn \
    --arg text "$icon $volume%" \
    --arg tooltip "$tooltip" \
    '{text: $text, tooltip: $tooltip, class: "disconnected", alt: "volume"}'
}

status_cache_is_valid() {
  [[ -r "$status_cache" ]] && jq -e '.noise_control.mode' >/dev/null <"$status_cache"
}

status_cache_is_fresh() {
  local cache_mtime current_time
  cache_mtime=$(stat -c '%Y' "$status_cache" 2>/dev/null) || return 1
  current_time=$(date +%s)
  (( current_time - cache_mtime < status_cache_ttl ))
}

case ${1:-audio} in
  volume-up)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0
    refresh_waybar
    exit 0
    ;;
  volume-down)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    refresh_waybar
    exit 0
    ;;
esac

exec 9>"$script_lock"
flock --exclusive 9

if ! headphones_connected; then
  case ${1:-audio} in
    audio)
      emit_disconnected_audio
      ;;
    audio-click)
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      refresh_waybar
      ;;
    audio-settings)
      pavucontrol >/dev/null 2>&1 &
      ;;
    *)
      printf '%s\n' '{"text":"","class":"disconnected","tooltip":"Nothing Headphone (1) disconnected"}'
      ;;
  esac
  exit 0
fi

status=''
broker_status=0
if candidate=$("$cli_command" --json broker status 2>/dev/null); then
  if jq -e '.noise_control.mode' >/dev/null <<<"$candidate"; then
    status=$candidate
    printf '%s\n' "$status" >"$status_cache"
  fi
else
  broker_status=$?
fi
if [[ -z "$status" ]] && (( broker_status != 2 )) && status_cache_is_valid; then
  status=$(<"$status_cache")
elif [[ -z "$status" ]] && (( broker_status == 2 )) && status_cache_is_valid && status_cache_is_fresh; then
  status=$(<"$status_cache")
elif [[ -z "$status" ]] && (( broker_status == 2 )) && candidate=$(run_cli --json status 2>/dev/null) && jq -e '.noise_control.mode' >/dev/null <<<"$candidate"; then
  status=$candidate
  printf '%s\n' "$status" >"$status_cache"
elif [[ -z "$status" ]] && status_cache_is_valid; then
  status=$(<"$status_cache")
fi

if [[ -z "$status" ]]; then
  printf '%s\n' '{"text":"󰋋 0%","class":"headphones","tooltip":"Nothing Headphone (1) connected; status unavailable"}'
  exit 0
fi

mode=$(jq -r '.noise_control.mode // "unknown"' <<<"$status")
if [[ "$mode" == smart-1 ]]; then
  mode_label=ANC
else
  mode_label=$(pretty_value "$mode")
fi

battery=$(jq -r 'if .battery.percent == null then "Unknown" else (.battery.percent | tostring) + "%" end' <<<"$status")
eq=$(pretty_value "$(jq -r '.eq.value // "Unknown"' <<<"$status")")
spatial=$(pretty_value "$(jq -r '.spatial_audio.mode // "Unknown"' <<<"$status")")
low_latency=$(pretty_value "$(jq -r '.low_latency.value // "Unknown"' <<<"$status")")
dual_connection=$(pretty_value "$(jq -r '.dual_connection.value // "Unknown"' <<<"$status")")
bass=$(jq -r 'if .bass_boost.enabled == true then "Level " + ((.bass_boost.level // "?") | tostring) else "Off" end' <<<"$status")
wear_detection=$(pretty_value "$(jq -r '.features.values.wear_detection // "Unknown"' <<<"$status")")

case "$mode" in
  smart-1)
    state_icon='󰋋'
    class=anc
    ;;
  transparency)
    state_icon='󰖝'
    class=transparency
    ;;
  *)
    state_icon='󰋋'
    class=headphones
    ;;
esac

volume_status=$(volume_state)
IFS=$'\t' read -r volume muted volume_icon <<<"$volume_status"

toggle_mode() {
  if [[ "$mode" == transparency ]]; then
    set_setting anc smart-1
  else
    set_setting anc transparency
  fi
}

anc_menu() {
  local choice
  choice=$(show_menu 'ANC modes' \
    'ANC' \
    'ANC high' \
    'ANC mid' \
    'ANC low' \
    'Smart 2' \
    'Off' \
    'Comfortable' \
    'Transparency')

  case "$choice" in
    ANC) set_setting anc smart-1 ;;
    'ANC high') set_setting anc anc-high ;;
    'ANC mid') set_setting anc anc-mid ;;
    'ANC low') set_setting anc anc-low ;;
    'Smart 2') set_setting anc smart-2 ;;
    Off) set_setting anc off ;;
    Comfortable) set_setting anc comfortable ;;
    Transparency) set_setting anc transparency ;;
  esac
}

bass_menu() {
  local choice
  choice=$(show_menu 'Bass boost' \
    'Off' \
    'Level 1' \
    'Level 2' \
    'Level 3' \
    'Level 4' \
    'Level 5')

  case "$choice" in
    Off) set_setting bass-boost off ;;
    'Level 1') set_setting bass-boost 1 ;;
    'Level 2') set_setting bass-boost 2 ;;
    'Level 3') set_setting bass-boost 3 ;;
    'Level 4') set_setting bass-boost 4 ;;
    'Level 5') set_setting bass-boost 5 ;;
  esac
}

eq_menu() {
  local choice
  choice=$(show_menu 'EQ presets' \
    Balanced \
    Voice \
    Treble \
    Bass \
    Dirac \
    Custom \
    'New Voice' \
    Instrument)

  case "$choice" in
    Balanced) set_setting eq balanced ;;
    Voice) set_setting eq voice ;;
    Treble) set_setting eq treble ;;
    Bass) set_setting eq bass ;;
    Dirac) set_setting eq dirac ;;
    Custom) set_setting eq custom ;;
    'New Voice') set_setting eq new-voice ;;
    Instrument) set_setting eq instrument ;;
  esac
}

spatial_menu() {
  local choice
  choice=$(show_menu 'Spatial audio' \
    'Off' \
    Fixed \
    'Head tracking')

  case "$choice" in
    Off) set_setting spatial off ;;
    Fixed) set_setting spatial fixed ;;
    'Head tracking') set_setting spatial head-tracking ;;
  esac
}

other_menu() {
  local choice
  choice=$(show_menu 'Other settings' \
    'Wear detection on' \
    'Wear detection off' \
    'Low latency on' \
    'Low latency off' \
    'Dual connection on' \
    'Dual connection off')

  case "$choice" in
    'Wear detection on') set_setting wear-detection on ;;
    'Wear detection off') set_setting wear-detection off ;;
    'Low latency on') set_setting low-latency on ;;
    'Low latency off') set_setting low-latency off ;;
    'Dual connection on') set_setting dual-connection on ;;
    'Dual connection off') set_setting dual-connection off ;;
  esac
}

settings_menu() {
  local category
  category=$(show_menu 'Nothing settings' \
    'ANC modes' \
    'Bass boost' \
    'EQ presets' \
    'Spatial audio' \
    'Other settings')

  case "$category" in
    'ANC modes') anc_menu ;;
    'Bass boost') bass_menu ;;
    'EQ presets') eq_menu ;;
    'Spatial audio') spatial_menu ;;
    'Other settings') other_menu ;;
  esac
}

case ${1:-status} in
  audio-click)
    toggle_mode
    exit 0
    ;;
  audio-settings|settings)
    settings_menu
    exit 0
    ;;
  toggle)
    toggle_mode
    exit 0
    ;;
esac

tooltip=$(printf 'Noise control: %s\nBattery: %s\nEQ: %s\nSpatial audio: %s\nBass boost: %s\nWear detection: %s\nLow latency: %s\nDual connection: %s\n\nLeft click: toggle ANC / Transparency\nScroll: adjust volume\nRight click: open settings' \
  "$mode_label" "$battery" "$eq" "$spatial" "$bass" "$wear_detection" "$low_latency" "$dual_connection")

jq -cn \
  --arg text "$state_icon $volume%" \
  --arg tooltip "$tooltip" \
  --arg class "$class" \
  --arg alt "$mode" \
  '{text: $text, tooltip: $tooltip, class: $class, alt: $alt}'
