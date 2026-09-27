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

    Rectangle {
      width: parent.width
      height: nightCol.implicitHeight + 32
      radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
      color: Util.alpha(Color.foreground, 0.04)
      border.width: 1
      border.color: Util.alpha(Color.foreground, 0.07)

      Column {
        id: nightCol
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
            width: parent.width - nightSwitch.width - 40
            spacing: 2
            Text {
              text: "Warm screen after dark"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              color: Color.foreground
            }
            Text {
              text: "Shifts the display toward warmer tones using hyprsunset."
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Color.muted
            }
          }
          SwitchControl {
            id: nightSwitch
            checked: Omarchy.nightlightEnabled
            anchors.verticalCenter: parent.verticalCenter
            onToggled: Omarchy.setNightlight(!Omarchy.nightlightEnabled)
          }
        }

        Row {
          width: parent.width
          spacing: 16
          opacity: Omarchy.nightlightEnabled ? 1 : 0.4

          Column {
            width: parent.width - tempSlider.width - 90
            spacing: 2
            Text {
              text: "Temperature"
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              color: Color.foreground
            }
            Text {
              text: "Lower is warmer. 4000 K is a comfortable evening setting."
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Color.muted
            }
          }
          Text {
            text: Omarchy.nightlightTemp + " K"
            width: 66
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Color.muted
          }
          ValueSlider {
            id: tempSlider
            width: 170
            minimum: 2500
            maximum: 6000
            step: 100
            integer: true
            enabled: Omarchy.nightlightEnabled
            value: Omarchy.nightlightTemp
            anchors.verticalCenter: parent.verticalCenter
            onMoved: function (v) { Omarchy.setNightlightTemp(Math.round(v)) }
          }
        }
      }
    }

    Row {
      spacing: 10
      PillButton {
        text: "Disable"
        onClicked: Omarchy.setNightlight(false)
      }
      PillButton {
        text: "Evening (4000 K)"
        primary: true
        onClicked: Omarchy.setNightlightTemp(4000)
      }
    }
  }
}
