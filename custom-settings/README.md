# Omarchy Settings

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/custom-settings`](https://github.com/nightdevil00/Plugins/custom-settings/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh custom-settings
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`nightdevil00.custom-settings`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/custom-settings ~/.config/omarchy/plugins/nightdevil00.custom-settings
omarchy-shell shell rescanPlugins
omarchy plugin enable nightdevil00.custom-settings
```


## Screenshots

| | |
|---|---|
| ![Appearance](screenshots/appearance.png) | ![Window](screenshots/window.png) |
| ![Motion](screenshots/motion.png) | ![Input](screenshots/input.png) |
| ![Display](screenshots/display.png) | ![Bar & Plugins](screenshots/bar&plugins.png) |
| ![Idle & Lock](screenshots/idle.png) | ![Night Light](screenshots/night_light.png) |
| ![Updates](screenshots/updates.png) | ![About](screenshots/about.png) |

## Install

With the Omarchy CLI (recommended):

```sh
omarchy plugin enable nightdevil00.custom-settings
```

Or copy it from a clone:

```sh
cp -r Plugins/custom-settings ~/.config/omarchy/plugins/nightdevil00.custom-settings
```

Then run `omarchy-shell shell rescanPlugins` and `omarchy plugin enable nightdevil00.custom-settings`, or restart the shell.

No `sudo` is involved: plugins load from `~/.config/omarchy/plugins`, which the shell watches. Removing is `omarchy plugin remove nightdevil00.custom-settings`.

## Using it

- **Bar gear** — click to open the panel. `Esc` or the window close button closes it; the shell tracks the open state so `toggle` stays correct.
- **CLI / keybind** — `omarchy-shell shell toggle nightdevil00.custom-settings '{}'` (or `summon` / `hide`).
- **Menu** — add an action entry to `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"settings": {
  "icon": "󰒓",
  "label": "Settings",
  "description": "Open the Omarchy settings panel",
  "action": "omarchy-shell shell toggle nightdevil00.custom-settings '{}'"
}
```

## How it works

Three models, one loop.

```
                      read                          write
  hyprctl -j getoption ──► SettingsStore ◄── controls ──► managed{}
  omarchy CLI / shell.json ─► Omarchy                        │
                                                              ▼
                                             ~/.config/hypr/settings.lua
                                                              │
                                           marker in ~/.config/hypr/hyprland.lua
                                                              │
                                                     hyprctl reload
```

### Reading live values

- `SettingsStore` reads every Hyprland option declared in the schema with a single batched `hyprctl -j getoption <name>` call. The JSON answer's `bool`/`int`/`float`/`str` field becomes the effective value; vec4 options such as `general:gaps_in` answer as a `css` string and are read from its first component.
- `Omarchy` (the singleton) reads everything that is not a Hyprland option: themes and fonts (`omarchy theme/font list|current`), monitors (`hyprctl -j monitors all`), plugins (`omarchy plugin list --json`), the bar and idle timing (`shell.json`, watched live), night light, version, the fastfetch summary, and the update channel/availability.

### Writing values

Every change goes through `SettingsStore.set()` (or `setMonitor()`), which updates an in-memory `managed` map, then schedules an apply. A 120 ms debounce coalesces bursts of changes (dragging a slider) into one write.

1. **Regenerate `~/.config/hypr/settings.lua`** from `managed` plus the monitor overrides, via `model/Lua.js`. Only changed values are emitted, so removing a setting removes its line and the original value applies again.
2. **Ensure the loader** — append the idempotent block

```lua
-- custom-settings:load
require("hypr.settings")
```

to `~/.config/hypr/hyprland.lua` so `settings.lua` is required *last* and wins over Omarchy defaults and the user's own files. When nothing is managed, the block is removed again. The app never edits the user's other config, only this marker block.
3. **Persist intent** to `~/.local/state/omarchy/settings/hypr.json` (`{ managed, monitors }`). The UI reads `managed` back first, so controls respond instantly rather than after the reload round-trip.
4. **Reload** — `hyprctl reload`, then read `hyprctl configerrors`. A clean result shows **Applied**; anything else surfaces the errors in the status bar.

`Reset` on a row drops it from `managed`; `Reset all` empties the map and removes the loader block, returning full control to the user's own files.

### Schema as data

`model/Schema.js` is the whole settings surface. The generic UI renders it; there are no hand-written rows for the four core pages.

```js
{ id: "decoration.rounding", page: "appearance", group: "Shape",
  label: "Corner radius", desc: "…",
  type: "int", hypr: "decoration:rounding", lua: ["decoration", "rounding"],
  default: 0, min: 0, max: 40, step: 1, unit: "px" }
```

| field | meaning |
|-------|---------|
| `id` | unique key and persistence key |
| `page` / `group` | page and section heading |
| `label` / `desc` | row title and muted help text |
| `type` | `bool` \| `int` \| `float` \| `enum` \| `string` |
| `hypr` | `hyprctl getoption` name; omit for app-only values |
| `lua` | path into the `hl.config({...})` table |
| `default` | shown (and compared) when the value is not managed |
| `min` / `max` / `step` / `unit` / `percent` | numeric control hints |
| `options` | `[{value,label}]` for enums |
| `leaf` | emit as `hl.animation()` instead of a config path |

Helper functions at the bottom of the file — `settingById`, `groupsForPage`, `hyprOptions`, `matchingSettings`, `pageHasMatch` — drive the controls and the search index.

## The interface

