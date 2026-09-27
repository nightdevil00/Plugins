import QtQuick
import qs.Commons

Rectangle {
  id: root
  property string text: ""
  property bool primary: false
  signal clicked()

  implicitWidth: label.implicitWidth + 30
  implicitHeight: 32
  radius: Style.cornerRadius > 0 ? Math.min(12, Math.round(Style.cornerRadius * 0.5)) : 4

  readonly property bool hot: mouse.containsMouse
  color: primary
    ? (hot ? Qt.lighter(Color.accent, 1.1) : Color.accent)
    : (hot ? Util.alpha(Color.foreground, 0.14) : Util.alpha(Color.foreground, 0.07))
  border.width: activeFocus ? 1 : 0
  border.color: primary ? Qt.lighter(Color.accent, 1.3) : Color.accent
  Behavior on color { ColorAnimation { duration: 110 } }

  activeFocusOnTab: true

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.weight: root.primary ? Font.DemiBold : Font.Normal
    color: root.primary ? Color.background : Color.foreground
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.forceActiveFocus()
      root.clicked()
    }
  }

  Keys.onReturnPressed: root.clicked()
  Keys.onEnterPressed: root.clicked()
  Keys.onSpacePressed: root.clicked()
}
