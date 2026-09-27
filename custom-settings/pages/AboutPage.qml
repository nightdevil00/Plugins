import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import "../model"
import "../components"

Item {
  id: root

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

      Text {
        text: "Omarchy Settings"
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.weight: Font.Bold
        color: Color.foreground
      }

      Text {
        width: parent.width
        text: "A native settings surface for Hyprland and the Omarchy shell. Changes are written to ~/.config/hypr/settings.lua and applied immediately."
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: Color.muted
      }

      Rectangle {
        width: parent.width
        height: facts.implicitHeight + 32
        radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
        color: Util.alpha(Color.foreground, 0.04)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.07)

        Grid {
          id: facts
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          columns: 2
          columnSpacing: 28
          rowSpacing: 12

          Text { text: "Omarchy"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
          Text { text: Omarchy.version.length > 0 ? Omarchy.version : "—"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

          Text { text: "Theme"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
          Text { text: Omarchy.theme.length > 0 ? Omarchy.theme : "—"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

          Text { text: "Font"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
          Text { text: Omarchy.font.length > 0 ? Omarchy.font : "—"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

          Text { text: "Monitors"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
          Text { text: String(Omarchy.monitors.length); font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

          Text { text: "Managed settings"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
          Text { text: String(SettingsStore.managedCount()); font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }

          Text { text: "Config"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }
          Text { text: "~/.config/hypr/settings.lua"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }
        }
      }

      Rectangle {
        width: parent.width
        height: systemCol.implicitHeight + 32
        radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
        color: Util.alpha(Color.foreground, 0.04)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.07)

        Column {
          id: systemCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          spacing: 12

          Row {
            spacing: 8
            Text {
              text: "System information"
              anchors.verticalCenter: parent.verticalCenter
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.weight: Font.DemiBold
              color: Color.foreground
            }
            Text {
              text: "fastfetch"
              anchors.verticalCenter: parent.verticalCenter
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
            }
          }

          Text {
            text: Omarchy.fastfetchText.length > 0 ? Omarchy.fastfetchText : "Reading system information…"
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Omarchy.fastfetchText.length > 0 ? Color.foreground : Color.muted
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
          }
        }
      }

      Row {
        spacing: 10

        PillButton {
          text: "Refresh info"
          onClicked: Omarchy.refreshFastfetch()
        }
        PillButton {
          text: "Open config folder"
          onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.config/hypr"])
        }
        PillButton {
          text: "Reload Hyprland"
          onClicked: Quickshell.execDetached(["hyprctl", "reload"])
        }
        PillButton {
          text: "Reset all settings"
          primary: SettingsStore.managedCount() > 0
          onClicked: SettingsStore.resetAll()
        }
      }
    }
  }
}
