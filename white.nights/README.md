# white.nights

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/white.nights`](https://github.com/nightdevil00/Plugins/white.nights/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh white.nights
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`white.nights`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/white.nights ~/.config/omarchy/plugins/white.nights
omarchy-shell shell rescanPlugins
omarchy plugin enable white.nights
```


## What it does

- Keeps the screensaver, lock, and display-off behavior exactly as configured
  (`idle.screensaver` / `idle.lock` in `~/.config/omarchy/shell.json`).
- Holds a `systemd-inhibit --mode=block` on `sleep`, `handle-lid-switch`,
  `handle-suspend-key`, and `handle-hibernate-key` while enabled, so suspend,
  hibernate, and lid-close sleep are refused.
- Shows a bar toggle to flip it on and off whenever you like. The enabled
  state persists across reboots.

Perfect for downloads, rendering, servers, or leaving the machine on overnight
without the screen burning.

## Requirements

- Omarchy (with the Quickshell-based shell and idle/lock plugins)
- `systemd-inhibit` (part of systemd, always present)

## Installation

Install it with `./install.sh white.nights` from a clone of the collection:

```bash
omarchy plugin enable white.nights
```

See [Installing](#installing) above for the full command.

```bash
omarchy plugin enable white.nights
# then, when you're ready:
omarchy plugin enable white.nights
```

The first time you enable it, sleep blocking is off. Turn it on with the bar
icon or `omarchy-shell no-sleep enable`.

## Usage

Click the monitor icon (`󰍹`) in the bar to toggle sleep blocking. When active
the icon is highlighted and tooltips explain the state.

You can also control it from a terminal:

```bash
omarchy-shell no-sleep status      # current state
omarchy-shell no-sleep enable      # block suspend/hibernate
omarchy-shell no-sleep disable     # allow suspend/hibernate again
omarchy-shell no-sleep toggle      # flip the state
```

Verify the inhibitor is live with:

```bash
systemd-inhibit --list
# No Sleep (white.nights) ... mode=block
```

## How it works

The plugin is a `service` + `bar-widget` pair:

- `Service.qml` keeps a long-running `systemd-inhibit` process that holds a
  **block** inhibitor while the service is enabled. logind refuses every sleep
  request (suspend, hibernate, suspend-then-hibernate, hybrid) and ignores the
  lid/suspend keys while it is held. The state is persisted in
  `~/.local/state/omarchy/indicators/white.nights`.
- `BarWidget.qml` is the bar toggle that talks to the service.

Because sleep is blocked, logind never enters sleep, so Omarchy's pre-suspend
lock (`omarchy-sleep-lock.service`) simply never fires — there is nothing to
lock before. The screen still blanks through the normal idle → screensaver →
lock path.

## Notes

- While enabled, `systemctl suspend` and friends fail with "Operation
  inhibited". That is the point — disable it when you actually want to sleep.
- The block only lasts while the Omarchy shell is running. If you log out, the
  inhibitor is released and sleep behaves normally again.

## Uninstall

```bash
omarchy plugin remove white.nights
```

## License

[MIT](LICENSE)
