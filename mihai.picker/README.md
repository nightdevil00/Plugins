# Wallpaper Picker

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.picker`](https://github.com/nightdevil00/Plugins/mihai.picker/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh mihai.picker
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`wallpicker.grid`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/mihai.picker ~/.config/omarchy/plugins/wallpicker.grid
omarchy-shell shell rescanPlugins
omarchy plugin enable wallpicker.grid
```


## Install

```bash
omarchy plugin enable wallpicker.grid
```

Enable the **Wallpapers** bar widget from Setup → Bar if it doesn't show
up on the right side automatically.

## Use

- Click the grid glyph (▦) in the bar to open/close the overlay.
- Click any thumbnail to apply it immediately and close the overlay.
- Escape dismisses without changing anything.

IPC:

```bash
omarchy-shell shell toggle wallpicker.grid
omarchy-shell wallpicker toggle|open|close|status
```

## Configuration

Open `WallpaperPicker.qml` and edit the properties near the top:

- `picturesDir` — defaults to `$HOME/Pictures/Wallpapers/`. Point it at any folder.
- `recursive` — set to `true` to include subfolders.
- `columns` — number of grid columns (default 5).

## How wallpaper-setting works

On click this plugin runs Omarchy's own CLI:

```bash
omarchy theme bg set "<chosen image>"
```

via `Util.execDetached(...)` (the same helper Omarchy's own plugins use).
Earlier drafts of this plugin manually symlinked
`~/.config/omarchy/current/background` and relaunched `swaybg` by hand —
that fought the CLI over state it owns (it actually tracks the current
background under `~/.local/state/omarchy/current/`) and silently did
nothing on current Omarchy releases. Letting `omarchy theme bg set` do
it is what Omarchy's own community plugins (e.g. grid-wallpaper-picker)
do, and it's the version that actually works.

## Remove

```bash
omarchy plugin disable wallpicker.grid
omarchy plugin remove wallpicker.grid --yes
```

## Notes / things to double check on your machine

- Relies on `omarchy theme bg set <path>` being available on your
  Omarchy version. Run it once from a terminal with a real image path
  to confirm it works on your system before relying on the plugin.
- The Quickshell `Process`/`StdioCollector` API used for listing files
  matches the pattern Omarchy's own plugins use, but if your Quickshell
  version's IPC API differs slightly, check `qs.Io`/`Quickshell.Io`
  docs and adjust `listProc`.
