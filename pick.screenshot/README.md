# Screenshot Picker — omarchy plugin

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/pick.screenshot`](https://github.com/nightdevil00/Plugins/pick.screenshot/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh pick.screenshot
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`pick.screenshot`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/pick.screenshot ~/.config/omarchy/plugins/pick.screenshot
omarchy-shell shell rescanPlugins
omarchy plugin enable pick.screenshot
```


## Install

```bash
omarchy plugin enable pick.screenshot
```

This clones the repo, validates the manifest, and prompts you to place the icon in your bar.

## Usage

Click the camera icon () in the bar to open the picker:

- **Region** — `omarchy-capture-screenshot region`
- **Fullscreen** — `omarchy-capture-screenshot fullscreen`
- **Window** — `omarchy-capture-screenshot windows`

Right-click the icon to take an instant default screenshot.

## Files

```
manifest.json       — plugin metadata
ScreenshotMenu.qml  — bar widget with popup menu
README.md           — this file
```
