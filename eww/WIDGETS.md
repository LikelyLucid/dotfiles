# Eww widget system

This directory exposes a small shared interface for Waybar popups. New widgets
should compose the existing primitives and semantic tokens rather than creating
a new visual language.

## Structure

- `eww.yuck` includes widget modules.
- `widgets/primitives.yuck` owns reusable Yuck interfaces.
- `widgets/<feature>.yuck` owns one feature's state, content, and windows.
- `styles/_tokens.scss` maps the Wallust palette to semantic UI roles.
- `styles/_primitives.scss` owns shared shells, headers, rows, actions, lists,
  media, empty states, and scrollbars.
- `styles/_<feature>.scss` contains only the feature-specific remainder.
- `scripts/eww-popup-open.sh` is the single popup lifecycle and positioning
  interface used by Waybar launchers.

## Shared Yuck interfaces

- `ui_header`: eyebrow, title, subtitle, and right-aligned metadata.
- `ui_section_header`: section label and optional status.
- `ui_icon_action`: icon button with command, tooltip, and optional class
  (`is-primary` for the one emphasized action).
- `ui_link_row`: content-width navigation or selection row.

Use `ui-surface ui-popup` on every popup root. Prefer `ui-inset`, `ui-muted`,
`ui-empty`, `ui-scroll`, `ui-list`, and `ui-media` before adding a feature class.

## Adding a widget

1. Create `widgets/<name>.yuck` and `styles/_<name>.scss`.
2. Add both imports to `eww.yuck` and `components.scss`.
3. Build the popup from shared interfaces; keep the feature stylesheet limited
   to layout or states unique to that widget.
4. Add a tiny launcher calling `scripts/eww-popup-open.sh` with width, height,
   competing windows to close, and the normal dynamic monitor behavior.
5. Add the launcher to the relevant Waybar module.
6. Reload and test with the literal live config path:

   ```bash
   config=/home/lucid/.config/eww
   eww --force-wayland --config "$config" reload
   "$config/scripts/<name>-popup.sh"
   eww --force-wayland --config "$config" active-windows
   hyprctl layers -j
   ```

For a Nothing headphones popup, the feature module should only need its state
poll, device-specific controls, and any unique battery/ANC presentation. The
shell, header, action buttons, settings rows, status labels, scroll behavior,
monitor selection, and Wallust styling are already provided.

Waybar popups use one interaction contract: click the module to toggle its
popup, and opening one popup closes related popups. Content popups may also use
a bounded `--duration` fallback. Do not add `unfocus-close` or `onhoverlost`
unless focus and pointer entry have been verified on every output; the Waybar
launch path can otherwise close a new layer immediately after opening it.

## System-widget launchers

Open one module directly with:

```bash
~/.config/eww/scripts/widget-preview.sh audio
~/.config/eww/scripts/widget-preview.sh bluetooth
~/.config/eww/scripts/widget-preview.sh wifi
~/.config/eww/scripts/widget-preview.sh workspaces
~/.config/eww/scripts/widget-preview.sh power
~/.config/eww/scripts/widget-preview.sh notifications
```

Every preview uses the same dynamic monitor positioning and closes competing
Eww previews. The shared state seam is `scripts/system-state.py <domain>` and
the action seam is `scripts/system-action.sh <domain> <action> [value]`.

Waybar now opens these launchers from audio, Wi-Fi, Bluetooth, backlight,
battery, caffeine, and notifications. Workspace buttons retain their normal
left-click switching behavior and open the workspace panel on right click.
Existing secondary actions remain available on right click where applicable.

- **Audio:** live volume and mute controls. When Nothing Headphone (1) is
  connected, the slider targets its PipeWire sink instead of the default sink
  and exposes battery, ANC/transparency, EQ, and spatial-audio controls.
- **Bluetooth:** adapter power/scanning controls, paired-device status, direct
  connect/disconnect, and Blueman settings.
- **Wi-Fi:** radio and rescan controls, available/known network status, safe
  known-profile connect/disconnect, and NetworkManager setup for new networks.
- **Workspaces:** live Hyprland workspace/window/output state and switching.
- **Power:** battery status, brightness slider, TLP profile selection,
  idle/caffeine state, lock, suspend, logout, reboot, and shutdown.
- **Notifications:** count/DND state plus notification-center, DND, and clear
  actions through SwayNC.

Spotify and calendar remain the existing active feature modules. The system
tray is not duplicated because it is an application-owned StatusNotifier host,
not a single control surface; notification history remains owned by SwayNC.
