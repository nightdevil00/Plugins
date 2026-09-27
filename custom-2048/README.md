# 2048

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/custom-2048`](https://github.com/nightdevil00/Plugins/custom-2048/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Each plugin has its own branch, so install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh custom-2048
```

Or do it by hand — note the directory is named by the plugin **id** (`terminal.2048`), not the folder name:

```sh
git clone --depth 1 --branch custom-2048 \
  https://github.com/nightdevil00/Plugins.git \
  ~/.config/omarchy/plugins/terminal.2048
omarchy-shell shell rescanPlugins
omarchy plugin enable terminal.2048
```


A small terminal **2048** for [Omarchy](https://omarchy.org/). The board follows the theme you already have selected and fills the whole screen. Pick a board size, then join the tiles to reach 2048.

![preview](preview.png)

The game opens as a normal tiled window, so it joins whatever layout you are already using. Move and resize it with your usual keys.

## Install

```sh
omarchy plugin enable terminal.2048   # after installing, see Installing below
```

That clones the repo into `~/.config/omarchy/plugins/terminal.2048/`. Click the bar icon to open the panel, then Play. Or run the game directly:

```sh
~/.config/omarchy/plugins/terminal.2048/omarchy-2048
```

## How to play

1. **Pick a board size** in the menu — anything from 4×4 up to 8×8.
2. **Move** the tiles with the arrow keys or WASD. Every move slides all tiles as far as they go in that direction.
3. Two tiles with the **same value merge** into one tile worth their sum. A tile merges at most once per move.
4. After every successful move a **new tile** (2, or 4 with a 10% chance) appears in a random empty cell.
5. Reach **2048** to win. Keep playing for a higher score, or stop there.
6. The game ends when no move can change the board.

Your **score** increases by the value of every tile you merge. The best score is tracked **per board size**.

| Key | Action |
|---|---|
| ← → ↑ ↓ / WASD | Move tiles |
| r | Retry |
| p | Pause |
| q / Esc | Menu, or quit from the menu |

The board renders to fill the entire terminal, with each tile sized to the chosen grid — a 4×4 board shows huge tiles, an 8×8 board shows smaller ones. Tiles are colored by value and follow your theme. Best scores live in `~/.local/share/omarchy-2048/scores.json`. Last size and "keep going" live in `~/.local/state/omarchy/2048.json`.

## Menu

Left click the bar icon for the panel. Right click starts a game. Escape closes the panel. `omarchy-shell shell summon terminal.2048` opens it the same way.

In the panel you can choose the **board size** and toggle **keep going past 2048**, then hit Play.

## Configure

```sh
omarchy bar move terminal.2048 --section left
```

## Why this is safe

Installing only clones the git repo. It does not run install scripts or request elevated privileges.

The game is Python 3 and the standard library. It does not open the network. It reads the current theme colors and writes scores and settings under your home directory. The bar widget launches that script in a terminal. Plugins stay off until you enable them.

## Remove

```sh
omarchy plugin remove terminal.2048
```

## License

Released under the [MIT License](LICENSE).
