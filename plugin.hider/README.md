# plugin.hider

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/plugin.hider`](https://github.com/nightdevil00/Plugins/plugin.hider/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Each plugin has its own branch, so install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh plugin.hider
```

Or do it by hand — note the directory is named by the plugin **id** (`plugin.hider`), not the folder name:

```sh
git clone --depth 1 --branch plugin.hider \
  https://github.com/nightdevil00/Plugins.git \
  ~/.config/omarchy/plugins/plugin.hider
omarchy-shell shell rescanPlugins
omarchy plugin enable plugin.hider
```


A bar widget for [Omarchy](https://omarchy.org/) that lets you hide and show all plugins in the right bar section with a single click.

![preview](preview.png)

![demo](demo.gif)

## Installation

```bash
omarchy plugin enable plugin.hider   # after installing, see Installing below
```

When prompted, choose **right** as the bar section placement.

## Usage

Click the chevron icon (`<` / `>`) in the right bar section:

- **`<`** — all other right-section plugins are hidden and the icon rotates to `>`
- **`>`** — hidden plugins are restored and the icon rotates back to `<`

The hidden state persists across shell restarts.

## Settings

Settings are configured in the widget's entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "plugin.hider",
  "keepVisible": ["omarchy.bluetooth", "omarchy.network"]
}
```

| Key | Default | Description |
|---|---|---|
| `keepVisible` | `[]` | Plugin IDs that should never be hidden by the chevron toggle |

You can set this with the CLI:

```bash
omarchy bar set plugin.hider keepVisible '["omarchy.bluetooth", "omarchy.network"]' --json
```

Plugins in `keepVisible` stay in the bar at all times and are not affected by the hide/show toggle.

## Remove

```bash
omarchy plugin remove plugin.hider
```

## How it works

The plugin reads `bar.layout.right` from `~/.config/omarchy/shell.json`. When hiding, it moves every entry (except itself and `keepVisible` entries) into a `hiddenEntries` array on its own layout entry and filters them out of `bar.layout.right`. When showing, it moves them back. The shell hot-reloads on save, so no restart is needed.

## License

MIT
