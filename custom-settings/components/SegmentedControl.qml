import QtQuick
import qs.Commons

// Immediate segmented choice. Left/Right changes the selection straight away —
// no separate "move cursor then confirm" step.
Item {
  id: root
  property var options: []
  property var value
  signal changed(var value)

  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body

  activeFocusOnTab: true
  implicitWidth: row.implicitWidth
  implicitHeight: 32

  function indexOf(v) {
    for (var i = 0; i < options.length; i++)
      if (String(options[i].value) === String(v)) return i
    return -1
  }
  function choose(i) {
    if (i < 0 || i >= options.length) return
    root.changed(options[i].value)
  }
  function step(d) {
    var i = indexOf(value)
    if (i < 0) i = 0
    choose(Math.max(0, Math.min(options.length - 1, i + d)))
  }

  Row {
    id: row
    anchors.fill: parent
    spacing: 2

    Repeater {
      model: root.options
      delegate: Rectangle {
        required property var modelData
        height: parent.height
        width: label.implicitWidth + 22
        radius: Style.cornerRadius > 0 ? Math.min(10, Math.round(Style.cornerRadius * 0.45)) : 3

        readonly property bool isSelected: String(modelData.value) === String(root.value)
        color: isSelected
          ? Util.alpha(Color.accent, 0.9)
          : (cellMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.06))
        Behavior on color { ColorAnimation { duration: 110 } }

        Text {
          id: label
          anchors.centerIn: parent
          text: modelData.label !== undefined ? modelData.label : String(modelData.value)
          font.family: root.fontFamily
          font.pixelSize: root.fontSize
          font.weight: parent.isSelected ? Font.DemiBold : Font.Normal
          color: parent.isSelected ? Color.background : Color.foreground
        }

        MouseArea {
          id: cellMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.forceActiveFocus()
            root.changed(modelData.value)
          }
        }
      }
    }
  }

  // Focus ring drawn last so it sits above the segments.
  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: Style.cornerRadius > 0 ? Math.min(12, Math.round(Style.cornerRadius * 0.5)) : 5
    color: "transparent"
    border.width: root.activeFocus ? 1 : 0
    border.color: Util.alpha(Color.accent, 0.9)
    visible: root.activeFocus
  }

  Keys.onLeftPressed: step(-1)
  Keys.onRightPressed: step(1)
  Keys.onSpacePressed: step(1)
  Keys.onReturnPressed: step(1)
}
