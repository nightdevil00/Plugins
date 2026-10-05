import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "plugin.hider"

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  readonly property var keepVisible: {
    var value = setting("keepVisible", [])
    return Array.isArray(value) ? value : []
  }
  readonly property var rightEntries: bar && bar.layoutConfig ? (bar.layoutConfig.right || []) : []
  readonly property var hiddenEntries: {
    if (!bar || !bar.layoutConfig) return []
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = bar.layoutConfig[sections[s]] || []
      for (var i = 0; i < entries.length; i++) {
        if (entryId(entries[i]) === root.moduleName) {
          return entries[i].hiddenEntries || []
        }
      }
    }
    return []
  }

  readonly property bool collapsed: hiddenEntries.length > 0

  implicitWidth: vertical ? barSize : expandIcon.implicitWidth
  implicitHeight: vertical ? expandIcon.implicitHeight : barSize

  // A bar-widget plugin is not a replacement bar, so the shell hands it a
  // scoped PluginShellApi whose mutateShellConfig() is gated off: it answers
  // false and never runs the mutator. shell.json is written here instead, and
  // the shell watches that file, so the bar rebuilds off the save.
  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
  }

  function entryId(entry) {
    if (typeof entry === "string") return entry
    if (entry && typeof entry === "object") return String(entry.id || "")
    return ""
  }

  function findOwnEntry(layout) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++) {
        if (entryId(entries[i]) === root.moduleName) return entries[i]
      }
    }
    return null
  }

  function parsedConfig() {
    var raw = configFile.text()
    if (!raw) configFile.reload()
    var config = null
    try {
      config = JSON.parse(raw)
    } catch (e) {
      return null
    }
    if (!config || typeof config !== "object") return null
    if (!config.bar || typeof config.bar !== "object") config.bar = {}
    if (!config.bar.layout || typeof config.bar.layout !== "object") config.bar.layout = {}
    var layout = config.bar.layout
    if (!Array.isArray(layout.left)) layout.left = []
    if (!Array.isArray(layout.center)) layout.center = []
    if (!Array.isArray(layout.right)) layout.right = []
    return config
  }

  // Mutators return false to abandon the write.
  function commit(mutate) {
    var config = parsedConfig()
    if (!config) return false
    if (mutate(config.bar.layout) === false) return false
    configFile.setText(JSON.stringify(config, null, 2) + "\n")
    return true
  }

  function hideAll() {
    return commit(function(layout) {
      var kept = []
      var hidden = []
      for (var i = 0; i < layout.right.length; i++) {
        var entry = layout.right[i]
        var eid = entryId(entry)
        if (eid === root.moduleName || root.keepVisible.indexOf(eid) !== -1) kept.push(entry)
        else hidden.push({ index: i, entry: entry })
      }
      if (hidden.length === 0) return false

      layout.right = kept
      var own = root.findOwnEntry(layout)
      if (!own) return false
      own.hiddenEntries = hidden
      return true
    })
  }

  function showAll() {
    return commit(function(layout) {
      var own = root.findOwnEntry(layout)
      if (!own || !Array.isArray(own.hiddenEntries) || own.hiddenEntries.length === 0) return false

      var stored = own.hiddenEntries.slice()
      stored.sort(function(a, b) { return Number(a && a.index) - Number(b && b.index) })

      var right = layout.right.slice()
      var present = ({})
      for (var i = 0; i < right.length; i++) present[entryId(right[i])] = true

      for (var k = 0; k < stored.length; k++) {
        var entry = stored[k] && stored[k].entry
        if (!entry) continue
        var eid = entryId(entry)
        if (!eid || present[eid]) continue
        var at = Math.max(0, Math.min(Number(stored[k].index) || 0, right.length))
        right.splice(at, 0, entry)
        present[eid] = true
      }

      layout.right = right
      delete own.hiddenEntries
      return true
    })
  }

  BarIconButton {
    id: expandIcon
    bar: root.bar
    anchors.fill: parent
    text: "\uf053"
    textRotation: root.collapsed ? 180 : 0
    tooltipText: root.collapsed ? "Show hidden bar plugins" : "Hide right section plugins"

    Behavior on textRotation {
      RotationAnimation {
        duration: 200
        direction: RotationAnimation.Shortest
      }
    }

    onPressed: function(button) {
      if (root.collapsed) root.showAll()
      else root.hideAll()
    }
  }
}