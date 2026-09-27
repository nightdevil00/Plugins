# tlp.battery

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/tlp.battery`](https://github.com/nightdevil00/Plugins/tlp.battery/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh tlp.battery
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`tlp.battery`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/tlp.battery ~/.config/omarchy/plugins/tlp.battery
omarchy-shell shell rescanPlugins
omarchy plugin enable tlp.battery
```


## What lives here

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin manifest: `id: tlp.battery`, marker `clonedFrom: omarchy.power` |
| `Panel.qml` | Bar widget UI (hero, stats, profile picker, charge-limit toggle) |
| `Model.js` | Icon / state helpers (unchanged from stock) |
| `battery-status.sh` | Emits panel stats (`percentage`..`threshold`) parsed from `tlp-stat -b` |
| `power-profiles.sh` | Lists TLP profiles `performance`/`balanced`/`power-saver`, marks the active one (`tlp-stat -s`) |
| `set-power-profile.sh` | Runs `sudo tlp <profile>` to switch profiles at runtime |
| `charge-limit.sh` | `show` / `set100` / `setcap`; persists and applies the charge limit |

## How it works

- The panel kernel no longer imports `Quickshell.Services.UPower` — battery
  state, percentage, rate, time-to-full, and cycles all come from
  `battery-status.sh`. Because nothing pushes updates anymore, the closed bar
  widget polls every 30 s, and the open panel every 5 s.
- The **power profile picker** lists TLP's three profiles and calls
  `tlp performance|balanced|power-saver`. On this machine the visible effect
  is the `intel_pstate` `max_perf_pct` cap: 100 % / 70 % / 50 %.
- The **Charge limit** toggle switches between `Standard` (charge to 100 %)
  and `Long_Life` (conservation cap). It is binary because the ThinkBook's
  driver exposes `charge_types` as `0=Standard, 1=Long_Life`.
  `charge-limit.sh` writes the choice to
  `/etc/tlp.d/10-omarchy-charge.conf` (`STOP_CHARGE_THRESH_BAT0=0|1`) so it
  survives reboots, then applies it immediately with `tlp setcharge`.

## Setting up TLP

TLP is a prerequisite: this widget reads and drives TLP state, so TLP must be
installed, enabled, and free of conflicting power managers. The steps below
follow the [ArchWiki](https://wiki.archlinux.org/title/TLP).

### Install and enable

```bash
sudo pacman -S tlp
sudo systemctl enable --now tlp.service
```

Useful optional packages (per the ArchWiki):

- `tlp-rdw` — Radio Device Wizard, manages Wi-Fi/Bluetooth radio state by
  power source. Requires NetworkManager and the
  `NetworkManager-dispatcher.service`.
- `tlpui` — GTK front end for TLP.
- `tlp-pd` — provides the freedesktop `power-profiles` D-Bus interface that
  GNOME/KDE expect, but backed by TLP instead of power-profiles-daemon. See
  the [TLP FAQ](https://linrunner.de/tlp/faq/ppd.html).

### Disable conflicting services

The ArchWiki
[Power management](https://wiki.archlinux.org/title/Power_management) page
warns: *"Only run one of these tools to avoid possible conflicts as they all
work more or less similarly."* `power-profiles-daemon` and TLP both drive the
same hardware knobs and fight each other when running side by side — the stock
Omarchy `omarchy.power` widget was even built on the assumption that
power-profiles-daemon provides the profiles (which, on this ThinkBook's
firmware, it does not).

With TLP taking over, stop and mask power-profiles-daemon:

```bash
sudo systemctl disable --now power-profiles-daemon.service
sudo systemctl mask power-profiles-daemon.service
```

If you later want the profiles in GNOME/KDE again, install `tlp-pd` instead of
un-masking power-profiles-daemon.

TLP's own radio management conflicts with *systemd's* rfkill handling, so the
ArchWiki also recommends masking systemd's units:

```bash
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
```

### Configuration

Main config lives in `/etc/tlp.conf`; per-change drop-ins go in `/etc/tlp.d/`,
e.g. `/etc/tlp.d/10-omarchy-charge.conf`. Note the ArchWiki precedence rule:
if the same parameter is set in both places, the value in `/etc/tlp.conf`
wins.

The widget uses (and, via `charge-limit.sh`, writes) drop-ins — see
[How it works](#how-it-works) above.

### Verifying and applying

```bash
sudo tlp-stat                # overview, mode (AC/BAT), applied settings
sudo tlp start|stop|status   # manage at runtime
sudo tlp setcharge 0 0 BAT0  # charge thresholds: <start> <stop> <battery>
```

See the [ArchWiki TLP page](https://wiki.archlinux.org/title/TLP) and
[TLP commands](https://linrunner.de/tlp/usage/index.html#commands) for more.

## Requirements

- Passwordless sudo for `tlp-stat` and `tlp` (the helper scripts invoke
  `sudo -n`; that is how Omarchy grants battery actions).
- TLP enabled and running (`tlp.service`).
- The TLP drop-in `/etc/tlp.d/10-omarchy-charge.conf` is shared state with the
  charge-limit toggle — edit it by hand or via the toggle, keep the values in
  sync.

## Notes

- IPC target is kept as `omarchy.power` (stock clone convention: built-in ids
  stay inside plugin code as stable IPC targets). The `SUPER + CTRL + P`
  keybinding to toggle the panel and the `showPercentage` setting keep
  working.

## Install

```bash
omarchy plugin enable tlp.battery
```

## Update

```bash
./install.sh --update tlp.battery
```

## Uninstall

```bash
omarchy plugin remove tlp.battery --yes
```