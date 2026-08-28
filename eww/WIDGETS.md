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
popup, and opening one popup closes related popups. Do not add `unfocus-close`
unless focus acquisition has been verified on every output; the Waybar launch
path can otherwise close a new layer before it receives focus.
