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

Waybar popups use one interaction contract: click the module to open it, move
into the popup, and it closes automatically after the pointer leaves for a
short grace period. Opening one popup closes related popups; clicking the module
again still toggles it closed. The shared watcher waits for pointer entry before
arming leave dismissal, avoiding the immediate-close race caused by Eww's
`unfocus-close` and `onhoverlost`. A popup that is never entered closes after a
short fallback timeout, and content popups may also retain a bounded
`--duration` fallback.

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
Successful actions push fresh provider data directly into Eww, so controls do
not wait for their fallback polling interval. Nothing-headphone actions also
invalidate the shared status cache before refreshing. When `nothing-headphonesd`
is available, Eww and Waybar share its single persistent RFCOMM connection;
the serialized one-shot CLI path remains as a fallback when the broker is not
running.
The shared position helper clamps every popup inside its click monitor with a
20px horizontal safety inset, including modules at either end of Waybar.

Waybar now opens these launchers from audio, Wi-Fi, Bluetooth, backlight,
battery, caffeine, and notifications. Workspace buttons retain their normal
left-click switching behavior and open the workspace panel on right click.
Existing secondary actions remain available on right click where applicable.

- **Audio:** live volume and mute controls. When Nothing Headphone (1) is
  connected, the slider targets its PipeWire sink instead of the default sink
  and exposes battery, a three-state Off/Transparency/ANC selector, EQ, and
  spatial-audio controls.
- **Bluetooth:** adapter power/scanning controls, paired-device status and
  individual battery levels when BlueZ reports them, direct connect/disconnect,
  and Blueman settings.
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

## Unified desktop shell

`widgets/shell.yuck` adds one `control_center_popup` behind Waybar's
`custom/control-center` button while preserving every module-specific popup.
Its five pages compose the existing adapters rather than duplicating them:

- **Home:** unified Quick Settings, volume and brightness sliders, and an
  at-a-glance route into the deeper surfaces.
- **Devices:** Nothing headphones, audio mixer entry, microphone/camera privacy,
  and Bluetooth device controls.
- **Activity:** SwayNC, multi-player media, enhanced agenda links/progress,
  focus sessions, downloads, and create-event actions.
- **System:** health, monitors/appearance, night light, detailed networking,
  Tailscale/VPN state, storage, and read-only NixOS state. Destructive NixOS and
  power controls remain disabled pending review.
- **Tools:** searchable-source clipboard entries, window overview, screenshot
  history, Kubernetes/local-service status, optional weather, and OpenHue setup
  state.

The shell's deep state seam is `scripts/shell-state.py`; optional providers
return explicit unavailable/setup states rather than breaking the popup. The
action seam is `scripts/shell-action.sh`, with dynamic identifiers encoded
before entering Yuck command strings.
