import QtQuick
import QtQuick.Controls
import qs.Commons
import "../model"
import "../components"

Item {
  id: root

  Component.onCompleted: Omarchy.refreshUpdates()

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
      spacing: 18
      bottomPadding: 24

      Rectangle {
        width: parent.width
        height: statusCol.implicitHeight + 32
        radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
        color: Util.alpha(Color.foreground, 0.04)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.07)

        Column {
          id: statusCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          spacing: 16

          Text {
            text: "Status"
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
            color: Color.foreground
          }

          Grid {
            width: parent.width
            columns: 2
            columnSpacing: 28
            rowSpacing: 10

            Text { text: "Version"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
            Text { text: Omarchy.version.length > 0 ? Omarchy.version : "—"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

            Text { text: "Channel"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
            Text { text: Omarchy.channel.length > 0 ? Omarchy.channel : "—"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

            Text { text: "Branch"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
            Text { text: Omarchy.branch.length > 0 ? Omarchy.branch : "—"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

            Text { text: "Packages"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
            Text { text: Omarchy.lastUpdate.length > 0 ? Omarchy.lastUpdate : "—"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Omarchy.checkingUpdates ? "Checking for updates…"
              : (Omarchy.updatesAvailable ? Omarchy.updateSummary : "Omarchy is up to date")
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Omarchy.updatesAvailable ? Color.accent : Color.muted
          }
        }
      }

      Rectangle {
        width: parent.width
        height: channelRow.implicitHeight + 32
        radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
        color: Util.alpha(Color.foreground, 0.04)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.07)

        Row {
          id: channelRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          spacing: 16

          Column {
            width: parent.width - channelSeg.width - 40
            spacing: 2
            Text {
              text: "Release channel"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              color: Color.foreground
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Switching opens a terminal to confirm and repoint the packages."
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Color.muted
            }
          }

          SegmentedControl {
            id: channelSeg
            anchors.verticalCenter: parent.verticalCenter
            options: [
              { value: "stable", label: "Stable" },
              { value: "rc", label: "RC" },
              { value: "edge", label: "Edge" },
              { value: "dev", label: "Dev" }
            ]
            value: Omarchy.channel
            onChanged: function (v) { Omarchy.setChannel(v) }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: actionCol.implicitHeight + 32
        radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
        color: Util.alpha(Color.foreground, 0.04)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.07)

        Column {
          id: actionCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          spacing: 14

          Text {
            text: "Actions"
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
            color: Color.foreground
          }

          Row {
            spacing: 10
            PillButton {
              text: "Update Omarchy"
              primary: true
              onClicked: Omarchy.updateOmarchy()
            }
            PillButton {
              text: "Check for updates"
              onClicked: Omarchy.refreshUpdates()
            }
            PillButton {
              text: "Update plugins"
              onClicked: Omarchy.updatePlugins()
            }
          }

          Row {
            spacing: 10
            PillButton {
              visible: Omarchy.themeExtras.length > 0
              text: "Update extra themes"
              onClicked: Omarchy.updateThemes()
            }
            PillButton {
              text: "Update firmware"
              onClicked: Omarchy.updateFirmware()
            }
            PillButton {
              text: "Restart shell"
              onClicked: Omarchy.restartShell()
            }
          }
        }
      }
    }
  }
}
