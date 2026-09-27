import QtQuick
import QtQuick.Controls
import qs.Commons
import "../model"
import "../components"

Item {
  id: root

  function stripMode(mode) {
    return String(mode || "").replace(/Hz$/, "")
  }

  function currentMode(m) {
    var override = SettingsStore.monitorOverride(m.name)
    if (override && override.mode) return override.mode
    return m.width + "x" + m.height + "@" + Math.round(m.refreshRate)
  }

  function modeOptions(m) {
    var seen = {}
    var out = []
    var list = m.availableModes || []
    for (var i = 0; i < list.length; i++) {
      var s = stripMode(list[i])
      if (!seen[s]) { seen[s] = true; out.push({ value: s, label: s }) }
    }
    var cur = currentMode(m)
    if (!seen[cur]) out.unshift({ value: cur, label: cur })
    return out
  }

  function transformOptions(m) {
    var cur = SettingsStore.monitorValue(m, "transform", 0)
    return [
      { value: 0, label: "Normal" },
      { value: 1, label: "90°" },
      { value: 2, label: "180°" },
      { value: 3, label: "270°" },
      { value: 4, label: "Flipped" },
      { value: 5, label: "90° + Flipped" },
      { value: 6, label: "180° + Flipped" },
      { value: 7, label: "270° + Flipped" }
    ]
  }

  function commit(m, changes) {
    var base = {
      enabled: SettingsStore.monitorValue(m, "disabled", false) === false,
      mode: currentMode(m),
      scale: SettingsStore.monitorValue(m, "scale", 1),
      x: SettingsStore.monitorValue(m, "x", 0),
      y: SettingsStore.monitorValue(m, "y", 0),
      transform: SettingsStore.monitorValue(m, "transform", 0)
    }
    var keys = Object.keys(changes)
    for (var i = 0; i < keys.length; i++) base[keys[i]] = changes[keys[i]]
    SettingsStore.setMonitor(m.name, base)
  }

  Flickable {
    anchors.fill: parent
    contentWidth: parent.width
    contentHeight: col.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: col
      width: parent.width
      spacing: 18
      bottomPadding: 24

      MonitorCanvas {
        width: col.width
        monitors: Omarchy.monitors
        commitFn: root.commit
      }

      Repeater {
        model: Omarchy.monitors
        delegate: Rectangle {
          id: card
          required property var modelData
          width: col.width
          height: content.height + 16
          radius: Style.cornerRadius > 0 ? Math.min(20, Style.cornerRadius) : 6
          color: Util.alpha(Color.foreground, 0.04)
          border.width: 1
          border.color: Util.alpha(Color.foreground, 0.07)

          readonly property bool enabledHere: SettingsStore.monitorValue(modelData, "disabled", false) === false

          property bool expanded: true

          Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 14

            // Header row with name and expand/collapse
            Row {
              width: parent.width
              spacing: 12

              Column {
                width: parent.width - expandBtn.width - resetRect.width - 80
                spacing: 2
                Text {
                  text: card.modelData.name
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.weight: Font.DemiBold
                  color: Color.foreground
                }
                Text {
                  text: card.modelData.description + "  ·  " + card.modelData.width + "×" + card.modelData.height
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  color: Color.muted
                }
              }

              Rectangle {
                id: expandBtn
                width: 32
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: "transparent"
                Text {
                  anchors.centerIn: parent
                  text: card.expanded ? "▲" : "▼"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  color: Color.muted
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: card.expanded = !card.expanded
                }
              }

              Rectangle {
                id: resetRect
                width: resetText.implicitWidth + 18
                height: 26
                radius: Style.cornerRadius > 0 ? Math.min(12, Math.round(Style.cornerRadius * 0.5)) : 4
                visible: SettingsStore.isMonitorManaged(card.modelData.name)
                anchors.verticalCenter: parent.verticalCenter
                color: resetMouse.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.06)
                Text {
                  id: resetText
                  anchors.centerIn: parent
                  text: "Reset"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  color: Color.foreground
                }
                MouseArea {
                  id: resetMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: SettingsStore.resetMonitor(card.modelData.name)
                }
              }
            }

            // Enable switch row
            Row {
              width: parent.width
              spacing: 12
              SwitchControl {
                id: enableSwitch
                checked: card.enabledHere
                onToggled: root.commit(card.modelData, { enabled: !card.enabledHere })
              }
              Text {
                text: "Enabled"
                anchors.verticalCenter: parent.verticalCenter
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Color.foreground
              }
            }

            // Collapsible content
            Item {
              id: collapsibleContent
              width: parent.width
              height: card.expanded ? innerCol.implicitHeight : 0
              clip: true
              visible: card.expanded && card.enabledHere

              Column {
                id: innerCol
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 14

                Row {
                  visible: card.enabledHere
                  width: parent.width
                  spacing: 14

                  Text {
                    text: "Mode"
                    width: 64
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    color: Color.muted
                  }
                  SegmentedControl {
                    options: root.modeOptions(card.modelData)
                    value: root.currentMode(card.modelData)
                    onChanged: function (v) { root.commit(card.modelData, { mode: v }) }
                  }
                }

                Row {
                  visible: card.enabledHere
                  width: parent.width
                  spacing: 14

                  Text {
                    text: "Scale"
                    width: 64
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    color: Color.muted
                  }
                  SegmentedControl {
                    options: [
                      { value: 0.75, label: "0.75×" },
                      { value: 1, label: "1×" },
                      { value: 1.25, label: "1.25×" },
                      { value: 1.5, label: "1.5×" },
                      { value: 2, label: "2×" }
                    ]
                    value: SettingsStore.monitorValue(card.modelData, "scale", 1)
                    onChanged: function (v) { root.commit(card.modelData, { scale: Number(v) }) }
                  }
                }

                Row {
                  visible: card.enabledHere
                  width: parent.width
                  spacing: 14

                  Text {
                    text: "Rotation"
                    width: 64
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    color: Color.muted
                  }
                  SegmentedControl {
                    options: root.transformOptions(card.modelData)
                    value: SettingsStore.monitorValue(card.modelData, "transform", 0)
                    onChanged: function (v) { root.commit(card.modelData, { transform: Number(v) }) }
                  }
                }

                Row {
                  visible: card.enabledHere
                  width: parent.width
                  spacing: 14

                  Text {
                    text: "Position"
                    width: 64
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    color: Color.muted
                  }
                  Text {
                    text: "X"
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: Color.muted
                  }
                  ValueSlider {
                    width: 150
                    minimum: -7680
                    maximum: 7680
                    step: 1
                    integer: true
                    value: SettingsStore.monitorValue(card.modelData, "x", 0)
                    onMoved: function (v) { root.commit(card.modelData, { x: Math.round(v) }) }
                  }
                  Text {
                    text: "Y"
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    color: Color.muted
                  }
                  ValueSlider {
                    width: 150
                    minimum: -4320
                    maximum: 4320
                    step: 1
                    integer: true
                    value: SettingsStore.monitorValue(card.modelData, "y", 0)
                    onMoved: function (v) { root.commit(card.modelData, { y: Math.round(v) }) }
                  }
                }
              }
            }
          }

          Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}