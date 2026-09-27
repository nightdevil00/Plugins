import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "plugin.hider"

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var keepVisible: setting("keepVisible", [])
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

  readonly property bool allHidden: {
    for (var i = 0; i < rightEntries.length; i++) {
      var eid = entryId(rightEntries[i])
      if (eid !== root.moduleName && keepVisible.indexOf(eid) === -1) return false
    }
    return true
  }

  function entryId(entry) {
    if (typeof entry === "string") return entry
    if (entry && typeof entry === "object") return String(entry.id || "")
    return ""
  }

  function hideAll() {
    var toHide = []
    for (var i = 0; i < rightEntries.length; i++) {
      var eid = entryId(rightEntries[i])
      if (eid !== root.moduleName && keepVisible.indexOf(eid) === -1)
        toHide.push(rightEntries[i])
    }
    if (toHide.length === 0) return

    bar.shell.mutateShellConfig(function(config) {
      var sections = ["left", "center", "right"]
      for (var s = 0; s < sections.length; s++) {
        var entries = config.bar && config.bar.layout ? config.bar.layout[sections[s]] || [] : []
        for (var j = 0; j < entries.length; j++) {
          if (entryId(entries[j]) === root.moduleName) {
            entries[j].hiddenEntries = toHide
            break
          }
        }
      }
      var right = config.bar && config.bar.layout ? config.bar.layout.right : []
      config.bar.layout.right = right.filter(function(e) {
        var eid = entryId(e)
        return eid === root.moduleName || root.keepVisible.indexOf(eid) !== -1
      })
    })
  }

  function showAll() {
    if (hiddenEntries.length === 0) return

    bar.shell.mutateShellConfig(function(config) {
      var right = config.bar && config.bar.layout ? config.bar.layout.right : []
      for (var i = 0; i < hiddenEntries.length; i++) {
        right.push(hiddenEntries[i])
      }
      config.bar.layout.right = right

      var sections = ["left", "center", "right"]
      for (var s = 0; s < sections.length; s++) {
        var entries = config.bar && config.bar.layout ? config.bar.layout[sections[s]] || [] : []
        for (var j = 0; j < entries.length; j++) {
          if (entryId(entries[j]) === root.moduleName) {
            entries[j].hiddenEntries = []
            break
          }
        }
      }
    })
  }

  implicitWidth: vertical ? barSize : expandIcon.implicitWidth
  implicitHeight: vertical ? expandIcon.implicitHeight : barSize

  BarIconButton {
    id: expandIcon
    bar: root.bar
    anchors.fill: parent
    text: "\uf053"
    textRotation: root.allHidden ? 0 : 180

    Behavior on textRotation {
      RotationAnimation {
        duration: 200
        direction: RotationAnimation.Shortest
      }
    }

    onPressed: function(button) {
      if (root.allHidden) root.showAll()
      else root.hideAll()
    }
  }
}
