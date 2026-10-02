# simple.dock

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/simple.dock`](https://github.com/nightdevil00/Plugins/simple.dock/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh simple.dock
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`simple.dock`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/simple.dock ~/.config/omarchy/plugins/simple.dock
omarchy-shell shell rescanPlugins
omarchy plugin enable simple.dock
```


## Features

- Centered dock card opposite the bar (default: bottom edge).
- Apps menu button that opens the Omarchy apps menu.
- Pinned apps (in your chosen order) followed by running apps.
- Web apps (Chromium windows such as Discord, X, or YouTube Music) resolve to the
  matching `omarchy-launch-webapp` launcher, so they get a real name and icon
  instead of a generic glyph. A subdomain window such as `music.youtube.com`
  falls back to its parent site's launcher.
- Left-click a running app to focus it (or launch a pinned app that isn't running).
- Right-click for a context menu: **Launch**, **Pin to Dock** / **Unpin from Dock**, and **Close Window(s)**.
- Pin state persists in `~/.config/omarchy/dock.json` across shell restarts.
- Autohide (on by default): the dock hides and reveals itself when the cursor
  touches the bottom edge of the screen. Set `"autohide": false` in
  `~/.config/omarchy/simple.dock.json` to keep the dock pinned.
- Configurable monitor via `"screen": "eDP-1"` in the same file.

## Requirements

- An Omarchy system (omarchy-shell with Quickshell support).

## Installation

Install and enable with the official Omarchy plugin command:

```sh
omarchy plugin enable simple.dock
```

The command clones the repo into `~/.config/omarchy/plugins/simple.dock`,
validates the manifest, and enables the plugin. To update it later:

```sh
./install.sh --update simple.dock
```

To uninstall:

```sh
omarchy plugin remove simple.dock
```

After installing (or removing) the plugin, the shell restarts or rescans the
plugin directory automatically; if the dock does not appear, run
`omarchy restart shell`.

The dock appears at the bottom of the primary monitor. Touch the bottom edge
of the screen with the cursor to reveal it.

## Configuration

### Pinned apps

Pinned apps are stored in `~/.config/omarchy/dock.json`:

```json
{
  "pinned": ["vesktop", "foot", "org.gnome.Nautilus"]
}
```

Entries are desktop-file ids (the `.desktop` suffix is optional). The file is
created automatically the first time you pin an app; edits you make to it are
picked up while the shell is running.

### Autohide and screen

The dock hides and reveals itself when the cursor touches the bottom edge of
the screen. Autohide is on by default, so no file is needed; to make the
setting explicit — or to keep the dock pinned and always visible — create
`~/.config/omarchy/simple.dock.json`:

```json
{
  "autohide": true,
  "screen": "eDP-1"
}
```

- `autohide` — `true` (default) enables hover-reveal autohide; `false` keeps
  the dock pinned and always visible.
- `screen` — optional name of the monitor to attach the dock to (from
  `hyprctl monitors`); defaults to the first screen Quickshell reports.

The file is optional — a missing file uses the defaults. Edits are picked up
live, no restart needed.

## Files

- `manifest.json` — plugin manifest (`id: simple.dock`, kinds `overlay` + `menu`, kept
  loaded). The `menu` kind is what makes omarchy-shell inject `shell.appLibrary` into
  the plugin; the shell resolves the entry kind to `overlay` regardless, so the dock
  still mounts as an overlay.
- `Dock.qml` — the dock UI (a full-screen overlay whose interactive region is
  limited to the dock card, the context menu, and the bottom reveal strip).
- `DockModel.js` — pure helpers for the model and persistence.

## License

MIT
