#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
nix_repo=${NIXOS_CONFIG_DIR:-/home/lucid/nixos}

mapfile -t theme_files < <(
  printf '%s\n' \
    "$repo/rofi/config.rasi" \
    "$repo/waybar/style.css"
  find "$repo/wallust/templates" -maxdepth 1 -type f -print | sort
)

if grep -HEn '#[[:xdigit:]]{6,8}\b|rgba?\([[:space:]]*[0-9]' "${theme_files[@]}"; then
  echo "error: authored themes must use Wallust color roles, not literal colors" >&2
  exit 1
fi

if grep -HwIn 'Inter' "${theme_files[@]}" "$repo/DESIGN.md"; then
  echo "error: JetBrains Mono is the desktop typeface" >&2
  exit 1
fi

if ! grep -q 'JetBrains Mono' "$repo/DESIGN.md"; then
  echo "error: DESIGN.md must document the desktop typeface" >&2
  exit 1
fi

hyprland_config="$nix_repo/modules/window-manager/hyprland-config.nix"
if [[ -f $hyprland_config ]] && grep -HEn 'rgba\([[:xdigit:]]+' "$hyprland_config"; then
  echo "error: Hyprland colors must come from the generated Wallust config" >&2
  exit 1
fi

echo "design system check passed"
