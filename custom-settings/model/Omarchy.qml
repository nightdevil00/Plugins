pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Everything the app changes that is not a Hyprland option: the theme, the
// monospace font, monitors, shell plugins, the bar, idle timing and the
// night light. Live state is read from the Omarchy CLI and shell.json.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string shellJsonPath: home + "/.config/omarchy/shell.json"

  property var themes: []
  property string theme: ""
  property var fonts: []
  property string font: ""
  property var monitors: []
  property var plugins: []
  property int idleScreensaver: 150
  property int idleLock: 300
  property bool nightlightEnabled: false
  property int nightlightTemp: 6000
  property string barPosition: "top"
  property bool barTransparent: false
  property string version: ""
  property string fastfetchText: ""
  property string channel: ""
  property string branch: ""
  property string lastUpdate: ""
  property bool updatesAvailable: false
  property bool checkingUpdates: false
  property string updateSummary: ""
  property var themeExtras: []
  property bool loading: false
  property string message: ""

  property var shellConfig: ({})

  // ------------------------------------------------------------- readers

  function reload() {
    loading = true
    themeListProc.running = true
    themeCurrentProc.running = true
    fontListProc.running = true
    fontCurrentProc.running = true
    monitorProc.running = true
    pluginProc.running = true
    nightProc.running = true
    versionProc.running = true
    channelProc.running = true
    branchProc.running = true
    lastUpdateProc.running = true
    refreshFastfetch()
    shellFile.reload()
  }

  // The Updates page asks these on demand: `omarchy-update-available` reaches
  // the package databases, so it is never part of the routine reload.
  function refreshUpdates() {
    checkingUpdates = true
    updateCheckProc.running = true
    themeExtrasProc.running = true
  }

  Process {
    id: channelProc
    command: ["omarchy-version-channel"]
    stdout: StdioCollector { id: channelOut; waitForEnd: true }
    onExited: root.channel = channelOut.text.trim()
  }

  Process {
    id: branchProc
    command: ["omarchy-version-branch"]
    stdout: StdioCollector { id: branchOut; waitForEnd: true }
    onExited: root.branch = branchOut.text.trim()
  }

  Process {
    id: lastUpdateProc
    command: ["omarchy-version-pkgs"]
    stdout: StdioCollector { id: lastUpdateOut; waitForEnd: true }
    onExited: root.lastUpdate = lastUpdateOut.text.trim()
  }

  Process {
    id: updateCheckProc
    command: ["omarchy-update-available"]
    stdout: StdioCollector { id: updateCheckOut; waitForEnd: true }
    onExited: function (code) {
      var text = String(updateCheckOut.text).trim()
      root.updatesAvailable = code === 0 && text.length > 0 && text.indexOf("up to date") === -1
      root.updateSummary = text
      root.checkingUpdates = false
    }
  }

  Process {
    id: themeExtrasProc
    command: ["omarchy-theme-extras"]
    stdout: StdioCollector { id: themeExtrasOut; waitForEnd: true }
    onExited: {
      root.themeExtras = themeExtrasOut.text.split("\n").map(function (s) { return s.trim() }).filter(function (s) { return s.length > 0 })
    }
  }

  // The About page mirrors the fastfetch summary Omarchy shows. Only the module
  // column is rendered (the logo is a terminal animation and too large here),
  // with the ANSI the generator emits stripped so it draws in the shell palette.
  function refreshFastfetch() {
    fastfetchProc.running = true
  }

  Process {
    id: fastfetchProc
    command: ["bash", "-c", "fastfetch --pipe true --logo none 2>/dev/null | sed 's/\\x1b\\[[0-9;?]*[a-zA-Z]//g'"]
    stdout: StdioCollector { id: fastfetchOut; waitForEnd: true }
    onExited: root.fastfetchText = String(fastfetchOut.text).replace(/^\n+/, "").replace(/\s+$/, "")
  }

  Process {
    id: versionProc
    command: ["omarchy", "version"]
    stdout: StdioCollector { id: versionOut; waitForEnd: true }
    onExited: root.version = versionOut.text.trim()
  }

  Process {
    id: themeListProc
    command: ["omarchy", "theme", "list"]
    stdout: StdioCollector { id: themeListOut; waitForEnd: true }
    onExited: {
      root.themes = themeListOut.text.split("\n").map(function (s) { return s.trim() }).filter(function (s) { return s.length > 0 })
    }
  }

  Process {
    id: themeCurrentProc
    command: ["omarchy", "theme", "current"]
    stdout: StdioCollector { id: themeCurrentOut; waitForEnd: true }
    onExited: root.theme = themeCurrentOut.text.trim()
  }

  Process {
    id: fontListProc
    command: ["omarchy", "font", "list"]
    stdout: StdioCollector { id: fontListOut; waitForEnd: true }
    onExited: {
      root.fonts = fontListOut.text.split("\n").map(function (s) { return s.trim() }).filter(function (s) { return s.length > 0 })
    }
  }

  Process {
    id: fontCurrentProc
    command: ["omarchy", "font", "current"]
    stdout: StdioCollector { id: fontCurrentOut; waitForEnd: true }
    onExited: root.font = fontCurrentOut.text.trim()
  }

  Process {
    id: monitorProc
    command: ["hyprctl", "-j", "monitors", "all"]
    stdout: StdioCollector { id: monitorOut; waitForEnd: true }
    onExited: {
      try { root.monitors = JSON.parse(monitorOut.text) } catch (e) { root.monitors = [] }
    }
  }

  Process {
    id: pluginProc
    command: ["omarchy", "plugin", "list", "--json"]
    stdout: StdioCollector { id: pluginOut; waitForEnd: true }
    onExited: {
      try { root.plugins = JSON.parse(pluginOut.text) } catch (e) { root.plugins = [] }
      root.loading = false
    }
  }

  Process {
    id: nightProc
    command: ["hyprctl", "hyprsunset", "temperature"]
    stdout: StdioCollector { id: nightOut; waitForEnd: true }
    onExited: {
      var m = String(nightOut.text).match(/[0-9]+/)
      if (m) {
        root.nightlightTemp = parseInt(m[0], 10)
        root.nightlightEnabled = root.nightlightTemp < 6000
      } else {
        root.nightlightEnabled = false
      }
    }
  }

  // -------------------------------------------------------------- config

  FileView {
    id: shellFile
    path: root.shellJsonPath
    watchChanges: true
    printErrors: false
    onLoaded: root.adoptShell(shellFile.text())
    onFileChanged: reload()
    onLoadFailed: print("custom-settings: could not read " + path)
  }

  FileView {
    id: shellWriter
    path: root.shellJsonPath
    watchChanges: false
    atomicWrites: true
  }

  function adoptShell(text) {
    try {
      var obj = JSON.parse(text)
      shellConfig = obj || {}
    } catch (e) {
      shellConfig = {}
    }
    var bar = shellConfig.bar || {}
    barPosition = bar.position || "top"
    barTransparent = bar.transparent === true
    var idle = shellConfig.idle || {}
    idleScreensaver = idle.screensaver !== undefined ? idle.screensaver : 150
    idleLock = idle.lock !== undefined ? idle.lock : 300
  }

  // ------------------------------------------------------------- actions

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function (code) {
      if (code !== 0) {
        var e = String(actionErr.text).trim()
        root.message = e.length > 0 ? e.split("\n")[0] : "Command failed"
      } else {
        root.message = ""
      }
      actionTimer.restart()
    }
  }

  Timer {
    id: actionTimer
    interval: 350
    onTriggered: root.reload()
  }

  function run(argv) {
    actionProc.command = argv
    actionProc.running = true
  }

  function setTheme(name) {
    if (!name || name === theme) return
    run(["omarchy", "theme", "set", name])
  }

  function setFont(name) {
    if (!name || name === font) return
    run(["omarchy", "font", "set", name])
  }

  function setBarPosition(pos) {
    if (pos === barPosition) return
    run(["omarchy", "bar", "position", pos])
  }

  function setBarTransparent(on) {
    run(["omarchy", "bar", "transparent", on ? "true" : "false"])
  }

  function toggleBar() {
    run(["omarchy", "toggle", "bar"])
  }

  function setPluginEnabled(id, enabled) {
    run(["omarchy", "plugin", enabled ? "enable" : "disable", id])
  }

  function setIdle(kind, minutes) {
    var obj = JSON.parse(JSON.stringify(shellConfig))
    if (!obj.idle) obj.idle = {}
    obj.idle[kind] = minutes
    shellConfig = obj
    shellWriter.setText(JSON.stringify(obj, null, 2))
    if (kind === "screensaver") idleScreensaver = minutes
    else idleLock = minutes
  }

  // Updates need sudo and print progress, so they run in the floating terminal
  // Omarchy uses for the same jobs from its menu. Restarting the shell does not
  // need a terminal and runs detached.
  function terminal(command) {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", command])
  }

  function updateOmarchy() {
    terminal("omarchy-update")
  }

  function setChannel(name) {
    if (!name || name === channel) return
    terminal("omarchy-channel-set " + name)
  }

  function updatePlugins() {
    terminal("omarchy-plugin-update")
  }

  function updateThemes() {
    terminal("omarchy-theme-update")
  }

  function updateFirmware() {
    terminal("omarchy-update-firmware")
  }

  function restartShell() {
    Quickshell.execDetached(["omarchy-restart-shell"])
  }

  function setNightlight(enabled) {
    if (!enabled) {
      run(["hyprctl", "hyprsunset", "temperature", "6500"])
      nightlightEnabled = false
      return
    }
    applyNightlightTemp(nightlightTemp < 6000 ? nightlightTemp : 4000)
  }

  function setNightlightTemp(kelvin) {
    nightlightTemp = kelvin
    applyNightlightTemp(kelvin)
  }

  function applyNightlightTemp(kelvin) {
    var script = "pgrep -x hyprsunset >/dev/null || (setsid uwsm-app -- hyprsunset >/dev/null 2>&1 &); "
      + "for i in 1 2 3 4 5 6 7 8 9 10; do "
      + "hyprctl hyprsunset temperature " + kelvin + " >/dev/null 2>&1; sleep 0.2; "
      + "[ \"$(hyprctl hyprsunset temperature 2>/dev/null | grep -oE '[0-9]+' | head -1)\" = \"" + kelvin + "\" ] && break; done"
    run(["bash", "-c", script])
    nightlightEnabled = kelvin < 6000
  }

  Component.onCompleted: reload()
}
