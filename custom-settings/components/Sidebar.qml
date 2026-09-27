import QtQuick
import qs.Commons
import "../model"
import "../model/Schema.js" as Schema
import "."

Item {
  id: root
  property string currentPage: ""
  property string filter: ""
  signal selected(string id)

  readonly property var visiblePages: {
    var out = []
    var all = SettingsStore.pages
    for (var i = 0; i < all.length; i++) {
      if (filter.length === 0 || Schema.pageHasMatch(all[i].id, filter)) out.push(all[i])
    }
    return out
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.foreground, 0.03)
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.06)
  }

  Column {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 4

    Item {
      width: parent.width
      height: 58
      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "\ue900"
          font.family: "omarchy"
          font.pixelSize: Style.font.displayLarge
          color: Color.accent
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1
          Text {
            text: "Omarchy"
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.weight: Font.Bold
            color: Color.foreground
          }
          Text {
            text: "Settings"
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Color.accent
          }
        }
      }
    }

    Repeater {
      model: root.visiblePages
      delegate: NavItem {
        required property var modelData
        width: parent.width
        icon: modelData.icon
        label: modelData.label
        selected: root.currentPage === modelData.id
        onActivated: root.selected(modelData.id)
      }
    }
  }
}
