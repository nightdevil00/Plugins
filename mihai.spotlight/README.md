# mihai.spotlight

> Part of the **[Plugins](https://github.com/nightdevil00/Plugins)** collection — source: [`Plugins/mihai.spotlight`](https://github.com/nightdevil00/Plugins/mihai.spotlight/)

## Installing

This plugin lives in the [Plugins](https://github.com/nightdevil00/Plugins) collection. Install it with the bundled script:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cd Plugins
./install.sh mihai.spotlight
```

Or copy it straight from a clone — note the install directory is named by the
plugin **id** (`mihai.spotlight`), not the folder name:

```sh
git clone https://github.com/nightdevil00/Plugins.git
cp -r Plugins/mihai.spotlight ~/.config/omarchy/plugins/mihai.spotlight
omarchy-shell shell rescanPlugins
omarchy plugin enable mihai.spotlight
```


## Features

- **App launcher** — fuzzy search across installed apps with smart ranking (prefix match, multi-word acronyms like `vsc` → Visual Studio Code, keywords, generic names)
- **File & folder search** — searches your home directory by name via [`fd`](https://github.com/sharkdp/fd), results sorted by most recently modified
  - Extension mode: type `*.pdf`, `.conf`, `.md` … to filter by extension
- **Run commands** — type any command found in `PATH` (`btop`, `fastfetch`, `pacman -Qs …`)
  - TUI programs (vim, htop, lazygit, ranger…) run interactively; one-shot commands keep the terminal open so you can read the output
  - Wrapper commands like `sudo …`, `watch …`, `env …` work too
- **Open folders in terminal** — `cd ~/Projects` launches a terminal at that directory
- **Open URLs** — anything that looks like a link (`example.com`, `www.foo.org`) opens in your default browser
- **Bang search** — `!g <term>` searches the web straight from the launcher, using DuckDuckGo's full bang list (13,489 bangs: `!g` Google, `!gh` GitHub, `!yt` YouTube, `!aw` Arch Wiki, `!aur` AUR, `!so` Stack Overflow, `!gm` Maps, `!r` Reddit, `!ai`, `!ddg`…). Alternates and typo corrections are offered as you type, and unknown bangs fall back to DuckDuckGo's own resolver
- **Inline calculator** — type an expression like `(1920 * 2) / 3`; press Enter to copy the result to the clipboard
- **Quick actions** — screenshot (region/fullscreen), screen recording, lock screen, night light toggle
- **Uninstall** — press `Delete` on an app or web app and a small dialog asks to confirm; Omarchy then removes whichever kind of entry it is (web app, TUI launcher, a `.desktop` you dropped in `~/.local/share/applications`, a pacman package, or a Flatpak)
- **Omarchy menu built in** — the full `omarchy.menu` tree lives inside Spotlight. It opens at the menu's root (Apps, Learn, Trigger, Style…); submenu rows drill into their section right in Spotlight (`←` goes back), action rows run their command directly, and the Apps and Fonts sections list their entries natively. Entries hidden by `when:` conditions stay hidden, and `checked:` rows carry a ✓
- **Folder jump list** — Downloads, Documents, Omarchy/Hyprland config, etc.

## Installation

```sh
omarchy plugin enable mihai.spotlight
```

Then add a keybind in `~/.config/hypr/bindings.lua`:

```lua
o.bind("ALT + SPACE", "Spotlight launcher", "omarchy-shell shell summon mihai.spotlight '{}'")
```

Pick whatever combo you like — `ALT + SPACE` is just a suggestion.

## Usage

Summon the overlay and just start typing — or use it like the Omarchy menu: the root sections are listed, `Enter`/`→` drills into a section, `←`/`Esc` goes back. Results when typing are grouped: calculator → URLs → terminal folders → commands → **apps** → binaries → actions → menu matches → folders → files. Installed apps come before `PATH` binaries so the app you searched for leads the list (`chrome` opens Chromium, not `Run chromium`).

| Input | Result |
|---|---|
| `fire` | Launches Firefox |
| `vsc` | Matches Visual Studio Code by acronym |
| `*.pdf` or `.conf` | Recent files with that extension |
| `notes.md` | Files/folders matching the name |
| `btop` | Runs btop in a terminal |
| `sudo pacman -Syu` | Runs the full command in a terminal |
| `cd ~/.config` | Opens a terminal there |
| `github.com` | Opens in default browser |
| `!g omarchy shell` | Searches Google, Enter opens it in the browser |
| `!aw pacman` | Searches the Arch Wiki |
| `!gh quickshell` | Searches GitHub |
| `128*42+7` | Shows `128*42+7 = 5383`, Enter copies it |
| `lock`, `record`, `night` | Quick system actions |
| `theme` | Runs the omarchy Theme picker (Style › Theme action) |
| `apps` | Opens the Apps menu inside Spotlight — browse/launch any installed app |
| `install steam` | Runs the Install › Gaming › Steam action |

### Keys

| Key | Action |
|---|---|
| `Enter` | Open / run / drill into selected result |
| `→` | Drill into selected menu section |
| `←` / `Backspace` | Go back to the previous menu section |
| `↑` / `↓` | Navigate results |
| `Delete` | Uninstall the selected app (asks first) |
| `PgUp` / `PgDn` | Jump to first / last |
| `Esc` | Clear query, go back, then dismiss |
| Click outside | Dismiss |

## How the Omarchy menu is built in

Spotlight loads the same menu tree as the `omarchy.menu` plugin — the default `omarchy-menu.jsonc` extended by your user overrides in `~/.config/omarchy/extensions/omarchy-menu.jsonc` — and renders it natively. The `omarchy.menu` plugin is never summoned or shelled out to.

- **On open** you land on the menu root — Apps, Learn, Trigger, Style, Setup, Install, Remove, Update, About, System — the same view the real menu shows at its root.
- **Drill into a section** with `Enter`, `→`, or a click. The header shows your path as a breadcrumb while you're inside (e.g. `‹ Style › Font`).
- **Go back** with `←`, `Backspace`, or `Esc` while the search box is empty; `Esc` clears your query first if you're typing. At the root, `Esc` dismisses.
- Each section lists its **children**, with `when:` conditions applied — so hardware-dependent sections disappear on unsupported machines, exactly like the real menu.
- The **Apps** section lists your installed apps alphabetically via the same apps provider the real menu uses.
- The **Fonts** section (`Style › Font`) runs the real menu's font provider: your current font is marked and `Enter` opens the default font picker for the selected font.
- **Action entries** (Theme picker, `install steam`, the DNS presets, …) run their command straight from Spotlight and close the overlay.
- **Link entries** (most of Learn) open their target in your browser and close the overlay.
- **`checked:` rows** carry a `✓` wherever the real menu would show one.
- **Search is scoped like the real menu**: while inside a section, typing searches that section and its descendants; at the root, typing searches the whole tree alongside apps, files, and commands as usual. Matching menu entries appear in the results either as a section (drill in) or an action (run).

## Bangs

Any query that starts with `!bang` is a [DuckDuckGo bang](https://duckduckgo.com/bang_lite.html) and goes straight to that site's search — no DuckDuckGo round trip, the target URL is built locally:

```
!g omarchy          → https://www.google.com/search?q=omarchy
!gh quickshell      → https://github.com/search?q=quickshell
!aw !ryu            → search the Arch Wiki
!yt lofi girl       → YouTube
```

- The first result is the bang you typed, with the final URL shown as the subtitle — `Enter` opens it, the arrows pick any of the alternates below it.
- **Alternates** are the other bangs that extend what you typed, ranked by DuckDuckGo's own popularity, so `!a` also offers `!aw` (Arch Wiki) and `!aur` (AUR).
- **Misspellings** recover by one character: `!githbu` offers `!git`/`!github`.
- **Unknown bangs** still work — the row falls back to `duckduckgo.com/?q=!bang term` so DuckDuckGo can resolve it, with a plain web search as the last resort.
- No term? `!gh` just opens the site's search page with an empty box.

The list lives in `bangs.txt` (1.3 MB, 13,489 bangs), loaded from disk the first time you type a bang and kept in memory afterwards. Refresh it with:

```sh
./update-bangs.py
```

## Requirements

- [Omarchy](https://omarchy.org) (plugin system + omarchy-shell)
- `fd` (included with Omarchy; used for file search)
- `wl-copy` from `wl-clipboard` (to copy calculation results)

## Removal

```sh
omarchy plugin remove mihai.spotlight
```

And delete or comment out the line you added to `~/.config/hypr/bindings.lua`.

## Feedback & contributing

Issues, ideas, and PRs are welcome — this is a hobby project built for my own setup, but others are free to fork it and make it their own.

## License

[MIT](https://opensource.org/licenses/MIT) © mihai
