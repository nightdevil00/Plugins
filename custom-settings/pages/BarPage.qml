import QtQuick
import QtQuick.Controls
import qs.Commons
import "../model"
import "../components"

Item {
  id: root

  function kindLabel(kind) {
    var map = {
      "bar-widget": "Bar widgets",
      "panel": "Panels",
      "service": "Services",
      "overlay": "Overlays",
      "menu": "Menus",
      "bar": "Bar"
    }
    return map[kind] || (kind.charAt(0).toUpperCase() + kind.slice(1))
  }

  readonly property var pluginGroups: {
    var byKind = {}
    var order = []
    var list = Omarchy.plugins
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p.canDisable) continue
      var kind = (p.kinds && p.kinds.length > 0) ? p.kinds[0] : "other"
      if (!byKind[kind]) { byKind[kind] = []; order.push(kind) }
      byKind[kind].push(p)
    }
    var out = []
    for (var j = 0; j < order.length; j++) {
      var items = byKind[order[j]]
      items.sort(function (a, b) { return a.name.localeCompare(b.name) })
      out.push({ kind: order[j], label: kindLabel(order[j]), items: items })
    }
    return out
  }

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: col
      width: parent.width
      spacing: 26
      bottomPadding: 24

      // ---------------------------------------------------------- bar
      Column {
        width: col.width
        spacing: 14

        Text {
          text: "BAR"
          leftPadding: 2
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1.2
          color: Color.muted
        }

        Rectangle {
          width: col.width
          height: barCol.implicitHeight + 28
          radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
          color: Util.alpha(Color.foreground, 0.04)
          border.width: 1
          border.color: Util.alpha(Color.foreground, 0.07)

          Column {
            id: barCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14

            Row {
              width: parent.width
              spacing: 14
              Text {
                text: "Position"
                width: 120
                anchors.verticalCenter: parent.verticalCenter
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Color.foreground
              }
              SegmentedControl {
                options: [
                  { value: "top", label: "Top" },
                  { value: "bottom", label: "Bottom" },
                  { value: "left", label: "Left" },
                  { value: "right", label: "Right" }
                ]
                value: Omarchy.barPosition
                onChanged: function (v) { Omarchy.setBarPosition(v) }
              }
            }

            Row {
              width: parent.width
              spacing: 14
              Text {
                text: "Transparent"
                width: 120
                anchors.verticalCenter: parent.verticalCenter
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Color.foreground
              }
              SwitchControl {
                checked: Omarchy.barTransparent
                onToggled: Omarchy.setBarTransparent(!Omarchy.barTransparent)
              }
            }
          }
        }
      }

      // ------------------------------------------------------- plugins
      Repeater {
        model: root.pluginGroups
        delegate: Column {
          id: groupCol
          required property var modelData
          width: col.width
          spacing: 2

          Text {
            text: groupCol.modelData.label.toUpperCase()
            leftPadding: 2
            bottomPadding: 6
            topPadding: 4
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
            color: Color.muted
          }

          Repeater {
            model: groupCol.modelData.items
            delegate: Rectangle {
              id: pluginRow
              required property var modelData
              width: groupCol.width
              height: 52
              radius: 0
              color: pluginMouse.containsMouse ? Util.alpha(Color.foreground, 0.04) : "transparent"

              Row {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                spacing: 12

                Column {
                  width: parent.width - pluginSwitch.width - 40
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 1
                  Text {
                    text: pluginRow.modelData.name
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    color: Color.foreground
                  }
                  Text {
                    text: pluginRow.modelData.id
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.muted
                  }
                }

                SwitchControl {
                  id: pluginSwitch
                  checked: pluginRow.modelData.enabled
                  anchors.verticalCenter: parent.verticalCenter
                  onToggled: Omarchy.setPluginEnabled(pluginRow.modelData.id, !checked)
                }
              }

              MouseArea {
                id: pluginMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }
            }
          }
        }
      }
    }
  }
}
