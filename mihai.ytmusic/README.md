# mihai-ytmusic

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.ytmusic`](https://github.com/nightdevil00/Plugins/mihai.ytmusic/)

YouTube Music as a dropdown window anchored to the Omarchy bar (Chromium in app mode). Playback continues while the dropdown is hidden.

- Click: shows/hides instantly (no animation, opens directly in position)
- Clicking outside, focus change, or workspace switch: hides automatically
- Bar icon shows the current track; middle-click toggles play/pause

Requires `chromium` (or `google-chrome`) installed.

Fork of [wolften/omarchy-youtube-music](https://github.com/wolften/omarchy-youtube-music). Renamed to `mihai.ytmusic`.

## Install

```bash
omarchy plugin add https://github.com/nightdevil00/mihai.ytmusic --enable
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
