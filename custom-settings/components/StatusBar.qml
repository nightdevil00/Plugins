import QtQuick
import qs.Commons
import "../model"

Item {
  id: root
  implicitHeight: 38

  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 1
    color: Util.alpha(Color.foreground, 0.08)
  }

  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    Rectangle {
      width: 7
      height: 7
      radius: 4
      anchors.verticalCenter: parent.verticalCenter
      color: SettingsStore.errors.length > 0 ? Color.urgent
        : (SettingsStore.applying ? Color.accent : Util.alpha(Color.foreground, 0.35))
    }

    Text {
      text: SettingsStore.errors.length > 0
        ? (SettingsStore.errors.length + " config problem" + (SettingsStore.errors.length === 1 ? "" : "s") + " · " + SettingsStore.errors[0])
        : SettingsStore.status
      anchors.verticalCenter: parent.verticalCenter
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      color: SettingsStore.errors.length > 0 ? Color.urgent : Color.muted
      elide: Text.ElideRight
      width: Math.min(implicitWidth, root.width - hints.width - 60)
    }
  }

  Text {
    id: hints
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: "↑↓/Tab navigate   ←→ adjust   Enter toggle   Esc close"
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    color: Util.alpha(Color.muted, 0.7)
  }
}
