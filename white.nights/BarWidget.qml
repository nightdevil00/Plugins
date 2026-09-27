import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "white.nights"

  readonly property var noSleepService: bar?.shell?.serviceFor("white.nights")
  readonly property bool enabled: noSleepService ? noSleepService.noSleep : false

  visible: noSleepService !== null
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍹"
    active: root.enabled
    dimmed: !root.enabled
    tooltipText: root.enabled
      ? "Sleep blocked: system stays on, screen still goes off"
      : "Suspend allowed: click to block sleep"
    onPressed: { if (root.noSleepService) root.noSleepService.toggle() }
  }
}
