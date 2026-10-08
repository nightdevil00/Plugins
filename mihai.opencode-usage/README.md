> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.opencode-usage`](https://github.com/nightdevil00/Plugins/mihai.opencode-usage/)

## Compatibility

This plugin works **only with opencode 2** (`session_v2` / `session_message` database tables). It does not support opencode 1.

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh mihai.opencode-usage
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`mihai.opencode-usage`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/mihai.opencode-usage ~/.config/omarchy/plugins/mihai.opencode-usage
omarchy-shell shell rescanPlugins
omarchy plugin enable mihai.opencode-usage
```

