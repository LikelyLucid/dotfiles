# Desktop design system

The desktop is a quiet, information-first workstation. It should feel composed
rather than decorated: one accent, consistent geometry, short motion, and no
surface that exposes how the system is assembled.

## Color

Wallust is the only palette authority. Application themes must consume semantic
roles generated from the current wallpaper; application configuration must not
contain literal palette hex values.

| Role | Wallust source | Use |
| --- | --- | --- |
| Canvas | `background` / `color0` | Desktop panels and deep surfaces |
| Surface | `color0` with controlled alpha | Bar modules, cards, menus |
| Text | `foreground` / `color15` | Primary labels and content |
| Muted | `color8` | Secondary text, inactive states, quiet borders |
| Accent | `color7` or app-mapped `color4` | Selection, focus, current state |
| Urgent | `color1` or app-mapped `color3` | Errors and states requiring attention |

The mappings are translated per toolkit by templates in `wallust/templates/`:

- Waybar: `colors-wallust.css`
- Rofi: `colors-rofi.rasi`
- SwayNC: `swaync.css.tmpl`
- Hyprland and Hyprlock: `hyprland-colors.conf` and
  `hyprlock-colors.conf`
- GTK: `gtk-colors.css`
- Ghostty, tmux, Neovim, and Spotify Player: their respective templates

Wallust contrast checking remains enabled. A wallpaper is unsuitable if the
result still obscures text or state after contrast correction.

## Typography

- **JetBrains Mono** is the single interface and utility face: launcher, status
  bar, notifications, GTK, terminal, editor, lock screen, labels, and prose.
- **JetBrains Mono Nerd Font** is the glyph-compatible variant used where icon
  codepoints appear. It is not a separate visual voice.
- Normal interface text is 11–13 px. Use weight 500 for controls and 700 only
  for the current or primary state.

## Geometry

Use a 4 px base rhythm:

- 4 px: compact internal separation
- 8 px: normal control padding
- 12 px: panel grouping
- 18 px: compositor breathing room

Interactive surfaces use a 7 px radius. Large shells may use 10 px. Tiny
switches and indicators may use 3–4 px. Window rounding remains 8 px so
applications and desktop chrome read as one family.

## Motion

Motion explains state; it does not decorate it.

- Control transitions: 140–160 ms
- Windows: the configured Hyprland ease-out curves
- No perpetual ambient animation outside media visualization
- Avoid stacking blur, transparency, gradients, and animation on one surface

## Interaction

- Left click performs the obvious action.
- Right click opens details or advanced controls.
- Scroll adjusts continuous values such as volume or brightness.
- Labels describe what the user controls, not the daemon or package involved.
- A feature must have one owner and one lifecycle. Prefer systemd services over
  compositor-spawned background processes.

## Quality gate

Before committing a visual change:

1. Regenerate the palette with the current wallpaper.
2. Validate the application's configuration parser.
3. Run `scripts/check-design-system.sh` to reject literal palette values and
   typography drift in authored themes.
4. Capture the live desktop with Grim and inspect spacing, contrast, clipping,
   and competing accents.
5. Confirm keyboard focus and the reduced-motion path remain usable.
