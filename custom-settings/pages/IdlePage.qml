import QtQuick
import qs.Commons
import "../model"
import "../components"

Item {
  id: root

  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 26

    Text {
      text: "TIMING"
      leftPadding: 2
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1.2
      color: Color.muted
    }

    Rectangle {
      width: parent.width
      height: timingCol.implicitHeight + 32
      radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
      color: Util.alpha(Color.foreground, 0.04)
      border.width: 1
      border.color: Util.alpha(Color.foreground, 0.07)

      Column {
        id: timingCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 18

        Row {
          width: parent.width
          spacing: 16
          Column {
            width: parent.width - screensaverSlider.width - 80
            spacing: 2
            Text {
              text: "Screensaver"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              color: Color.foreground
            }
            Text {
              text: "Minutes of inactivity before the screen dims."
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Color.muted
            }
          }
          Text {
            text: Omarchy.idleScreensaver + " min"
            width: 60
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Color.muted
          }
          ValueSlider {
            id: screensaverSlider
            width: 170
            minimum: 1
            maximum: 120
            step: 1
            integer: true
            value: Omarchy.idleScreensaver
            anchors.verticalCenter: parent.verticalCenter
            onMoved: function (v) { Omarchy.setIdle("screensaver", Math.round(v)) }
          }
        }

        Row {
          width: parent.width
          spacing: 16
          Column {
            width: parent.width - lockSlider.width - 80
            spacing: 2
            Text {
              text: "Lock"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              color: Color.foreground
            }
            Text {
              text: "Minutes of inactivity before the session locks."
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Color.muted
            }
          }
          Text {
            text: Omarchy.idleLock + " min"
            width: 60
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Color.muted
          }
          ValueSlider {
            id: lockSlider
            width: 170
            minimum: 1
            maximum: 240
            step: 1
            integer: true
            value: Omarchy.idleLock
            anchors.verticalCenter: parent.verticalCenter
            onMoved: function (v) { Omarchy.setIdle("lock", Math.round(v)) }
          }
        }
      }
    }

    Text {
      text: "FOR NOW"
      leftPadding: 2
      topPadding: 4
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1.2
      color: Color.muted
    }

    Row {
      spacing: 10
      PillButton {
        text: "Stay awake"
        onClicked: Omarchy.run(["omarchy", "toggle", "idle", "stay-awake"])
      }
      PillButton {
        text: "Allow idle"
        onClicked: Omarchy.run(["omarchy", "toggle", "idle", "allow-idle"])
      }
    }

    Text {
      width: parent.width
      text: "Screensaver and lock are stored in ~/.config/omarchy/shell.json and apply as soon as they change."
      wrapMode: Text.WordWrap
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      color: Util.alpha(Color.muted, 0.8)
    }
  }
}
