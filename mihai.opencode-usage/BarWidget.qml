import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button for opencode usage: a robot mark, and today's token total when
// the bar is horizontal. Left click opens the panel; right click refreshes.
// The panel reads `root.record`, which the collector process refreshes here,
// so a panel left open catches up on the same timer as the button.
BarWidget {
  id: root
  moduleName: "mihai.opencode-usage"

  property var record: ({})
  property bool loading: false

  readonly property string glyph: "\uf1b0"
  readonly property color buttonForeground: bar ? bar.foreground : ShellColor.foreground
  readonly property string buttonFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int refreshIntervalSec: Math.max(15, Number(setting("refreshIntervalSec", 60)))
  readonly property string dbPath: String(setting("dbPath", "") || "")

  // The collector ships next to this widget; resolve its path from the entry
  // point URL rather than assuming a fixed location.
  readonly property string scriptPath: {
    var url = String(Qt.resolvedUrl("collect.py"))
    var path = url.replace(/^file:\/\//, "")
    try { path = decodeURIComponent(path) } catch (e) {}
    return path
  }

  property var panelLoader: null
  readonly property bool opened: panelLoader && panelLoader.item
    ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader && panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button ? button.labelWidth : 0
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function formatTokens(n) {
    n = Number(n || 0)
    if (n >= 1000000) return (n / 1000000).toFixed(2).replace(/\.?0+$/, "") + "M"
    if (n >= 10000) return (n / 1000).toFixed(0) + "K"
    if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "K"
    return String(n)
  }

  function todayTokens() {
    return Number((root.record.today || {}).total || 0)
  }

  function tooltipText() {
    var t = Number((root.record.today || {}).total || 0)
    if (Object.keys(root.record).length === 0 || (root.record.ready === false)) return "opencode usage"
    return "opencode — " + formatTokens(t) + " tokens today"
  }

  function refresh() {
    if (!collectProc.running) collectProc.running = true
    if (panelLoader && panelLoader.item && panelLoader.item.refreshViews)
      panelLoader.item.refreshViews()
  }

  function injectPanel() {
    var target = panelLoader ? panelLoader.item : null
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader && panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader && panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader && panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader && panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: Qt.callLater(injectPanel)
  onSettingsChanged: Qt.callLater(injectPanel)
  Component.onCompleted: Qt.callLater(injectPanel)

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: root.injectPanel()
  }

  IpcHandler {
    target: "mihai.opencode-usage"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Process {
    id: collectProc

    function buildCommand() {
      var cmd = ["python3", root.scriptPath]
      if (root.dbPath !== "") cmd.push("--db", root.dbPath)
      return cmd
    }
    command: buildCommand()

    onStarted: root.loading = true
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) return
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          if (parsed && typeof parsed === "object") root.record = parsed
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: true
    hasVisualContent: true
    dimmed: Object.keys(root.record).length === 0 || root.record.ready === false
    tooltipText: root.tooltipText()
    text: root.vertical ? root.glyph : root.glyph + " " + root.formatTokens(root.todayTokens())
    fontFamily: root.buttonFontFamily
    fontSize: Style.font.caption
    horizontalMargin: 8.5
    verticalPadding: 6

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }
}