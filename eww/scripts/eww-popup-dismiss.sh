#!/usr/bin/env bash
set -euo pipefail

window=${1:?window is required}
namespace=${2:?namespace is required}
token=${3:?token is required}
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/eww
runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
token_file=$runtime_dir/eww-popup-${window}.token
enter_timeout_tenths=${EWW_POPUP_ENTER_TIMEOUT_TENTHS:-25}
leave_samples=${EWW_POPUP_LEAVE_SAMPLES:-3}

is_current() {
  [[ -r $token_file ]] && [[ $(<"$token_file") == "$token" ]]
}

layer_geometry() {
  hyprctl layers -j 2>/dev/null | jq -r --arg namespace "$namespace" '
    first(to_entries[] | .value.levels[][] | select(.namespace == $namespace))
    | if . then [.x, .y, .w, .h] | @tsv else empty end
  ' 2>/dev/null
}

entered=false
outside_count=0
waited=0

while is_current; do
  geometry=$(layer_geometry)
  if [[ -z $geometry ]]; then
    # Give a newly opened layer a brief opportunity to appear. Once entered,
    # a missing layer means it was closed elsewhere and the watcher is done.
    [[ $entered == true ]] && exit 0
    ((waited++)) || true
    ((waited >= enter_timeout_tenths)) && exit 0
    sleep 0.1
    continue
  fi

  read -r x y width height <<<"$geometry"
  cursor=$(hyprctl cursorpos 2>/dev/null || printf '0,0')
  cursor=${cursor//[[:space:]]/}
  IFS=, read -r cursor_x cursor_y <<<"$cursor"

  if ((cursor_x >= x && cursor_x < x + width && cursor_y >= y && cursor_y < y + height)); then
    entered=true
    outside_count=0
  elif [[ $entered == true ]]; then
    ((outside_count++)) || true
    if ((outside_count >= leave_samples)); then
      eww --force-wayland --config "$config_dir" close "$window" >/dev/null 2>&1 || true
      exit 0
    fi
  else
    ((waited++)) || true
    if ((waited >= enter_timeout_tenths)); then
      eww --force-wayland --config "$config_dir" close "$window" >/dev/null 2>&1 || true
      exit 0
    fi
  fi
  sleep 0.1
done
