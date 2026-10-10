# Better Displays

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/better.displays`](https://github.com/nightdevil00/Plugins/better.displays/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh better.displays
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`better.displays`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/better.displays ~/.config/omarchy/plugins/better.displays
omarchy-shell shell rescanPlugins
omarchy plugin enable better.displays
```


## Features

- **Layout canvas** — the panel draws your displays as rectangles at their
  real relative positions. Drag one to move it onto another (left, right,
  above, or below) and it snaps flush; click to select, right-click to cycle
  rotation. A ghost outline previews the landing spot while you drag.
- **Per-monitor** resolution (real modes reported by the monitor), scale,
  position, and orientation (0°/90°/180°/270°).
- **Per-terminal font size** for alacritty, kitty, ghostty, and foot, with
  live − / + steppers.
- All changes apply **live** via Hyprland and **persist** to
  `~/.config/omarchy/displays.json` and `~/.config/hypr/monitors.lua` (so they
  survive a reboot).
- A matching `omarchy display ...` CLI group and an interactive Display menu
  submenu (the scripts are installed onto `PATH` automatically).

## Requirements

- Omarchy (Hyprland-based) with the Quickshell shell.
- `bash` and `jq` (both standard on Omarchy).
- `hyprctl` (provided by Hyprland).

## Install

### Using the bundled installer

See [Installing](#installing) above — `./install.sh better.displays` copies the
plugin into place and enables the bar widget. When the
shell loads the plugin it **auto-installs the backend scripts** onto `PATH`
(`~/.local/bin`, falling back to `/usr/local/bin`), so the `omarchy display`
CLI group and the Display menu submenu work immediately. No manual step needed.

### Manual

```bash
cp -r Plugins/better.displays ~/.config/omarchy/plugins/better.displays
cd ~/.config/omarchy/plugins/better.displays
./install                 # symlink the backend scripts into ~/.local/bin
omarchy plugin enable better.displays
omarchy restart shell
```

## Use it

- Click the **Better Displays** icon in the bar (next to the monitor icon), or
  summon it: `omarchy-shell shell summon better.displays`.
- **Drag** a display rectangle in the LAYOUT canvas to move it next to
  another display. A dashed outline shows where it will land. **Click** a
  rectangle to select it, **right-click** to rotate it 90°.
- Adjust Resolution / Scale / Orientation for the selected monitor, and tune
  each terminal's font size.

CLI equivalents (interactive shell):

```bash
omarchy display monitor list
omarchy display monitor set DP-1 --mode 2560x1440@144 --scale 1.6 --pos 0x0 --transform 0
omarchy display layout read
omarchy display layout apply --json '[{"output":"HDMI-A-1","position":"0x0","scale":1},{"output":"eDP-1","position":"1920x0","scale":1}]'
omarchy display terminal list
omarchy display terminal set ghostty 14
omarchy display terminal set-all 13
```

`omarchy display layout` is the batched entry point the panel's drag/rotate
gestures use. It rewrites the whole block of `hl.monitor(...)` lines in
`~/.config/hypr/monitors.lua` **in the order the panel shows them**, which
`omarchy display monitor set` cannot do (it only replaces one output's line).
Any `mode`, `position`, `scale`, or `transform` left out of an entry keeps the
value the file already has, so dragging a display never rewrites
`mode = "preferred"` into a hardcoded refresh rate.

## Uninstall

```bash
~/.config/omarchy/plugins/better.displays/uninstall   # drop the PATH symlinks
omarchy plugin remove better.displays
```

(`uninstall` removes the `omarchy-display-*` symlinks; `omarchy plugin remove`
deletes the plugin folder. Order does not matter, but run both for a clean
removal.)

## How it works

The plugin folder bundles everything it needs:

```
better.displays/
├── manifest.json        # plugin metadata (bar-widget)
├── Panel.qml            # the bar widget + popup (reuses Omarchy's qs.Ui kit)
├── bin/                 # backend scripts (self-contained, travel with the plugin)
│   ├── omarchy-display-layout
│   ├── omarchy-display-monitor
│   ├── omarchy-display-terminal
│   └── omarchy-display-pick
├── install              # symlink bin/* into ~/.local/bin (idempotent)
├── uninstall            # remove those symlinks
├── preview.png
└── README.md
```

`Panel.qml` invokes the scripts by their absolute path inside `bin/`, so the
widget works the moment the folder is present — the `install` step only exists
to expose the `omarchy display` CLI / menu.

## How monitors.lua is rewritten

`omarchy-display-layout apply` regenerates the `hl.monitor(...)` lines while
preserving **everything else in the file byte-for-byte**: header comments,
`local omarchy_monitor_scale` declarations, `hl.env()` calls, and even
commented-out `hl.monitor` examples, which are documentation and must survive.

The output order follows the order the panel draws the displays (rows by
vertical centre, then columns within a row), and an Omarchy catch-all
`hl.monitor({ output = "", ... })` line is re-emitted first. A name-specific
rule always beats the catch-all in Hyprland, so precedence stays correct.
Monitors present in the file but absent from the incoming list keep their own
line, so a batch apply can never silently delete a display's configuration.
One backup of the pre-first-write file is kept as `monitors.lua.bak`.

Set `BETTER_DISPLAYS_MONITORS_LUA=/path/to/file` to rehearse the rewrite
against a scratch file instead of the real one.

## Security

The plugin receives monitor names, mode strings, positions, and scale values
from Hyprland (`hyprctl monitors -j`) and passes them through several layers:

**Panel.qml** — constructs `bash -c` commands to call the backend scripts. All
interpolated values (monitor name, flags, terminal names, sizes) are wrapped
with `shellEscape()` which quotes each argument with single quotes and escapes
any embedded single quotes, preventing shell metacharacter injection.

**omarchy-display-monitor** —

| Concern | Mitigation |
| --- | --- |
| Monitor name in jq filter | `jq --arg` used instead of string interpolation, so names cannot break out of the filter expression |
| Values embedded in Lua expressions (`hyprctl eval`, `monitors.lua`) | All inputs validated against strict regex patterns **before** use: output names match `[a-zA-Z0-9_-]+(:[a-zA-Z0-9_-]+)?`, modes match `WxH@R[Hz]` (or the `preferred`/`highres`/`highrr` tokens), positions match `XxY` or Hyprland's `auto`/`auto-*` placements, scales are numeric, transforms are `0`–`3`. String values are also run through `lua_escape()` which escapes `\` and `"` for safe Lua double-quote embedding |
| Values used in grep/awk patterns | `persist_to_lua` uses the same `lua_escape()` output in its grep regex and awk `-v` assignments |

**omarchy-display-layout** — takes the same validated fields as a JSON array,
so a single batch can carry the whole layout. It rejects non-arrays, empty
arrays, and duplicate output names. The rewrite itself never trusts the input
to be Lua: every interpolated value goes through `lua_escape()` and the
scale/transform (which must stay unquoted for Lua to read them as numbers)
are validated as numeric first. Two-mode parsing splits `output = "name"` from
bare values such as `scale = omarchy_monitor_scale`, so a monitor line that
shares a `local` at the top of the file keeps sharing it after a rewrite.

**omarchy-display-terminal** — validates that the terminal name is one of the
known set (`alacritty`, `kitty`, `ghostty`, `foot`) via a whitelist check and
that the font size is numeric (`^[0-9]+(\.[0-9]+)?$`).

## License

MIT — do what you like, attribute if you're feeling generous.
