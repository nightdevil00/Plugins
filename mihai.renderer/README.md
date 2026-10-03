# mihai.renderer

A bar widget for Omarchy that shows which GPU is rendering the desktop and lets
you pick a different one.

The panel is the whole point: the button in the bar reads the name of the GPU
that is drawing right now, and clicking it opens a list of the GPUs in the
machine. Picking one writes a saved order and offers to log out, because that
is the only point at which the change can take effect.

## What it does

On every login the plugin drops a small Lua file into the Hyprland toggle
directory. Hyprland sources it before it creates its DRM backends, and it sets
one variable:

```
AQ_DRM_DEVICES=/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu
```

`AQ_DRM_DEVICES` is a colon-separated list. The first entry renders; the rest
stay available for the screens plugged into them. A GPU left out of the list is
not used at all, and its monitors stay dark.

With nothing saved, the plugin writes no variable at all and lets Aquamarine
decide, which puts the GPU with the built-in screen in front. The hook file is
removed in that state rather than left behind empty.

The list is built from PCI addresses, not `/dev/dri/cardN`, so the usual
card renumbering after a kernel update cannot point it at the wrong GPU. If the
optional udev rules are installed, the stable `/dev/dri/intel-igpu` and
`/dev/dri/nvidia-dgpu` names are used instead.

## Files

| Path | What it is |
| --- | --- |
| `~/.config/mihai.renderer/order` | The saved order, one PCI address per line. Empty means automatic. |
| `~/.local/state/omarchy/toggles/hypr/mihai-renderer-gpus.lua` | Generated login hook that sets `AQ_DRM_DEVICES`. |
| `/etc/udev/rules.d/90-mihai-renderer-gpus.rules` | Optional stable GPU names, installed from the panel. |

The order file and the hook are both generated. Editing either by hand works —
the hook resolves PCI addresses through sysfs at startup — but the next choice
made in the panel rewrites the hook.

## The command line

Everything the panel does is available on its own:

```bash
# What is in the machine, what is saved, what is running.
~/.config/omarchy/plugins/mihai.renderer/lib/mihai-renderer.sh status

# The same thing as JSON, which is what the panel reads.
~/.config/omarchy/plugins/mihai.renderer/lib/mihai-renderer.sh json

# Pick a renderer. Any order is accepted; the first address renders.
lib/mihai-renderer.sh order 0000:01:00.0 0000:00:02.0

# Presets, for scripts.
lib/mihai-renderer.sh preset igpu        # integrated first, dedicated kept
lib/mihai-renderer.sh preset dgpu        # dedicated first, integrated kept
lib/mihai-renderer.sh preset auto        # clear the list, let Aquamarine decide
lib/mihai-renderer.sh preset only-igpu   # integrated only, dedicated not used
lib/mihai-renderer.sh preset only-dgpu   # dedicated only, integrated not used

# The udev rules that give the GPUs stable names.
lib/mihai-renderer.sh links             # print them
lib/mihai-renderer.sh links-install     # needs your password
lib/mihai-renderer.sh links-remove
```

`preset igpu` and `preset dgpu` keep both GPUs in the list, so the built-in
screen and any external screen stay lit. `only-igpu` and `only-dgpu` drop the
other one, which is what you want when the screens are all on one GPU.

## Applying a change

`AQ_DRM_DEVICES` is read once, when the DRM backends are created. Changing it
needs a new login, not a restart of anything. The panel says so as soon as the
saved order stops matching what is running, and the bar button turns the
warning colour until the two agree again.

## If another config also sets `AQ_DRM_DEVICES`

That is allowed — Hyprland merges the sources — but two files fighting over the
same variable is confusing. The panel lists every config file that sets it and
every device list that duplicates one of yours.

## Notes on the machine it runs on

The detection is deliberately generic: it reads sysfs and `/usr/share/hwdata/pci.ids`,
looks for a connected `eDP`/`LVDS`/`DSI` output to find the built-in screen, and
classifies each card by what that screen says rather than by a whitelist of
vendors. Machines with one card show their details and nothing to pick. Machines
with several cards that are not a hybrid get one choice per card. Virtual GPUs
such as virtio are listed but never offered, since they cannot render.

`/sys/module/nvidia_drm/parameters/*` is root-only, so the NVIDIA driver
version comes from `/proc/driver/nvidia/version` instead, which is world
readable. A driver that lives in the kernel tree has no version of its own, so
the kernel release is reported as its version.

The panel shows the driver, its version, the screens plugged into each card and
the stable `/dev/dri` name. The PCI address, the `cardN` number and
integrated/dedicated are deliberately left out: they are what the hook is keyed
on, but they are not what anyone needs told.

## A screen that stays dark

A connector can be plugged in and still produce no picture, because seeing the
monitor and being allowed to modeset it are two different things. The kernel
reports `connected` from the connector itself, which is true even when nothing
drives it. What actually decides is whether the compositor opened a DRM backend
on that card, which only Hyprland's own log records.

Both are read, and the panel says so when they disagree: a card with a screen
plugged in that never got a backend is reported as one whose screen will stay
dark. The usual cause is the NVIDIA driver without kernel modesetting
(`nvidia_drm.modeset=1`), which leaves `nvidia-smi` reporting a loaded driver
and `hyprctl monitors` reporting nothing on the card.
