pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Schema.js" as Schema
import "Lua.js" as Lua

// The single source of truth for Hyprland settings the app manages.
//
//  * live values come from `hyprctl -j getoption`
//  * values the user changed live in `managed` and in the state sidecar
//  * applying regenerates ~/.config/hypr/settings.lua and reloads Hyprland
//
// A value present in `managed` always wins for display, so the UI responds
// the instant a control moves rather than after the reload round-trip.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string hyprDir: home + "/.config/hypr"
  readonly property string luaPath: hyprDir + "/settings.lua"
  readonly property string hyprlandPath: hyprDir + "/hyprland.lua"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/settings"
  readonly property string statePath: stateDir + "/hypr.json"

  readonly property var pages: Schema.pages
  readonly property var schema: Schema.settings

  property var managed: ({})
  property var managedMonitors: []
  property var effective: ({})
  property bool loaded: false
  property bool applying: false
  property string status: "Loading…"
  property var errors: []

  // ---------------------------------------------------------------- lookup

  function value(id) {
    if (Object.prototype.hasOwnProperty.call(managed, id)) return managed[id]
    if (Object.prototype.hasOwnProperty.call(effective, id)) return effective[id]
    var s = Schema.settingById(id)
    return s ? s.default : undefined
  }

  function isManaged(id) {
    return Object.prototype.hasOwnProperty.call(managed, id)
  }

  function pageById(id) {
    return Schema.pageById(id)
  }

  function looseEqual(a, b) {
    if (typeof a === "number" || typeof b === "number") return Number(a) === Number(b)
    return String(a) === String(b)
  }

  function isChanged(id) {
    var s = Schema.settingById(id)
    if (!s) return false
    return !looseEqual(value(id), s.default)
  }

  function managedCount() {
    return Object.keys(managed).length
  }

  // ---------------------------------------------------------------- mutate

  function set(id, v) {
    if (!root.loaded) {
      console.warn("[settings] set " + id + " ignored: state not loaded yet")
      return
    }
    var next = {}
    var keys = Object.keys(managed)
    for (var i = 0; i < keys.length; i++) next[keys[i]] = managed[keys[i]]
    next[id] = v
    managed = next
    scheduleApply()
  }

  function reset(id) {
    if (!root.loaded || !isManaged(id)) return
    var next = {}
    var keys = Object.keys(managed)
    for (var i = 0; i < keys.length; i++) {
      if (keys[i] === id) continue
      next[keys[i]] = managed[keys[i]]
    }
    managed = next
    scheduleApply()
  }

  function toggle(id) {
    set(id, !value(id))
  }

  function resetAll() {
    if (!root.loaded) return
    if (managedCount() === 0 && managedMonitors.length === 0) return
    managed = ({})
    managedMonitors = []
    scheduleApply()
  }

  // ------------------------------------------------------------- monitors

  function monitorOverride(output) {
    for (var i = 0; i < managedMonitors.length; i++)
      if (managedMonitors[i].output === output) return managedMonitors[i]
    return null
  }

  function monitorValue(m, key, fallback) {
    var o = monitorOverride(m.name)
    if (o && o[key] !== undefined) return o[key]
    if (m[key] !== undefined) return m[key]
    return fallback
  }

  function isMonitorManaged(output) {
    return monitorOverride(output) !== null
  }

  function setMonitor(output, changes) {
    if (!root.loaded) return
    var next = []
    var found = null
    for (var i = 0; i < managedMonitors.length; i++) {
      if (managedMonitors[i].output === output) found = managedMonitors[i]
      else next.push(managedMonitors[i])
    }
    var entry = found ? JSON.parse(JSON.stringify(found)) : { output: output }
    var keys = Object.keys(changes)
    for (var k = 0; k < keys.length; k++) entry[keys[k]] = changes[keys[k]]
    next.push(entry)
    managedMonitors = next
    scheduleApply()
  }

  function resetMonitor(output) {
    if (!root.loaded) return
    var next = []
    for (var i = 0; i < managedMonitors.length; i++)
      if (managedMonitors[i].output !== output) next.push(managedMonitors[i])
    managedMonitors = next
    scheduleApply()
  }

  function scheduleApply() {
    applying = true
    status = "Applying…"
    applyTimer.restart()
  }

  // ------------------------------------------------------------ file state

  FileView {
    id: stateFile
    path: root.statePath
    preload: true
    watchChanges: false
    onLoaded: root.adoptState(stateFile.text())
    onLoadFailed: {
      root.managed = ({})
      root.loaded = true
      root.refresh()
    }
  }

  FileView {
    id: stateBackupFile
    path: root.statePath + ".bak"
    preload: false
    watchChanges: false
    atomicWrites: true
  }

  FileView {
    id: hyprlandFile
    path: root.hyprlandPath
    preload: true
    watchChanges: false
  }

  FileView {
    id: luaFile
    path: root.luaPath
    preload: false
    watchChanges: false
    atomicWrites: true
  }

  FileView {
    id: stateWriteFile
    path: root.statePath
    preload: false
    watchChanges: false
    atomicWrites: true
  }

  function adoptState(text) {
    try {
      var obj = JSON.parse(text)
      if (obj && obj.managed && typeof obj.managed === "object") managed = obj.managed
      else managed = ({})
      if (obj && Array.isArray(obj.monitors)) managedMonitors = obj.monitors
      else managedMonitors = []
    } catch (e) {
      managed = ({})
      managedMonitors = []
    }
    loaded = true
    refresh()
    refreshEnvironment()
    if (managedCount() > 0 || managedMonitors.length > 0) scheduleApply()
  }

  // ------------------------------------------------------------- apply loop

  Timer {
    id: applyTimer
    interval: 120
    onTriggered: root.writeAndApply()
  }

  function writeAndApply() {
    luaFile.setText(Lua.generate(root.managed, root.schema, root.managedMonitors))

    if (stateFile.loaded && stateFile.text().length > 0) {
      stateBackupFile.setText(stateFile.text())
    }

    if (hyprlandFile.loaded) {
      var current = hyprlandFile.text()
      if (root.managedCount() > 0 || root.managedMonitors.length > 0) {
        var ensured = Lua.ensureRequire(current)
        if (ensured.changed) hyprlandFile.setText(ensured.text)
      } else {
        var removed = Lua.removeRequire(current)
        if (removed.changed) hyprlandFile.setText(removed.text)
      }
    } else {
      var current = ""
      var ensured = Lua.ensureRequire(current)
      if (ensured.changed) hyprlandFile.setText(ensured.text)
    }

    stateWriteFile.setText(JSON.stringify({ managed: root.managed, monitors: root.managedMonitors }, null, 2))
    reloadTimer.restart()
  }

  Timer {
    id: reloadTimer
    interval: 220
    onTriggered: reloadProc.running = true
  }

  Process {
    id: reloadProc
    command: ["bash", "-c", "hyprctl reload >/dev/null 2>&1; hyprctl configerrors"]
    stdout: StdioCollector { id: reloadOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function (code) {
      var out = reloadOut.text.trim()
      if (out.length === 0) {
        root.errors = []
        root.status = "Applied"
      } else {
        root.errors = out.split("\n")
        root.status = "Config has " + root.errors.length + " problem(s)"
      }
      root.applying = false
      root.refresh()
    }
  }

  // --------------------------------------------------------- effective read

  Process {
    id: getProc
    stdout: StdioCollector { id: getOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: root.parseEffective(getOut.text)
  }

  // ------------------------------------------------------- env vars read

  property var envSettingIds: []

  function buildEnvSettingIds() {
    var out = []
    for (var i = 0; i < root.schema.length; i++) {
      var s = root.schema[i]
      if (s.id && s.id.startsWith("env.") && s.lua && s.lua.length >= 2 && s.lua[0] === "env") {
        out.push({ id: s.id, key: s.lua[1] })
      }
    }
    envSettingIds = out
  }

  function readEnvironmentVariables() {
    var result = {}
    for (var i = 0; i < envSettingIds.length; i++) {
      var entry = envSettingIds[i]
      var val = Quickshell.env(entry.key)
      if (val !== null && val !== undefined && val.length > 0) {
        result[entry.id] = val
      }
    }
    return result
  }

  property var optionToId: ({})

  function buildOptionMap() {
    var map = ({}),
      opts = Schema.hyprOptions()
    for (var i = 0; i < opts.length; i++) {
      var s = null
      for (var j = 0; j < root.schema.length; j++) {
        if (root.schema[j].hypr === opts[i]) { s = root.schema[j]; break }
      }
      if (s) map[opts[i]] = s.id
    }
    optionToId = map
  }

  function refresh() {
    if (Object.keys(optionToId).length === 0) buildOptionMap()
    if (envSettingIds.length === 0) buildEnvSettingIds()
    var opts = Schema.hyprOptions()
    var script = ""
    for (var i = 0; i < opts.length; i++) {
      script += "hyprctl -j getoption " + JSON.stringify(opts[i]) + " 2>/dev/null\n"
    }
    getProc.command = ["bash", "-c", script]
    getProc.running = true
  }

  function refreshEnvironment() {
    if (envSettingIds.length === 0) buildEnvSettingIds()
    var envResult = readEnvironmentVariables()
    var updated = false
    var keys = Object.keys(envResult)
    for (var i = 0; i < keys.length; i++) {
      var id = keys[i]
      var val = envResult[id]
      if (!Object.prototype.hasOwnProperty.call(effective, id) || effective[id] !== val) {
        effective[id] = val
        updated = true
      }
    }
    if (updated && !applying) status = "Ready"
  }

  function parseEffective(text) {
    var result = {}
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line.length === 0) continue
      var obj = null
      try { obj = JSON.parse(line) } catch (e) { continue }
      if (!obj || !obj.option) continue
      var id = optionToId[obj.option]
      if (!id) continue
      if (obj.hasOwnProperty("bool")) result[id] = obj.bool
      else if (obj.hasOwnProperty("int")) result[id] = obj.int
      else if (obj.hasOwnProperty("float")) result[id] = obj.float
      else if (obj.hasOwnProperty("str")) result[id] = obj.str
      else if (obj.hasOwnProperty("css")) {
        var raw = String(obj.css).trim()
        var n = parseFloat(raw)
        result[id] = isNaN(n) ? raw : n
      }
    }

    // Merge environment variables
    var envResult = readEnvironmentVariables()
    var envKeys = Object.keys(envResult)
    for (var i = 0; i < envKeys.length; i++) {
      var id = envKeys[i]
      if (!Object.prototype.hasOwnProperty.call(managed, id)) {
        result[id] = envResult[id]
      }
    }

    // App-only settings never appear from hyprctl; fall back to default.
    for (var k = 0; k < root.schema.length; k++) {
      var s = root.schema[k]
      if (!s.hypr && !result.hasOwnProperty(s.id) && !Object.prototype.hasOwnProperty.call(root.managed, s.id)) {
        result[s.id] = s.default
      }
    }
    effective = result
    if (!applying) status = "Ready"
  }

  Component.onCompleted: {
    buildOptionMap()
    buildEnvSettingIds()
    // preload:true already loads when path resolves; this retry covers a
    // transient failure so the state is never adopted empty on first open.
    Qt.callLater(function() {
      if (!stateFile.loaded && !root.loaded) stateFile.reload()
    })
  }
}
