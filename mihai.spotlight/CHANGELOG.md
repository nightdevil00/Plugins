# Changelog

All notable changes to **Spotlight** (`mihai.spotlight`) will be documented in
this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## Source & install

Spotlight is tracked in git as part of the **Plugins** collection — one commit
per change, on `main`:

| | |
|---|---|
| Git address | `https://github.com/nightdevil00/Plugins.git` |
| Plugin directory | [`Plugins/mihai.spotlight`](https://github.com/nightdevil00/Plugins/tree/main/mihai.spotlight/) |
| Raw source | [`Plugins/mihai.spotlight/Spotlight.qml`](https://github.com/nightdevil00/Plugins/blob/main/mihai.spotlight/Spotlight.qml) |
| Commit log | [`Plugins/commits/main`](https://github.com/nightdevil00/Plugins/commits/main/?path=mihai.spotlight) |

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh mihai.spotlight
```

Or copy it straight from a clone — the install directory is named by the plugin
**id** (`mihai.spotlight`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/mihai.spotlight ~/.config/omarchy/plugins/mihai.spotlight
omarchy-shell shell rescanPlugins
omarchy plugin enable mihai.spotlight
```

Then add a keybind in `~/.config/hypr/bindings.lua`:

```lua
o.bind("ALT + SPACE", "Spotlight launcher", "omarchy-shell shell summon mihai.spotlight '{}'")
```

Update an installed copy, or remove it:

```sh
cd Plugins && ./install.sh --update mihai.spotlight   # pull the latest and re-copy
omarchy plugin remove mihai.spotlight                  # uninstall
```

> The plugin used to live in its own repository, so
> `omarchy plugin add https://github.com/nightdevil00/mihai.spotlight.git`
> worked. That standalone repository is retired: everything now ships from the
> collection above, and `omarchy plugin add` (which needs `manifest.json` at a
> repository root) does **not** apply to it — use `./install.sh`.

---

## [1.2.1] - 2026-10-05

### 🐛 Fixed
- **Installed apps no longer buried under PATH binaries**: searching `chrome`
  used to return `Run chromium`, `Run chromedriver`, `Run google-chrome-stable`
  and `Run omarchy-chromium-copy-url-host` before the browser itself, leaving
  the app you searched for on row 5. App rows are now emitted before binaries
  in `rebuildDisplay()`, so the `.desktop` entry you searched for leads the
  list. Files stay last, and math / URL / `cd` / shell-command rows still win
  when the query clearly *is* one of those.

Result order at the root is now: calculator → URLs → terminal folders →
commands → **apps** → binaries → actions → menu matches → folders → files.

### 📚 Docs
- Refreshed the documented result order in `README.md` to match.

Commits: [`34e2f60`](https://github.com/nightdevil00/Plugins/commit/34e2f60)

---

## [1.2.0] - 2026-10-04

### 🚀 Added
- **Bang search**: any query starting with `!bang` goes straight to that site's
  search — `!g` Google, `!gh` GitHub, `!aw` Arch Wiki, `!aur` AUR, `!yt`
  YouTube, `!so` Stack Overflow, `!gm` Maps and 13,489 more. The target URL is
  built locally, so there is no DuckDuckGo round trip.
- **`bangs.txt`**: the full DuckDuckGo bang list (13,489 entries, 1.3 MB) shipped
  with the plugin, parsed into memory on first use and binary-searched per
  keystroke instead of being scanned linearly.
- **Alternates and typo recovery**: `!a` also offers `!aw` and `!aur`, ranked by
  DuckDuckGo's own popularity, and a one-character misspelling (`!githbu`)
  recovers to `!git` / `!github`.
- **Unknown-bang fallback**: unresolved bangs still work by handing
  `duckduckgo.com/?q=!bang term` to DuckDuckGo, with a plain web search as the
  last resort. A bang with no term opens the site's search page.
- **`update-bangs.py`**: refresh script for `bangs.txt`.

Commits: [`b2a439b`](https://github.com/nightdevil00/Plugins/commit/b2a439b)

---

## [1.1.0] - 2026-09-27

### 📦 Published
- First release in the **Plugins** collection: `manifest.json`
  (`schemaVersion: 1`, `overlay` kind, `keepLoaded`), `LICENSE` (MIT),
  `preview.png`, and the complete `Spotlight.qml` source.
- Install docs written for per-plugin branches, then switched to installing from
  repository subdirectories — the layout `omarchy` expects, and the one the
  collection's `install.sh` produces.

### ✨ Features
- **App launcher** — fuzzy search over installed apps with smart ranking:
  prefix match, multi-word acronyms (`vsc` → Visual Studio Code), keywords and
  generic names.
- **File & folder search** via [`fd`](https://github.com/sharkdp/fd), newest
  first, with extension mode (`*.pdf`, `.conf`, `.md`).
- **Command runner** for anything in `PATH`, including wrappers (`sudo …`,
  `watch …`); TUI programs run interactively, one-shot commands keep the
  terminal open so output stays readable.
- **Open a folder in a terminal** (`cd ~/Projects`) and **open URLs**
  (`example.com`) in the default browser.
- **Inline calculator** with clipboard copy, and **quick actions**: screenshot
  (region/fullscreen), screen recording, lock screen, night light.
- **The whole `omarchy.menu` tree built in** — opens at the menu root, drills
  into sections with a breadcrumb header, honours `when:` guards and `checked:`
  ticks, and lists Apps and Fonts natively. The external menu plugin is never
  summoned.
- **Folder jump list** for Downloads, Documents and Omarchy/Hyprland config.

Commits: [`d8d16ea`](https://github.com/nightdevil00/Plugins/commit/d8d16ea),
[`b794739`](https://github.com/nightdevil00/Plugins/commit/b794739),
[`df54db2`](https://github.com/nightdevil00/Plugins/commit/df54db2),
[`dceac6f`](https://github.com/nightdevil00/Plugins/commit/dceac6f)

---

## Commit history

Only commits touching `mihai.spotlight` are listed; development before
`d8d16ea` predates the repository and is not recoverable from git.

| Commit | Date | Version | Change |
|---|---|---|---|
| [`34e2f60`](https://github.com/nightdevil00/Plugins/commit/34e2f60) | 2026-10-05 | 1.2.1 | Rank installed apps above PATH binaries in search |
| [`b2a439b`](https://github.com/nightdevil00/Plugins/commit/b2a439b) | 2026-10-04 | 1.2.0 | Add bang search (`!g term`) with the full DDG bang list |
| [`dceac6f`](https://github.com/nightdevil00/Plugins/commit/dceac6f) | 2026-09-27 | 1.1.0 | Install from subdirectories; drop the per-plugin branches |
| [`df54db2`](https://github.com/nightdevil00/Plugins/commit/df54db2) | 2026-09-27 | 1.1.0 | Point all install docs at the per-plugin branches |
| [`b794739`](https://github.com/nightdevil00/Plugins/commit/b794739) | 2026-09-27 | 1.1.0 | Include complete plugin source |
| [`d8d16ea`](https://github.com/nightdevil00/Plugins/commit/d8d16ea) | 2026-09-27 | 1.1.0 | Publish plugin collection |

## Requirements

- [Omarchy](https://omarchy.org) (plugin system + `omarchy-shell`)
- `fd` (bundled with Omarchy) for file search
- `wl-clipboard` for copying calculator results

## License

[MIT](https://opensource.org/licenses/MIT) © mihai