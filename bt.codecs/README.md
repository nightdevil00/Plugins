# Bluetooth codec

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/bt.codecs`](https://github.com/nightdevil00/Plugins/bt.codecs/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh bt.codecs
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`bt.codecs`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/bt.codecs ~/.config/omarchy/plugins/bt.codecs
omarchy-shell shell rescanPlugins
omarchy plugin enable bt.codecs
```


## Requirements

- Omarchy (Quickshell shell)
- PipeWire with PulseAudio compat (default on Omarchy) and `pactl` on `PATH`
- Bluetooth audio devices managed by PulseAudio/PipeWire

## Install

Plugins are installed from git with the `omarchy plugin` command:

```bash
omarchy plugin enable bt.codecs
```

`omarchy plugin enable` places the widget in your bar. It asks which bar
section to use; pass `--section left|center|right` to skip the prompt.

If you already have the plugin installed, replace it with:

```bash
./install.sh --update bt.codecs
```

## Usage

- Click the codec icon in the bar to open the device/codec panel.
- The icon shows the active codec of the currently active Bluetooth device
  (or a disconnected glyph when no Bluetooth device is active).
- The panel lists every connected Bluetooth audio device and its profiles.
  Click a profile to switch immediately.
- Active profile is marked with a check icon.

## Supported profiles

Listed per device as reported by PipeWire:

- A2DP sink: `a2dp-sink-sbc`, `a2dp-sink-sbc_xq`, `a2dp-sink` (AAC)
- Headset: `headset-head-unit-cvsd`, `headset-head-unit` (MSBC)

## Development

The plugin lives in `~/.config/omarchy/plugins/bt.codecs/` after install. Edit
the QML/JS there; saved changes reload automatically.

- `Panel.qml` — bar widget and panel UI
- `Model.js` — parses `pactl list cards` and builds the device/profile model
- `manifest.json` — Omarchy plugin manifest

## License

MIT
