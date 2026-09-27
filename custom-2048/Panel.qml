import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "terminal.2048"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string gamePath: pluginDir + "/omarchy-2048"
  readonly property string configPath: Quickshell.env("HOME") + "/.local/state/omarchy/2048.json"

  property int size: 4
  property bool keepGoing: false
  readonly property var sizeOptions: [
    { value: 4, label: "4 × 4" },
    { value: 5, label: "5 × 5" },
    { value: 6, label: "6 × 6" },
    { value: 7, label: "7 × 7" },
    { value: 8, label: "8 × 8" }
  ]

  function open() {
    configFile.reload()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function play() {
    if (!root.bar) return
    root.close()
    root.bar.run("omarchy-launch-or-focus-tui --app-id=org.omarchy.t2048 " + root.gamePath)
  }

  function applyConfig(raw) {
    var data = {}
    try { data = JSON.parse(raw || "{}") } catch (e) { data = {} }
    if (!data || typeof data !== "object") data = {}
    var nextSize = parseInt(data.size, 10)
    var known = false
    for (var i = 0; i < sizeOptions.length; i++)
      if (sizeOptions[i].value === nextSize) known = true
    root.size = known ? nextSize : 4
    root.keepGoing = data.keep_going === true
  }

  function persist() {
    var payload = JSON.stringify({
      size: root.size,
      keep_going: root.keepGoing
    }, null, 2) + "\n"
    configFile.setText(payload)
  }

  function cycleSize(dir) {
    var idx = 0
    for (var i = 0; i < sizeOptions.length; i++)
      if (sizeOptions[i].value === root.size) idx = i
    idx = (idx + dir + sizeOptions.length) % sizeOptions.length
    root.size = sizeOptions[idx].value
    root.persist()
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("{}")
    onFileChanged: reload()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      Keys.onReturnPressed: root.play()
      Keys.onEnterPressed: root.play()
      Keys.onLeftPressed: root.cycleSize(-1)
      Keys.onRightPressed: root.cycleSize(1)
      Keys.onUpPressed: root.cycleSize(-1)
      Keys.onDownPressed: root.cycleSize(1)

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          title: "2048"
          meta: "Join the tiles, fill the screen"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          iconComponent: Component {
            Mark2048 {
              implicitWidth: Style.font.display
              implicitHeight: Style.font.display
              foreground: root.contentForeground
            }
          }
        }

        Button {
          width: parent.width
          text: "Play"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.play()
        }

        PanelSeparator { foreground: root.contentForeground }

        PanelSectionHeader {
          text: "Board size"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
        }

        Row {
          id: sizeRow
          spacing: Style.space(6)
          width: parent.width
          Repeater {
            id: sizeRepeater
            model: root.sizeOptions
            Button {
              width: (sizeRow.width - sizeRow.spacing * (sizeRepeater.count - 1)) / sizeRepeater.count
              text: modelData.label
              foreground: root.size === modelData.value ? Color.accent : root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: {
                root.size = modelData.value
                root.persist()
              }
            }
          }
        }

        Toggle {
          width: parent.width
          label: "Keep going past 2048"
          description: "Reach 2048, then keep stacking"
          checked: root.keepGoing
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: {
            root.keepGoing = !root.keepGoing
            root.persist()
          }
        }
      }
    }
  }
}
