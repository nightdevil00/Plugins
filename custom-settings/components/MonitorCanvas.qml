import QtQuick
import qs.Commons
import "../model"

// A to-scale arrangement surface: each active monitor is a rectangle placed
// at its logical (post-scale) X/Y. Dragging a rectangle writes a snapped
// position back through `commitFn`, which fills the rest of the monitor base
// so a position edit never resets mode/scale.
Item {
  id: canvas

  property var monitors: []
  property var commitFn: null
  property int pad: 18
  property real maxFit: 0.35

  implicitHeight: 280

  property string dragging: ""
  property real previewX: 0
  property real previewY: 0

  readonly property var managedMonitors: SettingsStore.managedMonitors

  // ------------------------------------------------------------- layout model

  function buildEntries() {
    var list = canvas.monitors || []
    var out = []
    for (var i = 0; i < list.length; i++) {
      var m = list[i]
      var sc = Number(SettingsStore.monitorValue(m, "scale", 1))
      if (!isFinite(sc) || sc <= 0) sc = 1
      out.push({
        monitor: m,
        name: String(m.name),
        enabled: SettingsStore.monitorValue(m, "disabled", false) !== true,
        x: Number(SettingsStore.monitorValue(m, "x", 0)),
        y: Number(SettingsStore.monitorValue(m, "y", 0)),
        w: Number(m.width) / sc,
        h: Number(m.height) / sc,
        res: m.width + "×" + m.height
      })
    }
    return out
  }

  readonly property var entries: {
    var dep = canvas.managedMonitors
    var dep2 = canvas.monitors
    return buildEntries()
  }

  function entryFor(name) {
    var list = canvas.entries
    for (var i = 0; i < list.length; i++)
      if (list[i].name === name) return list[i]
    return null
  }

  readonly property var frame: {
    var dep = canvas.managedMonitors
    var dep2 = canvas.monitors
    return computeFrame()
  }

  // Scale is derived from the summed sizes of active monitors so the surface
  // never rescales while dragging -- only the rectangles move. Coordinates are
  // offset so monitors with negative or far-from-origin positions stay in view.
  function computeFrame() {
    var list = canvas.entries
    var sumW = 0, sumH = 0
    var minX = Infinity, minY = Infinity
    for (var i = 0; i < list.length; i++) {
      if (!list[i].enabled) continue
      sumW += list[i].w
      sumH += list[i].h
      minX = Math.min(minX, list[i].x)
      minY = Math.min(minY, list[i].y)
    }
    if (minX === Infinity) minX = 0
    if (minY === Infinity) minY = 0
    var availW = Math.max(1, canvas.width - canvas.pad * 2)
    var availH = Math.max(1, canvas.implicitHeight - canvas.pad * 2)
    if (sumW <= 0 || sumH <= 0)
      return { fit: 1, ox: canvas.pad, oy: canvas.pad, bx: 0, by: 0, availW: availW, availH: availH }
    var fit = Math.min(availW / (sumW * 1.15), availH / (sumH * 1.15), canvas.maxFit)
    var ox = canvas.pad + (availW - sumW * fit) / 2
    var oy = canvas.pad + (availH - sumH * fit) / 2
    return { fit: fit, ox: ox, oy: oy, bx: minX, by: minY, availW: availW, availH: availH }
  }

  function edgesX(self) {
    var out = [0]
    for (var i = 0; i < canvas.entries.length; i++) {
      var o = canvas.entries[i]
      if (!o.enabled || o.name === self.name) continue
      out.push(o.x)
      out.push(o.x + o.w)
    }
    return out
  }

  function edgesY(self) {
    var out = [0]
    for (var i = 0; i < canvas.entries.length; i++) {
      var o = canvas.entries[i]
      if (!o.enabled || o.name === self.name) continue
      out.push(o.y)
      out.push(o.y + o.h)
    }
    return out
  }

  // Snap either edge of the dragged rectangle to the targets, else fall back
  // to a coarse grid so values stay tidy.
  function snap(value, edges, size, fit) {
    var thr = 12 / fit
    var best = value, bestD = 1e9
    for (var i = 0; i < edges.length; i++) {
      var dLeft = Math.abs(value - edges[i])
      if (dLeft < bestD) { bestD = dLeft; best = edges[i] }
      var dRight = Math.abs(value + size - edges[i])
      if (dRight < bestD) { bestD = dRight; best = edges[i] - size }
    }
    if (bestD > thr) return Math.round(value / 10) * 10
    return Math.round(best)
  }

  // ---------------------------------------------------------------- surface

  Rectangle {
    id: surface
    anchors.fill: parent
    radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
    color: Util.alpha(Color.foreground, 0.03)
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.07)
    clip: true

    Text {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: 12
      text: "Drag to arrange"
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Util.alpha(Color.foreground, 0.3)
    }

    Text {
      anchors.centerIn: parent
      visible: canvas.dragging === ""
      text: canvas.monitors.length === 0 ? "No monitors reported by Hyprland."
        : (canvas.entries.filter(function (e) { return e.enabled }).length === 0 ? "All monitors are disabled." : "")
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      color: Color.muted
    }

    Repeater {
      model: canvas.monitors
      delegate: Rectangle {
        id: box
        required property var modelData
        required property int index

        readonly property string output: String(modelData.name)
        readonly property var entry: canvas.entryFor(output)
        readonly property bool active: entry !== null && entry.enabled
        readonly property bool held: canvas.dragging === output
        readonly property real wx: held ? canvas.previewX : (entry ? entry.x : 0)
        readonly property real wy: held ? canvas.previewY : (entry ? entry.y : 0)

        visible: active
        x: canvas.frame.ox + (wx - canvas.frame.bx) * canvas.frame.fit
        y: canvas.frame.oy + (wy - canvas.frame.by) * canvas.frame.fit
        width: Math.max(24, (entry ? entry.w : 0) * canvas.frame.fit)
        height: Math.max(18, (entry ? entry.h : 0) * canvas.frame.fit)
        radius: 8
        color: held ? Util.alpha(Color.accent, 0.20) : Util.alpha(Color.foreground, 0.06)
        border.width: 1
        border.color: held ? Color.accent : Util.alpha(Color.foreground, 0.28)
        Behavior on color { ColorAnimation { duration: 110 } }

        Column {
          anchors.centerIn: parent
          spacing: 1
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: box.output
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.weight: Font.DemiBold
            color: Color.foreground
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: box.height > 58
            text: box.held ? (Math.round(canvas.previewX) + ", " + Math.round(canvas.previewY))
              : (box.entry ? (box.entry.x + ", " + box.entry.y) : "")
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.muted
          }
        }

        DragHandler {
          id: drag
          target: null
          property point startScene
          property real baseX: 0
          property real baseY: 0

          onActiveChanged: {
            if (active) {
              if (!box.entry) return
              canvas.dragging = box.output
              canvas.previewX = box.entry.x
              canvas.previewY = box.entry.y
              baseX = box.entry.x
              baseY = box.entry.y
              startScene = centroid.scenePosition
            } else if (canvas.dragging === box.output) {
              var fn = canvas.commitFn
              var mon = box.modelData
              var mx = Math.round(canvas.previewX)
              var my = Math.round(canvas.previewY)
              var moved = mx !== Math.round(baseX) || my !== Math.round(baseY)
              canvas.dragging = ""
              if (fn && moved) fn(mon, { x: mx, y: my })
            }
          }

          onCentroidChanged: {
            if (!active || !box.entry) return
            var fit = canvas.frame.fit
            var dx = (centroid.scenePosition.x - startScene.x) / fit
            var dy = (centroid.scenePosition.y - startScene.y) / fit
            canvas.previewX = canvas.snap(baseX + dx, canvas.edgesX(box.entry), box.entry.w, fit)
            canvas.previewY = canvas.snap(baseY + dy, canvas.edgesY(box.entry), box.entry.h, fit)
          }
        }

        HoverHandler {
          cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
      }
    }
  }
}
