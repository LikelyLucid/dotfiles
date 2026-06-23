#!/usr/bin/env bash

ignored='^(firefox|firefox-esr|zen|helium|chromium|google-chrome|brave)(\.|$)'

has_music_player() {
  playerctl -l 2>/dev/null | grep -Eiv "$ignored" | grep -q .
}

cfg="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava.conf"
cat >"$cfg" <<'EOF'
[general]
bars = 14
framerate = 30

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 0

[smoothing]
noise_reduction = 77
EOF

while true; do
  if ! has_music_player; then
    echo
    sleep 1
    continue
  fi

  cava -p "$cfg" 2>/dev/null | tr -d '\000' | awk 'BEGIN{b["0"]="▁";b["1"]="▂";b["2"]="▃";b["3"]="▄";b["4"]="▅";b["5"]="▆";b["6"]="▇";b["7"]="█"} {out=""; for(i=1;i<=length($0);i++) out=out b[substr($0,i,1)]; print out; fflush()}' | while IFS= read -r line; do
    has_music_player || break
    printf '%s\n' "$line"
  done

  sleep 0.2
done
