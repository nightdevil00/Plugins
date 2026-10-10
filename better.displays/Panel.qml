import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "better.displays"
  ipcTarget: "better.displays"
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

  // --- drag state for the layout canvas -----------------------------------
  // The dragged monitor follows the pointer; the drop resolves to whichever
  // monitor it overlaps most and which side of that monitor the pointer is on.
  property string dragName: ""
  property real dragX: 0
  property real dragY: 0
  property real grabDX: 0
  property real grabDY: 0
  property bool dragMoved: false

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

  function monitorByName(name) {
    for (var i = 0; i < root.monitors.length; i++)
      if (root.monitors[i].name === name) return root.monitors[i]
    return null
  }

  // --- transform helpers ---------------------------------------------------
  //
  // Hyprland reports a monitor's *un-rotated* mode size in width/height and
  // rotates it with `transform`. The box a rotated monitor actually occupies
  // on screen is the swapped pair (measured: a transform=1 monitor at
  // 5000x0 puts the next auto-placed monitor at 6080, i.e. 5000 + height).
  // Every layout computation below must use the occupied box, not the raw
  // mode, or dragged rectangles will not line up with where the cursor is.
  function footW(m) {
    if (!m) return 1
    return (Number(m.transform) % 2 === 1) ? Number(m.height) : Number(m.width)
  }

  function footH(m) {
    if (!m) return 1
    return (Number(m.transform) % 2 === 1) ? Number(m.width) : Number(m.height)
  }

  // --- layout canvas geometry ---------------------------------------------

  // Pixel-space bounds of the whole desktop described by the monitors.
  function layoutBounds() {
    var minX = 0, minY = 0, maxX = 0, maxY = 0
    var arr = root.monitors || []
    for (var i = 0; i < arr.length; i++) {
      var m = arr[i]
      var x = Number(m.x), y = Number(m.y)
      var w = root.footW(m), h = root.footH(m)
      if (i === 0 || x < minX) minX = x
      if (i === 0 || y < minY) minY = y
      if (i === 0 || x + w > maxX) maxX = x + w
      if (i === 0 || y + h > maxY) maxY = y + h
    }
    return { minX: minX, minY: minY, maxX: maxX, maxY: maxY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
  }

  // Which side of `t` the dragged box `d` sits on. Uses the aspect-corrected
  // comparison so a drop that is mostly vertical on a tall monitor snaps
  // above/below instead of left/right.
  function snapSide(d, t) {
    var dx = Math.abs((d.x + d.w / 2) - (t.x + t.w / 2)) / Math.max(1, t.w)
    var dy = Math.abs((d.y + d.h / 2) - (t.y + t.h / 2)) / Math.max(1, t.h)
    if (dx >= dy) return (d.x + d.w / 2) >= (t.x + t.w / 2) ? "right" : "left"
    return (d.y + d.h / 2) >= (t.y + t.h / 2) ? "below" : "above"
  }

  // Best target and the side of it to dock to.
  function dropTarget() {
    var d = canvas.rawRectFor(root.dragName)
    if (!d) return null
    var best = null, bestArea = -1
    for (var i = 0; i < root.monitors.length; i++) {
      var m = root.monitors[i]
      if (m.name === root.dragName) continue
      var r = canvas.rawRectFor(m.name)
      if (!r) continue
      var ox = Math.min(d.x + d.w, r.x + r.w) - Math.max(d.x, r.x)
      var oy = Math.min(d.y + d.h, r.y + r.h) - Math.max(d.y, r.y)
      var area = (ox > 0 && oy > 0) ? ox * oy : 0
      if (area > bestArea) { bestArea = area; best = { name: m.name, rect: r, side: root.snapSide(d, r), area: area } }
    }
    if (bestArea > 0) return best
    // No overlap at all: dock to the nearest monitor by centre distance.
    var dcx = d.x + d.w / 2, dcy = d.y + d.h / 2
    var bestDist = Infinity
    for (var j = 0; j < root.monitors.length; j++) {
      var m2 = root.monitors[j]
      if (m2.name === root.dragName) continue
      var r2 = canvas.rawRectFor(m2.name)
      if (!r2) continue
      var dist = Math.hypot(dcx - (r2.x + r2.w / 2), dcy - (r2.y + r2.h / 2))
      if (dist < bestDist) { bestDist = dist; best = { name: m2.name, rect: r2, side: root.snapSide(d, r2), area: 0 } }
    }
    return best
  }

  // Rectangle the drag would land on right now, in canvas coordinates.
  function dragPreview() {
    if (!root.dragName) return null
    var d = canvas.rawRectFor(root.dragName)
    if (!d) return null
    var t = root.dropTarget()
    if (!t) return null
    var p = root.dockedPixel(d, t)
    return canvas.placePixel(p.name, p.x, p.y, p.w, p.h)
  }

  // Pixel-space landing box for dragged box `d` docked to target `t`.
  function dockedPixel(d, t) {
    var x = t.rect.x, y = t.rect.y
    if (t.side === "left") x = t.rect.x - d.w
    else if (t.side === "right") x = t.rect.x + t.rect.w
    else x = t.rect.x
    if (t.side === "above") y = t.rect.y - d.h
    else if (t.side === "below") y = t.rect.y + t.rect.h
    else y = t.rect.y
    return { x: x, y: y, w: d.w, h: d.h, name: root.dragName || "" }
  }

  // --- writing the layout --------------------------------------------------

  // Rewrite monitors.lua (and apply live) for the whole set of monitors, in
  // the visual order described by the canvas: reading order top-to-bottom then
  // left-to-right. `change` gets a chance to adjust one monitor's entry.
  function applyLayout(change) {
    var entries = []
    for (var i = 0; i < root.monitors.length; i++) {
      var m = root.monitors[i]
      entries.push({
        name: m.name,
        x: Number(m.x), y: Number(m.y),
        w: root.footW(m), h: root.footH(m),
        scale: Number(m.scale) || 1,
        transform: Number(m.transform) || 0
      })
    }
    if (change) change(entries)
    entries.sort(root.layoutCompare)

    var arr = []
    for (var k = 0; k < entries.length; k++) {
      var e = entries[k]
      arr.push({
        output: e.name,
        position: e.auto ? "auto" : (Math.round(e.x) + "x" + Math.round(e.y)),
        scale: e.scale,
        transform: e.transform
      })
    }
    var cmd = root.scriptDir + "/omarchy-display-layout apply --json " + root.shellEscape(JSON.stringify(arr))
    layoutProc.command = ["bash", "-c", cmd]
    if (!layoutProc.running) layoutProc.running = true
  }

  // Files list monitors in the order the panel draws them: rows first (by
  // vertical centre), then columns within a row.
  function layoutCompare(a, b) {
    var ca = a.y + a.h / 2, cb = b.y + b.h / 2
    if (Math.abs(ca - cb) > Math.min(a.h, b.h) / 2) return ca - cb
    return a.x - b.x
  }

  // Move `name` to the docked position computed from the drag. `d` and `t` are
  // captured before the drag state is cleared, because clearing it snaps the
  // dragged rectangle back to its stored position.
  function commitDrop(name, d, t) {
    if (!d) return
    var x = d.x, y = d.y
    if (t) {
      var p = root.dockedPixel(d, t)
      x = p.x
      y = p.y
    }
    root.applyLayout(function(entries) {
      for (var i = 0; i < entries.length; i++)
        if (entries[i].name === name) { entries[i].x = x; entries[i].y = y }
    })
  }

  function rotateSelected(delta) {
    var m = root.selectedMonitor()
    if (!m) return
    var next = ((Number(m.transform) || 0) + delta + 4) % 4
    var name = m.name
    root.applyLayout(function(entries) {
      for (var i = 0; i < entries.length; i++)
        if (entries[i].name === name) entries[i].transform = next
    })
  }

  function setTransform(value) {
    var m = root.selectedMonitor()
    if (!m) return
    var name = m.name
    root.applyLayout(function(entries) {
      for (var i = 0; i < entries.length; i++)
        if (entries[i].name === name) entries[i].transform = value
    })
  }

  function resetAuto() {
    root.applyLayout(function(entries) {
      for (var i = 0; i < entries.length; i++) entries[i].auto = true
    })
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

  Process {
    id: layoutProc
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

        // ---------- Layout canvas ----------
        PanelSeparator { foreground: root.bar.foreground }
        PanelSectionHeader { text: "LAYOUT"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
        Text {
          width: parent.width
          text: "Drag a display to move it. Click to select, right-click to rotate."
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          opacity: 0.7
          wrapMode: Text.WordWrap
        }

        Item {
          id: canvas
          width: parent.width
          height: Style.space(190)
          clip: true

          // Backdrop, so the canvas reads as "the desktop" rather than a gap.
          Rectangle {
            anchors.fill: parent
            color: Style.normalFillFor(root.bar.foreground, ShellColor.accent)
            border.color: Style.normalBorderFor(root.bar.foreground, ShellColor.accent)
            border.width: 1
            radius: Style.cornerRadius
          }

          // Scale + offset that fit every monitor's occupied box inside the
          // canvas with a little padding.
          readonly property real fit: {
            var pad = Style.space(10)
            var b = root.layoutBounds()
            var availW = Math.max(1, canvas.width - pad * 2)
            var availH = Math.max(1, canvas.height - pad * 2)
            return Math.min(availW / b.w, availH / b.h)
          }
          readonly property real offX: (canvas.width - root.layoutBounds().w * canvas.fit) / 2 - root.layoutBounds().minX * canvas.fit
          readonly property real offY: (canvas.height - root.layoutBounds().h * canvas.fit) / 2 - root.layoutBounds().minY * canvas.fit

          // Map a monitor's top-left pixel position into canvas coordinates.
          function placePixel(name, px, py, w, h) {
            return {
              name: name,
              x: px * canvas.fit + canvas.offX,
              y: py * canvas.fit + canvas.offY,
              w: w * canvas.fit,
              h: h * canvas.fit
            }
          }

          // Occupied box of a monitor in pixel space. For the dragged monitor
          // the pointer position drives it, not its stored x/y.
          function rawRectFor(name) {
            for (var i = 0; i < root.monitors.length; i++) {
              var m = root.monitors[i]
              if (m.name !== name) continue
              var w = root.footW(m), h = root.footH(m)
              if (name === root.dragName) {
                var dx = (root.dragX - root.grabDX) / Math.max(0.001, canvas.fit)
                var dy = (root.dragY - root.grabDY) / Math.max(0.001, canvas.fit)
                return { x: Number(m.x) + dx, y: Number(m.y) + dy, w: w, h: h }
              }
              return { x: Number(m.x), y: Number(m.y), w: w, h: h }
            }
            return null
          }

          Repeater {
            model: root.monitors
            Item {
              id: dlg
              required property var modelData
              readonly property string monName: modelData.name
              readonly property bool isDragged: root.dragName === dlg.monName
              readonly property var base: canvas.rawRectFor(dlg.monName) || { x: 0, y: 0, w: 0, h: 0 }
              readonly property var drawn: canvas.placePixel(dlg.monName, dlg.base.x, dlg.base.y, dlg.base.w, dlg.base.h)

              x: dlg.drawn.x
              y: dlg.drawn.y
              width: dlg.drawn.w
              height: dlg.drawn.h
              visible: dlg.drawn.w > 0 && dlg.drawn.h > 0
              z: dlg.isDragged ? 20 : (root.selected === dlg.monName ? 10 : 1)

              Rectangle {
                anchors.fill: parent
                radius: Math.max(2, Style.cornerRadius)
                color: root.selected === dlg.monName
                  ? Style.selectedFillFor(root.bar.foreground, ShellColor.accent)
                  : Style.normalFillFor(root.bar.foreground, ShellColor.accent)
                border.color: root.selected === dlg.monName
                  ? Style.selectedBorderFor(root.bar.foreground, ShellColor.accent)
                  : Style.normalBorderFor(root.bar.foreground, ShellColor.accent)
                border.width: 1
                opacity: dlg.isDragged ? 0.85 : 1.0

                Behavior on opacity { enabled: !Style.reduceMotion; NumberAnimation { duration: Style.duration(120) } }
              }

              Text {
                anchors.centerIn: parent
                width: parent.width - Style.space(4)
                text: dlg.monName
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.selected === dlg.monName || dlg.isDragged
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
              }

              // Mode / scale / rotation under the name, when the rectangle is
              // big enough to carry a second line.
              Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(3)
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                visible: parent.height > Style.space(46)
                text: {
                  var m = dlg.modelData
                  var bits = []
                  var mode = root.currentModeString(m)
                  if (mode) bits.push(mode.split("@")[0])
                  if (Number(m.scale) !== 1) bits.push(Number(m.scale) + "x")
                  var t = Number(m.transform) || 0
                  if (t !== 0) bits.push((t * 90) + "°")
                  return bits.join(" · ")
                }
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                opacity: 0.75
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: dlg.isDragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onPressed: function(mouse) {
                  root.selected = dlg.monName
                  if (mouse.button === Qt.RightButton) {
                    // Right-click rotates in place without starting a drag.
                    root.rotateSelected(1)
                    return
                  }
                  var p = mapToItem(canvas, mouse.x, mouse.y)
                  root.dragName = dlg.monName
                  root.grabDX = p.x
                  root.grabDY = p.y
                  root.dragX = p.x
                  root.dragY = p.y
                  root.dragMoved = false
                }

                onPositionChanged: function(mouse) {
                  if (root.dragName !== dlg.monName) return
                  var p = mapToItem(canvas, mouse.x, mouse.y)
                  root.dragX = p.x
                  root.dragY = p.y
                  if (Math.abs(root.dragX - root.grabDX) > 3 || Math.abs(root.dragY - root.grabDY) > 3)
                    root.dragMoved = true
                }

                onReleased: function(mouse) {
                  if (root.dragName !== dlg.monName) return
                  var p = mapToItem(canvas, mouse.x, mouse.y)
                  root.dragX = p.x
                  root.dragY = p.y
                  var moved = root.dragMoved
                  // Capture before clearing: once dragName is empty the
                  // dragged rectangle snaps back to its stored position.
                  var dragged = canvas.rawRectFor(dlg.monName)
                  var target = root.dropTarget()
                  root.dragName = ""
                  if (!moved) return   // a click only selects
                  root.commitDrop(dlg.monName, dragged, target)
                }
              }
            }
          }

          // Where the dragged display will land once the pointer is released.
          // Sits above every monitor rectangle so the docked edge stays
          // readable while the dragged rectangle is at 85% opacity over it.
          Rectangle {
            id: ghost
            z: 30
            readonly property var preview: root.dragPreview()
            visible: root.dragName !== "" && preview !== null
            x: preview ? preview.x : 0
            y: preview ? preview.y : 0
            width: preview ? preview.w : 0
            height: preview ? preview.h : 0
            radius: Math.max(2, Style.cornerRadius)
            color: "transparent"
            border.color: Style.selectedBorderFor(root.bar.foreground, ShellColor.accent)
            border.width: 1
            opacity: root.dragName !== "" && preview !== null ? 0.9 : 0.0

            Behavior on opacity { enabled: !Style.reduceMotion; NumberAnimation { duration: Style.duration(100) } }
          }
        }

        // ---------- Monitor selector ----------
        PanelSeparator { foreground: root.bar.foreground }
        PanelSectionHeader { text: "MONITOR"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }

        Flow {
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
          Flow {
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

          PanelSectionHeader { text: "ORIENTATION"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          Flow {
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
                onClicked: root.setTransform(Number(modelData))
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
