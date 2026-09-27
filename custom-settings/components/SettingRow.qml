import QtQuick
import QtQuick.Controls
import qs.Commons
import "../model"
import "."

// A single schema-driven setting. The control is chosen from the setting's
// type; the row owns reset and the label/description column.
Item {
  id: root
  property var setting

  signal changed(var value)

  readonly property string sid: setting ? setting.id : ""
  readonly property var val: setting ? SettingsStore.value(setting.id) : undefined
  readonly property bool managed: setting ? SettingsStore.isManaged(setting.id) : false
  readonly property bool numeric: setting !== undefined && setting !== null && (setting.type === "int" || setting.type === "float")

  implicitHeight: Math.max(58, labelCol.implicitHeight + 20)

  function displayValue() {
    if (!setting) return ""
    if (setting.percent) return Math.round(Number(val) * 100) + "%"
    var dec = 0
    if (setting.type === "float") dec = setting.step >= 0.1 ? 1 : 2
    var s = dec > 0 ? Number(val).toFixed(dec) : String(val)
    return setting.unit ? s + " " + setting.unit : s
  }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -12
    anchors.rightMargin: -12
    radius: Style.cornerRadius > 0 ? Math.round(Style.cornerRadius * 0.4) : 4
    color: rowMouse.containsMouse ? Util.alpha(Color.foreground, 0.04) : "transparent"
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    anchors.leftMargin: -12
    anchors.rightMargin: -12
    hoverEnabled: true
    acceptedButtons: setting && setting.type === "bool" ? Qt.LeftButton : Qt.NoButton
    cursorShape: setting && setting.type === "bool" ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.changed(!val)
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 2
    anchors.rightMargin: 2
    spacing: 16

    Column {
      id: labelCol
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(160, parent.width - controlArea.width - resetBtn.width - 48)
      spacing: 3

      Row {
        spacing: 8
        Text {
          text: root.setting ? root.setting.label : ""
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.weight: Font.Medium
          color: Color.foreground
          anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
          visible: root.managed
          width: managedText.implicitWidth + 12
          height: 18
          radius: height / 2
          color: Util.alpha(Color.accent, 0.16)
          anchors.verticalCenter: parent.verticalCenter
          Text {
            id: managedText
            anchors.centerIn: parent
            text: "managed"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.accent
          }
        }
      }

      Text {
        text: root.setting ? root.setting.desc : ""
        visible: text.length > 0
        width: parent.width
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Color.muted
      }
    }

    Item { width: 1; height: 1 }

    Row {
      id: controlArea
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      // bool
      SwitchControl {
        visible: root.setting && root.setting.type === "bool"
        checked: root.val === true
        onToggled: root.changed(!checked)
      }

      // enum
      SegmentedControl {
        visible: root.setting && root.setting.type === "enum"
        options: root.setting ? root.setting.options : []
        value: root.val
        onChanged: function (v) { root.changed(v) }
      }

      // numeric
      Text {
        visible: root.setting && (root.setting.type === "int" || root.setting.type === "float")
        text: root.displayValue()
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: Color.muted
        width: 56
        horizontalAlignment: Text.AlignRight
        anchors.verticalCenter: parent.verticalCenter
      }
      ValueSlider {
        visible: root.numeric
        width: 170
        minimum: root.numeric ? root.setting.min : 0
        maximum: root.numeric ? root.setting.max : 1
        step: root.numeric ? root.setting.step : 1
        integer: root.numeric ? root.setting.type === "int" : true
        value: Number(root.val)
        onMoved: function (v) { root.changed(v) }
        anchors.verticalCenter: parent.verticalCenter
      }

      // string
      TextField {
        id: field
        visible: root.setting && root.setting.type === "string"
        width: 200
        text: root.val !== undefined ? String(root.val) : ""
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: Color.foreground
        selectByMouse: true
        leftPadding: 10
        rightPadding: 10
        topPadding: 6
        bottomPadding: 6
        placeholderTextColor: Util.alpha(Color.foreground, 0.35)
        onEditingFinished: {
          if (text !== root.val) root.changed(text)
        }
        background: Rectangle {
          radius: Style.cornerRadius > 0 ? Math.min(10, Math.round(Style.cornerRadius * 0.45)) : 3
          color: Util.alpha(Color.foreground, 0.06)
          border.width: field.activeFocus ? 1 : 0
          border.color: Color.accent
        }
      }
    }

    Item {
      id: resetBtn
      width: 22
      height: 22
      visible: root.managed
      anchors.verticalCenter: parent.verticalCenter
      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: resetMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : "transparent"
        Text {
          anchors.centerIn: parent
          text: "󰑙"
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: resetMouse.containsMouse ? Color.foreground : Color.muted
        }
      }
      MouseArea {
        id: resetMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: SettingsStore.reset(root.sid)
      }
    }
  }
}
