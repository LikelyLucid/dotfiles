#!/usr/bin/env bash
# swaync do-not-disturb toggle & waybar widget

state=$(swaync-client -D)

if [ "$1" = "toggle" ]; then
	state=$(swaync-client -d)
fi

if [ "$state" = "true" ]; then
	echo '{"text": "󰂛", "alt": "activated", "class": "activated", "tooltip": "Do Not Disturb: ON"}'
else
	echo '{"text": "󰂚", "alt": "deactivated", "class": "deactivated", "tooltip": "Do Not Disturb: OFF"}'
fi
