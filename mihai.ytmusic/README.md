# mihai-ytmusic

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.ytmusic`](https://github.com/nightdevil00/Plugins/mihai.ytmusic/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh mihai.ytmusic
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`mihai.ytmusic`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/mihai.ytmusic ~/.config/omarchy/plugins/mihai.ytmusic
omarchy-shell shell rescanPlugins
omarchy plugin enable mihai.ytmusic
```


## Install

```bash
omarchy plugin enable mihai.ytmusic
```

Then add it to the bar (`~/.config/omarchy/shell.json`, `right` section):

```json
{ "id": "mihai.ytmusic", "display": "icon" }
```

## Remove

```bash
omarchy plugin remove mihai.ytmusic
```

Also remove the `mihai.ytmusic` entry from `~/.config/omarchy/shell.json` if you added it manually.

## License

MIT — see [LICENSE](./LICENSE).

## Tests

```bash
node --test tests/model.test.js
```
