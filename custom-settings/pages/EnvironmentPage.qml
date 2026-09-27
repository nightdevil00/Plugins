import QtQuick
import QtQuick.Controls
import qs.Commons
import "../model"
import "../components"

Item {
  id: root

  property bool advancedMode: false
  readonly property color warnColor: Color.urgent

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
      spacing: 24
      bottomPadding: 24

      Rectangle {
        width: parent.width
        implicitHeight: warningCol.implicitHeight + 28
        height: implicitHeight
        radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
        color: advancedMode ? Util.alpha(root.warnColor, 0.1) : Util.alpha(Color.foreground, 0.04)
        border.width: 1
        border.color: advancedMode ? Util.alpha(root.warnColor, 0.3) : Util.alpha(Color.foreground, 0.07)

        Column {
          id: warningCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 14
          spacing: 12

          Row {
            width: parent.width
            spacing: 12

            Text {
              text: advancedMode ? "󰀪" : "󰋽"
              font.family: Style.font.family
              font.pixelSize: Style.font.iconLarge
              color: advancedMode ? root.warnColor : Color.muted
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              width: parent.width - 36
              wrapMode: Text.WordWrap
              text: advancedMode
                ? "Advanced mode enabled. Changing these environment variables can affect system stability, graphics drivers, and application behavior. Only modify if you know what you're doing."
                : "Environment variables control low-level behavior for Hyprland, Aquamarine, NVIDIA drivers, and toolkits (GTK, Qt, SDL, etc.). Enable Advanced mode to edit them."
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              color: advancedMode ? root.warnColor : Color.muted
            }
          }

          Rectangle {
            id: advancedToggle
            width: parent.width
            height: 48
            radius: Style.cornerRadius > 0 ? Math.min(12, Math.round(Style.cornerRadius * 0.5)) : 4
            color: advancedMode ? Util.alpha(root.warnColor, 0.15) : (toggleMouse.containsMouse ? Util.alpha(Color.foreground, 0.06) : "transparent")
            border.width: 1
            border.color: advancedMode ? Util.alpha(root.warnColor, 0.4) : Util.alpha(Color.foreground, 0.1)

            Item {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 12

              Text {
                anchors.left: parent.left
                anchors.right: toggleSwitch.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: advancedMode ? "⚠  Advanced Mode Active — Tap to Disable" : "🔧  Enable Advanced Mode to Edit Environment Variables"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.weight: Font.DemiBold
                color: advancedMode ? root.warnColor : Color.foreground
              }

              Rectangle {
                id: toggleSwitch
                width: 50
                height: 26
                radius: 13
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: advancedMode ? root.warnColor : Util.alpha(Color.foreground, 0.15)

                Rectangle {
                  id: toggleThumb
                  width: 20
                  height: 20
                  radius: 10
                  color: "white"
                  x: advancedMode ? parent.width - 23 : 3
                  anchors.verticalCenter: parent.verticalCenter
                  Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
              }
            }

            MouseArea {
              id: toggleMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.advancedMode = !root.advancedMode
            }
          }
        }
      }

      GenericPage {
        id: innerGenericPage
        width: parent.width
        height: advancedMode ? contentHeight : 0
        visible: advancedMode
        pageId: "environment"
        embedded: true
      }
    }
  }
}