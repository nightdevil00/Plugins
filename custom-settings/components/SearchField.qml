import QtQuick
import QtQuick.Controls
import qs.Commons

TextField {
  id: root

  placeholderText: "Search settings"
  selectByMouse: true
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  color: Color.foreground
  placeholderTextColor: Util.alpha(Color.foreground, 0.35)
  leftPadding: 36
  rightPadding: 34
  topPadding: 9
  bottomPadding: 9

  background: Rectangle {
    radius: Style.cornerRadius > 0 ? Math.min(14, Math.round(Style.cornerRadius * 0.6)) : 5
    color: Util.alpha(Color.foreground, 0.05)
    border.width: root.activeFocus ? 1 : 0
    border.color: Color.accent
    Behavior on color { ColorAnimation { duration: 110 } }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: "󰍉"
      font.family: Style.font.family
      font.pixelSize: Style.font.icon
      color: Color.muted
    }

    Rectangle {
      visible: root.text.length > 0
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      height: 20
      radius: 10
      color: clearMouse.containsMouse ? Util.alpha(Color.foreground, 0.14) : "transparent"
      Text {
        anchors.centerIn: parent
        text: "󰅖"
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Color.muted
      }
      MouseArea {
        id: clearMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.text = ""
      }
    }
  }
}
