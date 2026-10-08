import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button for the local llama servers: a server glyph, and the loaded
// model's tag (or "…" while one is loading, "off" when none is resident).
// Left click opens the panel; right click refreshes status. The panel reads
// `root.record`, which the status process keeps fresh here, so a panel left
// open updates on the same timer as the button.
BarWidget {
  id: root
  moduleName: "mihai.llama"

  property var record: ({})
  property var prevStates: ({})
  property bool loading: false
  property variant actionCommand: []
  property variant notifyCommand: []

  readonly property string glyph: "\uf233"
  readonly property color buttonForeground: bar ? bar.foreground : ShellColor.foreground
  readonly property string buttonFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int refreshIntervalSec: Math.max(3, Number(setting("refreshIntervalSec", 3) || 3))

  // The control script ships next to this widget; resolve its path from the
  // entry point URL rather than assuming a fixed location. It never writes
  // files here (launchers, markers and logs stay in ~/llama-serve), so the
  // shell's plugin file-watcher is never triggered by it.
  readonly property string scriptPath: {
    var url = String(Qt.resolvedUrl("llama_ctl.py"))
    var path = url.replace(/^file:\/\//, "")
    try { path = decodeURIComponent(path) } catch (e) {}
    return path
  }

  property var panelLoader: null
  readonly property bool opened: panelLoader && panelLoader.item
    ? panelLoader.item.opened === true : false

  function modelList(state) {
    var out = []
    var ms = root.record.models || []
    for (var i = 0; i < ms.length; i++)
      if (ms[i].state === state) out.push(ms[i])
    return out
  }

  function loadedTags() {
    var out = []
    var ms = root.modelList("loaded")
    for (var i = 0; i < ms.length; i++) out.push(ms[i].tag)
    return out
  }

  function startingTag() {
    var ms = root.modelList("starting")
    return ms.length > 0 ? String(ms[0].tag) : ""
  }

  function gpuFreeMb() {
    var g = root.record.gpu || {}
    return Number(g.total_mb || 0) - Number(g.used_mb || 0)
  }

  function statusLabel() {
    if (Object.keys(root.record).length === 0 || root.record.ready !== true)
      return "…"
    var tags = root.loadedTags()
    if (tags.length > 0) return tags.join("+")
    if (root.startingTag() !== "") return root.startingTag() + "…"
    return "off"
  }

  function tooltipText() {
    if (Object.keys(root.record).length === 0 || root.record.ready !== true)
      return "local llama"
    var lines = ["local llama"]
    var tags = root.loadedTags()
    var st = root.startingTag()
    if (tags.length > 0) lines.push("loaded: " + tags.join(", "))
    else if (st !== "") lines.push("loading model " + st + "…")
    else lines.push("no model loaded")
    lines.push(Math.round(root.gpuFreeMb() / 1024) + " GB VRAM free")
    return lines.join("\n")
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function injectPanel() {
    var target = panelLoader ? panelLoader.item : null
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function openPanel() { if (panelLoader && panelLoader.item) panelLoader.item.open() }
  function closePanel() { if (panelLoader && panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader && panelLoader.item) panelLoader.item.toggle() }

  // Owner contract for KeyboardPanel.close(): it checks for "close" on its
  // owner (this widget) and only falls back to hiding the surface — leaving
  // the PanelController untouched — when owner.close is missing. Forward the
  // lifecycle through to the panel so outside-click/Escape dismissal resets
  // `opened` and the next icon click really opens.
  function open() { root.openPanel() }
  function close() { root.closePanel() }
  function toggle() { root.togglePanel() }

  // `action` is "load" or "unload"; the status timer reflects the change.
  function doAction(action, modelId) {
    root.actionCommand = ["python3", root.scriptPath, action, modelId]
    if (!actionProc.running) actionProc.running = true
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
    target: "mihai.llama"

    function refresh(): void { root.refresh() }
    function open(): void { root.openPanel() }
    function close(): void { root.closePanel() }
    function show(): void { root.openPanel() }
    function hide(): void { root.closePanel() }
    function toggle(): void { root.togglePanel() }
  }

  Process {
    id: statusProc

    command: ["python3", root.scriptPath, "status"]

    onStarted: root.loading = true
    onExited: function(exitCode) { root.loading = false }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          if (parsed && typeof parsed === "object") root.acceptStatus(parsed)
        } catch (e) {}
      }
    }
  }

  // Fold fresh status into the record, spot transitions to "loaded", and
  // pop a desktop notification so you know the moment opencode can use it.
  function acceptStatus(parsed) {
    var ms = parsed.models || []
    for (var i = 0; i < ms.length; i++) {
      var m = ms[i]
      var was = root.prevStates[m.id]
      if (m.state === "loaded" && was !== "loaded") {
        root.notifyCommand = [
          "notify-send", "-a", "mihai.llama",
          m.name + " loaded",
          "Select " + m.opencode + " in opencode (/models). Unload frees the memory."
        ]
        if (!notifyProc.running) notifyProc.running = true
      }
      root.prevStates[m.id] = m.state
    }
    root.record = parsed
  }

  Process {
    id: actionProc

    command: root.actionCommand

    onExited: function(exitCode) { root.refresh() }

    stdout: StdioCollector {
      waitForEnd: true
    }
  }

  Process {
    id: notifyProc

    command: root.notifyCommand

    stdout: StdioCollector {
      waitForEnd: true
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
    dimmed: root.statusLabel() === "off"
    tooltipText: root.tooltipText()
    text: root.vertical ? root.glyph : root.glyph + " " + root.statusLabel()
    fontFamily: root.buttonFontFamily
    fontSize: Style.font.caption
    horizontalMargin: 8.5
    verticalPadding: 6

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }
  }
}