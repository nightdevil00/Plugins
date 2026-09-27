import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "mihai.displays"
  ipcTarget: "mihai.displays"
  manageIpc: true

  property var monitors: []
  property string selected: ""
  property var terminalSizes: ({})

  // Absolute path to this plugin's bundled scripts, so the panel works on
  // install without relying on the shell's PATH. (Qt.resolvedUrl(".") is the
  // directory of this Panel.qml.)
  readonly property string scriptDir: Qt.resolvedUrl(".").toString().replace("file://", "") + "/bin"

  readonly property var scalePresets: ["1", "1.25", "1.6", "2", "3", "4"]
  readonly property var transformPresets: ["0", "1", "2", "3"]
  readonly property var terminals: ["alacritty", "kitty", "ghostty", "foot"]

  function shellEscape(s) {
    if (s === undefined || s === null) return "''"
    var str = String(s)
    return "'" + str.replace(/'/g, "'\\''") + "'"
  }

  function selectedMonitor() {
    if (!root.monitors || root.monitors.length === 0) return null
    for (var i = 0; i < root.monitors.length; i++)
      if (root.monitors[i].name === root.selected) return root.monitors[i]
    for (var j = 0; j < root.monitors.length; j++)
      if (root.monitors[j].focused) return root.monitors[j]
    return root.monitors[0]
  }

  function currentModeString(m) {
    if (!m || !m.modes || m.modes.length === 0) return ""
    var best = ""
    var bestDiff = 1e9
    var cur = Number(m.refreshRate)
    for (var i = 0; i < m.modes.length; i++) {
      var s = m.modes[i]
      var at = s.indexOf("@")
      if (at < 0) continue
      var dims = s.slice(0, at)
      var rate = parseFloat(s.slice(at + 1).replace("Hz", ""))
      if (!isNaN(rate) && dims === (m.width + "x" + m.height)) {
        var diff = Math.abs(rate - cur)
        if (diff < bestDiff) { bestDiff = diff; best = s }
      }
    }
    return best
  }

  function modeOptions(m) {
    if (!m || !m.modes) return []
    var seen = {}
    var out = []
    for (var i = 0; i < m.modes.length; i++) {
      var s = m.modes[i]
      if (!s || seen[s]) continue
      seen[s] = true
      out.push({ value: s, label: s })
    }
    return out
  }

  function refresh() {
    if (!monitorProc.running) monitorProc.running = true
    if (!termProc.running) termProc.running = true
  }

  function setMonitor(flag, val) {
    var m = root.selectedMonitor()
    if (!m) return
    actionProc.command = ["bash", "-c", root.scriptDir + "/omarchy-display-monitor set " + root.shellEscape(m.name) + " " + root.shellEscape(flag) + " " + root.shellEscape(val)]
    if (!actionProc.running) actionProc.running = true
  }

  function setTerminal(term, size) {
    actionProc.command = ["bash", "-c", root.scriptDir + "/omarchy-display-terminal set " + root.shellEscape(term) + " " + root.shellEscape(size)]
    if (!actionProc.running) actionProc.running = true
  }

  function stepTerminal(term, delta) {
    var cur = Number(root.terminalSizes[term] || 0)
    if (!(cur > 0)) return
    var next = cur + delta
    if (next < 6) next = 6
    if (next > 40) next = 40
    root.setTerminal(term, next)
  }

  function posFor(selected, other, dir) {
    var sw = selected.width, sh = selected.height
    var ox = other.x, oy = other.y, ow = other.width, oh = other.height
    if (dir === "left") return (ox - sw) + "x" + oy
    if (dir === "right") return (ox + ow) + "x" + oy
    if (dir === "above") return ox + "x" + (oy - sh)
    if (dir === "below") return ox + "x" + (oy + oh)
    return "auto"
  }

  function monitorByName(name) {
    for (var i = 0; i < root.monitors.length; i++)
      if (root.monitors[i].name === name) return root.monitors[i]
    return null
  }

  function positionButtons() {
    var sel = root.selectedMonitor()
    if (!sel) return []
    var out = []
    var dirs = [
      { dir: "left", glyph: "◀" },
      { dir: "right", glyph: "▶" },
      { dir: "above", glyph: "▲" },
      { dir: "below", glyph: "▼" }
    ]
    for (var i = 0; i < root.monitors.length; i++) {
      var o = root.monitors[i]
      if (o.name === root.selected) continue
      for (var d = 0; d < dirs.length; d++)
        out.push({ label: dirs[d].glyph + " " + o.name, other: o.name, dir: dirs[d].dir })
    }
    return out
  }

  Component.onCompleted: {
    root.refresh()
    // Install the backend scripts onto PATH on first load so the `omarchy
    // display` CLI group and the Display menu submenu work after the plugin
    // is added/enabled. Idempotent — safe to run every load.
    if (!installProc.running) installProc.running = true
  }

  onOpenedChanged: if (opened) refresh()

  Timer {
    interval: 4000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: monitorProc
    command: ["bash", "-c", "hyprctl monitors -j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var arr = JSON.parse(String(text || "[]"))
          var out = []
          for (var i = 0; i < arr.length; i++) {
            var d = arr[i]
            var modeStrings = []
            if (Array.isArray(d.modes)) {
              for (var mi = 0; mi < d.modes.length; mi++) {
                var rm = d.modes[mi]
                if (rm && rm.width) modeStrings.push(rm.width + "x" + rm.height + "@" + rm.refreshRate)
              }
            }
            if (modeStrings.length === 0 && Array.isArray(d.availableModes))
              modeStrings = d.availableModes.slice()
            out.push({
              name: d.name,
              width: d.width, height: d.height,
              x: d.x, y: d.y,
              scale: d.scale, transform: d.transform,
              focused: !!d.focused,
              modes: modeStrings
            })
          }
          root.monitors = out
          if (!root.selected) {
            for (var k = 0; k < out.length; k++) if (out[k].focused) root.selected = out[k].name
            if (!root.selected && out.length) root.selected = out[0].name
          }
        } catch (e) { /* ignore parse errors */ }
      }
    }
  }

  Process {
    id: termProc
    command: ["bash", "-c", root.scriptDir + "/omarchy-display-terminal list --json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.terminalSizes = JSON.parse(String(text || "{}")) }
        catch (e) { /* ignore */ }
      }
    }
  }

  Process {
    id: installProc
    command: ["bash", "-c", root.scriptDir + "/../install --silent"]
    stdout: StdioCollector { waitForEnd: true }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Quickshell.screens.length > 1 ? "󰍺" : "󰍹"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(640))

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        // ---------- Hero ----------
        Item {
          width: parent.width
          implicitHeight: heroIcon.implicitHeight
          Text {
            id: heroIcon
            text: "󰍹"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "Displays"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---------- Monitor selector ----------
        PanelSeparator { foreground: root.bar.foreground }
        PanelSectionHeader { text: "MONITOR"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }

        Row {
          width: parent.width
          spacing: Style.spacing.xs
          Repeater {
            model: root.monitors
            Button {
              required property var modelData
              text: modelData.name
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              bordered: true
              active: root.selected === modelData.name
              onClicked: root.selected = modelData.name
            }
          }
        }

        // ---------- Resolution / Scale / Position / Orientation ----------
        PanelSeparator { foreground: root.bar.foreground }
        Column {
          width: parent.width
          spacing: Style.space(10)
          PanelSectionHeader { text: "RESOLUTION"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          SearchableDropdown {
            width: parent.width
            foreground: root.bar.foreground
            value: root.currentModeString(root.selectedMonitor())
            options: root.modeOptions(root.selectedMonitor())
            onChanged: function(v) { root.setMonitor("--mode", v) }
          }

          PanelSectionHeader { text: "SCALE"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          Row {
            width: parent.width
            spacing: Style.spacing.xs
            Repeater {
              model: root.scalePresets
              Button {
                required property string modelData
                text: modelData + "x"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.caption
                bordered: true
                active: {
                  var m = root.selectedMonitor()
                  m && Math.abs(Number(m.scale) - Number(modelData)) < 0.001
                }
                onClicked: root.setMonitor("--scale", modelData)
              }
            }
          }

          PanelSectionHeader { text: "POSITION"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          Flow {
            width: parent.width
            spacing: Style.spacing.xs
            Button {
              text: "Auto"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.setMonitor("--pos", "auto")
            }
            Repeater {
              model: root.positionButtons()
              Button {
                required property var modelData
                text: modelData.label
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: {
                  var m = root.selectedMonitor()
                  var other = root.monitorByName(modelData.other)
                  if (m && other) root.setMonitor("--pos", root.posFor(m, other, modelData.dir))
                }
              }
            }
          }

          PanelSectionHeader { text: "ORIENTATION"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          Row {
            width: parent.width
            spacing: Style.spacing.xs
            Repeater {
              model: root.transformPresets
              Button {
                required property string modelData
                text: ({ "0": "0°", "1": "90°", "2": "180°", "3": "270°" })[modelData]
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.caption
                bordered: true
                active: {
                  var m = root.selectedMonitor()
                  m && Number(m.transform) === Number(modelData)
                }
                onClicked: root.setMonitor("--transform", modelData)
              }
            }
          }
        }

        // ---------- Terminal fonts ----------
        PanelSeparator { foreground: root.bar.foreground }
        PanelSectionHeader { text: "TERMINAL FONT"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
        Column {
          width: parent.width
          spacing: Style.space(8)
          Repeater {
            model: root.terminals
            Row {
              required property string modelData
              width: parent.width
              spacing: Style.spacing.sm
              Text {
                text: modelData
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(86)
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }
              Button {
                text: "−"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.body
                bordered: true
                onClicked: root.stepTerminal(modelData, -1)
              }
              Text {
                text: String(root.terminalSizes[modelData] || "—")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                width: Style.space(34)
                anchors.verticalCenter: parent.verticalCenter
              }
              Button {
                text: "+"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.body
                bordered: true
                onClicked: root.stepTerminal(modelData, 1)
              }
            }
          }
        }

        Item { width: parent.width; height: Style.space(4) }
      }
    }
  }
}
