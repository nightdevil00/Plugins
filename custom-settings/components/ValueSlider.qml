import QtQuick
import qs.Commons

Item {
  id: root
  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 1
  property bool integer: false
  signal moved(real value)

  activeFocusOnTab: true
  implicitWidth: 180
  implicitHeight: 24

  readonly property bool hot: mouse.containsMouse || mouse.pressed
  readonly property real range: Math.max(0.0001, maximum - minimum)
  readonly property real progress: Math.max(0, Math.min(1, (value - minimum) / range))

  function clamp(v) {
    return Math.max(minimum, Math.min(maximum, v))
  }
  function quantize(v) {
    var n = clamp(v)
    if (integer) return Math.round(n)
    return Math.round(n / step) * step
  }
  function commit(v) {
    root.moved(quantize(v))
  }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    height: 4
    radius: 2
    color: Util.alpha(Color.foreground, 0.12)

    Rectangle {
      height: parent.height
      radius: parent.radius
      color: Color.accent
      width: parent.width * root.progress
    }
  }

  Rectangle {
    id: knob
    width: root.hot || root.activeFocus ? 16 : 13
    height: width
    radius: width / 2
    color: Color.foreground
    border.width: root.activeFocus ? 2 : 0
    border.color: Color.accent
    anchors.verticalCenter: parent.verticalCenter
    x: Math.max(0, Math.min(parent.width - width, parent.width * root.progress - width / 2))
    Behavior on width { NumberAnimation { duration: 100 } }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    function valueAt(px) {
      var t = Math.max(0, Math.min(1, px / width))
      return root.minimum + t * root.range
    }
    onPressed: function (m) { root.forceActiveFocus(); root.commit(valueAt(m.x)) }
    onPositionChanged: function (m) { if (pressed) root.commit(valueAt(m.x)) }
    onClicked: function (m) { root.commit(valueAt(m.x)) }
  }

  Keys.onLeftPressed: commit(value - step)
  Keys.onDownPressed: commit(value - step)
  Keys.onRightPressed: commit(value + step)
  Keys.onUpPressed: commit(value + step)
  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_PageUp) { commit(value + step * 5); event.accepted = true }
    else if (event.key === Qt.Key_PageDown) { commit(value - step * 5); event.accepted = true }
    else if (event.key === Qt.Key_Home) { commit(minimum); event.accepted = true }
    else if (event.key === Qt.Key_End) { commit(maximum); event.accepted = true }
  }
}
