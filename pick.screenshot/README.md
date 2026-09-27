# Screenshot Picker — omarchy plugin

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/pick.screenshot`](https://github.com/nightdevil00/Plugins/pick.screenshot/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Each plugin has its own branch, so install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh pick.screenshot
```

Or do it by hand — note the directory is named by the plugin **id** (`pick.screenshot`), not the folder name:

```sh
git clone --depth 1 --branch pick.screenshot \
  https://github.com/nightdevil00/Plugins.git \
  ~/.config/omarchy/plugins/pick.screenshot
omarchy-shell shell rescanPlugins
omarchy plugin enable pick.screenshot
```


A bar widget that lets you pick screenshot mode: region, fullscreen, or window.

![Preview](preview.png)

## Install

```bash
omarchy plugin enable pick.screenshot   # after installing, see Installing below
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