- **Sidebar** — pages from `Schema.pages`, with the square Omarchy glyph and a search field. Typing filters pages and settings; results come from `Schema.matchingSettings`.
- **Keyboard** — Up/Down walk the focus chain, Tab moves between controls, Enter/Space activate. Escape closes the panel.
- **Generic pages** (`appearance`, `window`, `motion`, `input`) are rendered from the schema by `GenericPage` + `SettingRow`, using `SwitchControl`, `SegmentedControl`, and `ValueSlider`.
- **Custom pages** are hand-built where the schema model does not fit. See the table below.
- **Status bar** shows a summary of managed settings and the last apply result, including Hyprland config errors.

### Pages

| Page | Kind | What it covers |
|------|------|----------------|
| Appearance | generic | rounding, opacity, dim, blur, shadows, theme, font |
| Window | generic | gaps, borders, layout, tearing, resize |
| Motion | generic | animation speeds and styles |
| Input | generic | mouse, touchpad, keyboard repeat |
| Display | custom | monitor enable/mode/scale/position + arrangement canvas |
| Bar & Plugins | custom | bar position/transparency, plugins, bar layout |
| Idle & Lock | custom | screensaver and lock timing |
| Night Light | custom | on/off and colour temperature (hyprsunset) |
| Updates | custom | channel, availability, update actions |
| About | custom | version, fastfetch summary, health, ways back |

### Display and the monitor canvas

`DisplayPage` edits each output's enabled state, mode, scale, transform, and position, and hosts `components/MonitorCanvas.qml` for arrangement:

- Monitors are drawn at true aspect ratio from their **logical** size (`width / scale`), scaled to fit the canvas, so positions read the way Hyprland thinks about them.
- A monitor can be dragged with the mouse; edges snap to other monitors and to the origin, with a 10 px grid as a fallback. A live coordinate readout follows the drag.
- A drag only commits when the position actually changes, and a commit always writes the full base for that output (enabled, mode, scale, x, y), so a partial override can never silently reset the other fields.

### Updates

Update jobs need `sudo`, print progress, and sometimes prompt, so they run the same way Omarchy's own menu runs them — in a floating terminal:

```sh
omarchy-launch-floating-terminal-with-presentation "omarchy-update"
```

The page shows version, channel, branch, last package update, and availability (`omarchy-update-available`), lets the channel be switched (`omarchy-channel-set stable|rc|edge|dev`), and offers Update Omarchy, Check for updates, Update plugins, Update extra themes, Update firmware, and Restart shell. The availability probe only runs when the page asks — it reaches the package databases and is not part of the routine refresh.

### About

Reads the same fastfetch summary Omarchy prints, with the terminal logo and ANSI colour stripped, in a read-only monospace panel, plus a **Refresh info** button. Nothing here is editable; it is the app's answer to "what am I running?"

## Design language

Pulled from `qs.Commons.Style` and `qs.Commons.Color` so the panel matches the active theme:

- 24 px corner radius; background `#161616`, raised `#1e1e1e`, ink `#d6d6d6`, muted `#8c8c8c`, accent `#6db8ee`.
- Spacing ramp 2/4/8/12/16/20/24/32/48; type scale 11/12/13/14/16/18/24/56.
- No dividers — whitespace and two text tones separate content. Accent is rationed, and at most one inverted element (the primary action) appears per surface. Motion runs at 120/200/320 ms.

## Files

```
manifest.json               plugin id, kinds (bar-widget + panel), entry points
BarWidget.qml               the gear; toggles the panel through the shell
SettingsPanel.qml           panel lifecycle: open/close + FloatingWindow
SettingsApp.qml             the settings UI, host-agnostic
model/
  Schema.js                 the settings surface (pages + rows)
  Lua.js                    managed map → hypr/settings.lua
  SettingsStore.qml         live values, apply loop, state sidecar
  Omarchy.qml               everything that is not a Hyprland option
  qmldir                    registers the two singletons
components/
  Sidebar, NavItem          navigation + search
  GenericPage, SettingRow   schema-driven rendering
  SwitchControl, SegmentedControl, ValueSlider, PillButton, SearchField
  MonitorCanvas             draggable monitor arrangement
  PageHeader, StatusBar, SearchResults
pages/
  DisplayPage, BarPage, IdlePage, NightlightPage, UpdatesPage, AboutPage
```

## Extending

**Add a Hyprland setting:** add one entry to `Schema.settings`. Pick an existing `page` (or add a new page to `Schema.pages` and a `sourceFor` branch in `SettingsApp.qml` if it needs a custom body). No component changes are needed — the generic page, search, and Lua generator all read the schema.

**Add a custom page:** add it to `Schema.pages`, handle it in `sourceFor()`, and drop a `pages/<Name>Page.qml`. Use `SettingsStore` for Hyprland values and `Omarchy` for everything else.

## Safety

- The app writes only three files: `~/.config/hypr/settings.lua`, the marker block in `~/.config/hypr/hyprland.lua`, and the state sidecar.
- The loader block is idempotent and removed when nothing is managed.
- Every apply ends with `hyprctl configerrors`; problems are reported rather than hidden.
- To back everything out by hand: delete `~/.config/hypr/settings.lua`, remove the two lines under `-- custom-settings:load` in `hyprland.lua`, then `hyprctl reload`.

## Requirements

An Omarchy build whose shell supports user plugins under `~/.config/omarchy/plugins` and the `omarchy plugin` CLI, plus the Omarchy CLI on `PATH`. `fastfetch` is optional — the About page simply stays empty without it.