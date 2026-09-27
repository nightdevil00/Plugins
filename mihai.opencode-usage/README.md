> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.opencode-usage`](https://github.com/nightdevil00/Plugins/mihai.opencode-usage/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Each plugin has its own branch, so install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh mihai.opencode-usage
```

Or do it by hand — note the directory is named by the plugin **id** (`mihai.opencode-usage`), not the folder name:

```sh
git clone --depth 1 --branch mihai.opencode-usage \
  https://github.com/nightdevil00/Plugins.git \
  ~/.config/omarchy/plugins/mihai.opencode-usage
omarchy-shell shell rescanPlugins
omarchy plugin enable mihai.opencode-usage
```


Opencode Usage plugin for Omarchy

<img width="398" height="674" alt="preview" src="https://github.com/user-attachments/assets/6abbfb6d-f0fc-4ea3-85ea-00a823b3789c" />

Install with `./install.sh mihai.opencode-usage` from a clone of the [Plugins](https://github.com/nightdevil00/Plugins) collection — see [Installing](#installing).

Remove ```omarchy plugin remove mihai.opencode-usage```

Enjoy!

MIT Licence
