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

## Thumbnails (previews)

The grid paints one cell per wallpaper, and a cell is ~370 px wide. Decoding
the originals to fill it is ruinous at this collection size: the average
wallpaper here is ~4400×2500 and the largest is 7475×4319, which is ~120 MB of
RGBA per cell once decoded, and ~450 ms of CPU each. The plugin therefore shows
a cached preview instead.

Previews live in `~/.cache/wallpicker-grid/thumbs/`, mirroring your wallpaper
tree with the leading `/` dropped:

```
~/Pictures/Wallpapers-sorted/anime/foo.jpg
~/.cache/wallpicker-grid/thumbs/home/you/Pictures/Wallpapers-sorted/anime/foo.jpg.jpg
```

That layout is the whole contract — a preview path is derived from a wallpaper
path by string concatenation, so there is no index to keep in sync and no way
for the two to disagree.

**You don't have to do anything.** The first time you open a category that has
no previews, the plugin generates them for that category in the background and
shows `Cached N previews in <category>` when it finishes. Wallpapers that
already have a preview are skipped, so reopening a category costs nothing.

To pre-build everything at once (better on a category with thousands of
images, and it keeps the overlay from competing for CPU while it's open):

```sh
~/.config/omarchy/plugins/wallpicker.grid/thumbnails.sh
```

(The directory is named after the plugin **id**, `wallpicker.grid`, not the
repo folder name `mihai.picker`.)

Roughly 5 minutes for 4,400 wallpapers on 12 cores, producing ~96 MB of
previews. Re-running it is cheap and only regenerates what changed:

```sh
thumbnails.sh --help          # --size, --jobs, --backend, --cache
```

It uses `vipsthumbnail` (libvips) when available and falls back to ImageMagick.
A preview is written to a temp name and renamed into place, so the picker can
never read a half-written file.

If a preview is missing the cell falls back to the original file, and the
`Image` still asks Qt to decode at cell size rather than native size — so even
the uncached path is far cheaper than it was.

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
