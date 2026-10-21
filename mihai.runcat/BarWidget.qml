import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button: the RunCat running cat. Frame speed follows CPU load. Left click opens btop.
// Sprites: https://github.com/win0err/gnome-runcat (GPL-3.0)
BarWidget {
  id: root
  moduleName: "mihai.runcat"

  property real cpu: 0
  property real lastIdle: -1
  property real lastTotal: -1
  property int frame: 0
  readonly property bool resting: cpu < 2
  readonly property string sprite: resting
    ? Qt.resolvedUrl("frames/idle.svg")
    : Qt.resolvedUrl("frames/sprite-" + frame + ".svg")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function readStat(text) {
    var f = text.trim().split(/\s+/).slice(1).map(Number)
    if (f.length < 5) return
    var idle = f[3] + f[4]
    var total = f.slice(0, 8).reduce(function(a, b) { return a + b }, 0)
    if (lastTotal >= 0 && total > lastTotal) {
      cpu = Math.max(0, Math.min(100, 100 * (1 - (idle - lastIdle) / (total - lastTotal))))
    }
    lastIdle = idle
    lastTotal = total
  }

  Process {
    id: statProc
    command: ["bash", "-c", "head -n1 /proc/stat"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.readStat(text)
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statProc.running) statProc.running = true
  }

  Timer {
    interval: Math.max(40, Math.round(200 - root.cpu * 1.6))
    running: !root.resting
    repeat: true
    onTriggered: root.frame = (root.frame + 1) % 5
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    tooltipText: "CPU " + Math.round(root.cpu) + "%"
    fixedWidth: root.vertical ? -1 : Math.round(content.implicitWidth + scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.round(content.implicitHeight + scaledVerticalPadding * 2) : -1

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.bar.run("omarchy-launch-tui btop")
    }

    Item {
      id: content
      anchors.centerIn: parent
      implicitWidth: Math.round(Style.bar.iconCanvas * 1.5)
      implicitHeight: Math.round(Style.bar.iconCanvas * 1.5)

      Image {
        id: spriteImage
        anchors.fill: parent
        source: root.sprite
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
      }

      MultiEffect {
        anchors.fill: spriteImage
        source: spriteImage
        colorization: 1
        colorizationColor: button.foreground
      }
    }
  }
}
