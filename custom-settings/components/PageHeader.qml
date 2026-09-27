import QtQuick
import qs.Commons
import "../model"

Item {
  id: root
  property string title: ""
  property string description: ""

  implicitHeight: 74

  Column {
    anchors.left: parent.left
    anchors.right: actions.left
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Text {
      text: root.title
      width: parent.width
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: Style.font.display
      font.weight: Font.Bold
      color: Color.foreground
    }
    Text {
      text: root.description
      width: parent.width
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      color: Color.muted
    }
  }

  Row {
    id: actions
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10

    Text {
      visible: SettingsStore.managedCount() > 0
      text: SettingsStore.managedCount() + " managed"
      anchors.verticalCenter: parent.verticalCenter
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      color: Color.muted
    }

    Rectangle {
      visible: SettingsStore.managedCount() > 0
      width: resetText.implicitWidth + 24
      height: 30
      radius: Style.cornerRadius > 0 ? Math.min(12, Math.round(Style.cornerRadius * 0.5)) : 4
      color: resetMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.06)
      anchors.verticalCenter: parent.verticalCenter
      Text {
        id: resetText
        anchors.centerIn: parent
        text: "Reset all"
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: Color.foreground
      }
      MouseArea {
        id: resetMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: SettingsStore.resetAll()
      }
    }
  }
}
