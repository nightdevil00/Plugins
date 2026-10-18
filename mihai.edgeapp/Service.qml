import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// A bullet on the left or right edge, halfway down the screen. Hovering it
// slides the chosen app out beside it; the app stays until Escape or a click
// on the bullet puts it away again. Right-click the bullet for the settings
// menu: pick the side and the app. Settings are stored in this plugin's entry
// in ~/.config/omarchy/shell.json:
//   { "id": "mihai.edgeapp", "app": "org.gnome.Nautilus", "side": "right",
//     "width": 480, "height": 640 }
Item {
  id: root

  // Injected by omarchy-shell (the third-party service loader).
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginId: "mihai.edgeapp"
  readonly property string parkWorkspace: "special:edgeapp"
  readonly property string escapeBind: "mihaiEdgeappEscape"
  readonly property string hideCommand: "omarchy-shell mihai-edgeapp hide"
  readonly property int stripWidth: 18
  readonly property int stripHeight: 160
  readonly property int bulletSize: 8
  readonly property int gap: 4
  readonly property int launchTimeout: 10000
  readonly property int menuWidth: 320
  readonly property int menuHeight: 580

  property var settings: ({})
  readonly property string appKey: normalizeId(settings.app)
  readonly property var edgeEntry: appKey ? DesktopEntries.byId(appKey) : null
  readonly property bool leftSide: settings.side === "left"
  readonly property bool hoverTrigger: settings.trigger === "hover"
  readonly property int appWidth: positiveInt(settings.width, 480)
  readonly property int appHeight: positiveInt(settings.height, 640)

  property bool shown: false
  property var activeScreen: null
  property bool waiting: false
  property double waitStarted: 0

  property bool menuOpen: false
  property var menuScreen: null
  property bool appListOpen: false

  function positiveInt(value, fallback) {
    var number = Math.round(Number(value))
    return isFinite(number) && number > 0 ? number : fallback
  }

  function normalizeId(value) {
    var id = String(value || "").trim()
    if (id.slice(-8) === ".desktop") id = id.slice(0, -8)
    return id
  }

  function readSettings(raw) {
    var data = null
    try { data = JSON.parse(raw) } catch (error) { data = null }
    var entries = data && Array.isArray(data.plugins) ? data.plugins : []
    var found = {}
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] && entries[i].id === root.pluginId) {
        found = entries[i]
        break
      }
    }
    root.settings = found
  }

  // Writes one or more keys of this plugin's entry, keeping the rest of
  // shell.json. The shell reloads the file on save.
  readonly property string saveScript: [
    "import json, os, sys",
    "path = os.path.expanduser('~/.config/omarchy/shell.json')",
    "with open(path) as f: data = json.load(f)",
    "plugins = data.get('plugins') if isinstance(data.get('plugins'), list) else []",
    "entry = next((p for p in plugins if isinstance(p, dict) and p.get('id') == 'mihai.edgeapp'), None)",
    "if entry is None:",
    "    entry = {'id': 'mihai.edgeapp'}",
    "    plugins.append(entry)",
    "entry.update(json.loads(sys.argv[1]))",
    "data['plugins'] = plugins",
    "with open(path, 'w') as f:",
    "    json.dump(data, f, indent=2)",
    "    f.write('\\n')"
  ].join("\n")

  function saveSettings(patch) {
    Util.execArgv(["python3", "-c", root.saveScript, JSON.stringify(patch)])
  }

  FileView {
    path: root.home + "/.config/omarchy/shell.json"
    watchChanges: true
    onLoaded: root.readSettings(text())
    onFileChanged: reload()
  }

  function insetsFor(screen) {
    var monitor = Hyprland.monitorFor(screen)
    var reserved = monitor && monitor.lastIpcObject && monitor.lastIpcObject.reserved
      ? monitor.lastIpcObject.reserved : [0, 0, 0, 0]
    return { left: reserved[0] || 0, top: reserved[1] || 0, right: reserved[2] || 0, bottom: reserved[3] || 0 }
  }

  // Where the strip sits on its output, and where the app sits in global
  // layout coordinates, both centred on the free height beside the bar.
  function stripTop(screen) {
    var inset = insetsFor(screen)
    var usable = screen.height - inset.top - inset.bottom
    return inset.top + Math.round((usable - root.stripHeight) / 2)
  }

  function menuTop(screen) {
    var inset = insetsFor(screen)
    var top = root.stripTop(screen) + Math.round(root.stripHeight / 2) - Math.round(root.menuHeight / 2)
    return Math.max(inset.top + 8, Math.min(top, screen.height - root.menuHeight - 8))
  }

  function appFrame(screen) {
    var inset = insetsFor(screen)
    var usable = screen.height - inset.top - inset.bottom
    var height = Math.max(120, Math.min(root.appHeight, usable - 16))
    var width = Math.max(160, Math.min(root.appWidth, screen.width - inset.left - inset.right - root.stripWidth - root.gap * 2))
    var y = screen.y + inset.top + Math.round((usable - height) / 2)
    var x = root.leftSide
      ? screen.x + inset.left + root.stripWidth + root.gap
      : screen.x + screen.width - inset.right - root.stripWidth - root.gap - width
    return { x: Math.round(x), y: Math.round(y), width: Math.round(width), height: Math.round(height) }
  }

  function windowFor() {
    if (!root.edgeEntry) return null
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var appId = toplevel.wayland ? String(toplevel.wayland.appId || "") : ""
      if (!appId) continue
      if (appId.toLowerCase() === root.appKey.toLowerCase()) return toplevel
      var match = DesktopEntries.heuristicLookup(appId)
      if (match && match.id === root.edgeEntry.id) return toplevel
    }
    return null
  }

  function addressOf(toplevel) {
    var address = String(toplevel.address || "")
    return address.indexOf("0x") === 0 ? address : "0x" + address
  }

  function dispatch(step) {
    return "hyprctl dispatch " + Util.shellQuote(step)
  }

  function bindEscape() {
    return "hyprctl eval " + Util.shellQuote(
      "if " + root.escapeBind + " then " + root.escapeBind + ":unbind() end; "
      + root.escapeBind + " = hl.bind('ESCAPE', hl.dsp.exec_cmd('" + root.hideCommand + "'), { description = 'Hide edge app' })")
  }

  function unbindEscape() {
    return "hyprctl eval " + Util.shellQuote(
      "if " + root.escapeBind + " then " + root.escapeBind + ":unbind(); " + root.escapeBind + " = nil end")
  }

  function show(screen) {
    if (root.shown || !root.edgeEntry || !screen) return
    root.activeScreen = screen
    var toplevel = root.windowFor()
    if (toplevel) {
      root.place(toplevel, screen)
      return
    }
    if (!root.waiting) {
      root.waiting = true
      root.waitStarted = Date.now()
      waitTimer.restart()
      root.edgeEntry.execute()
    }
  }

  function place(toplevel, screen) {
    var monitor = Hyprland.monitorFor(screen)
    var workspaceId = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    if (!(workspaceId >= 1)) return
    var frame = root.appFrame(screen)
    var target = "window = 'address:" + root.addressOf(toplevel) + "'"
    // Floated, sized and placed while parked, so the window only becomes
    // visible already at its edge position.
    var steps = [
      "hl.dsp.window.move({ workspace = '" + root.parkWorkspace + "', follow = false, " + target + " })",
      "hl.dsp.window.float({ action = 'enable', " + target + " })",
      "hl.dsp.window.resize({ x = " + frame.width + ", y = " + frame.height + ", " + target + " })",
      "hl.dsp.window.move({ x = " + frame.x + ", y = " + frame.y + ", " + target + " })",
      "hl.dsp.window.move({ workspace = '" + workspaceId + "', follow = false, " + target + " })",
      "hl.dsp.window.alter_zorder({ mode = 'top', " + target + " })",
      "hl.dsp.focus({ " + target + " })"
    ]
    var commands = steps.map(root.dispatch)
    commands.push(root.bindEscape())
    Util.execDetached(commands.join("; "))
    root.shown = true
  }

  function hide() {
    root.waiting = false
    waitTimer.stop()
    var commands = []
    var toplevel = root.windowFor()
    if (toplevel) {
      commands.push(root.dispatch(
        "hl.dsp.window.move({ workspace = '" + root.parkWorkspace + "', follow = false, window = 'address:" + root.addressOf(toplevel) + "' })"))
    }
    commands.push(root.unbindEscape())
    Util.execDetached(commands.join("; "))
    root.shown = false
  }

  function toggle(screen) {
    if (root.shown) root.hide()
    else root.show(screen)
  }

  function openMenu(screen) {
    root.menuScreen = screen
    root.appListOpen = false
    root.menuOpen = true
  }

  function closeMenu() {
    root.menuOpen = false
    root.appListOpen = false
  }

  function chooseSide(side) {
    root.saveSettings({ side: side })
  }

  function chooseTrigger(trigger) {
    root.saveSettings({ trigger: trigger })
  }

  function chooseApp(id) {
    if (root.shown) root.hide()
    root.saveSettings({ app: id })
    root.appListOpen = false
  }

  function filterApps(query) {
    var values = DesktopEntries.applications.values || []
    var needle = String(query || "").trim().toLowerCase()
    var out = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay) continue
      var name = String(entry.name || entry.id)
      if (needle && name.toLowerCase().indexOf(needle) < 0 && String(entry.id).toLowerCase().indexOf(needle) < 0) continue
      out.push({ id: String(entry.id), name: name, icon: String(entry.icon || "") })
    }
    out.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return out.slice(0, 300)
  }

  // A launched app that has not mapped yet is waited for, then slid out.
  Timer {
    id: waitTimer
    interval: 30
    repeat: true
    onTriggered: {
      var toplevel = root.windowFor()
      if (toplevel) {
        root.waiting = false
        waitTimer.stop()
        root.place(toplevel, root.activeScreen)
      } else if (Date.now() - root.waitStarted > root.launchTimeout) {
        root.waiting = false
        waitTimer.stop()
      }
    }
  }

  // If the app is closed while it is out, the bullet goes back to resting.
  Timer {
    id: closeCheck
    interval: 150
    onTriggered: {
      if (root.shown && !root.windowFor()) {
        root.shown = false
        Util.execDetached(root.unbindEscape())
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.shown && event && String(event.name) === "closewindow") closeCheck.restart()
    }
  }

  Component.onCompleted: Util.execDetached(root.unbindEscape())

  IpcHandler {
    target: "mihai-edgeapp"

    function show(): string {
      root.show(root.activeScreen || Quickshell.screens[0])
      return "ok"
    }
    function hide(): string { root.hide(); return "ok" }
    function toggle(): string {
      root.toggle(root.activeScreen || Quickshell.screens[0])
      return "ok"
    }
    function settings(): string { root.openMenu(Quickshell.screens[0]); return "ok" }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: strip

        required property var modelData

        screen: modelData
        color: "transparent"
        implicitWidth: root.stripWidth
        implicitHeight: root.stripHeight
        WlrLayershell.namespace: "mihai-edgeapp"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors {
          top: true
          left: root.leftSide
          right: !root.leftSide
        }
        margins.top: root.stripTop(strip.modelData)

        Rectangle {
          id: bullet

          anchors.centerIn: parent
          width: root.bulletSize
          height: root.bulletSize
          radius: width / 2
          color: Commons.Color.accent
          opacity: hover.hovered || root.shown || root.menuOpen && root.menuScreen === strip.modelData ? 1 : 0

          Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
          }
        }

        HoverHandler {
          id: hover
          onHoveredChanged: if (hovered && root.hoverTrigger && root.appKey) root.show(strip.modelData)
        }

        TapHandler {
          acceptedButtons: Qt.LeftButton
          onTapped: {
            if (!root.appKey) root.openMenu(strip.modelData)
            else root.toggle(strip.modelData)
          }
        }

        TapHandler {
          acceptedButtons: Qt.RightButton
          onTapped: root.openMenu(strip.modelData)
        }
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: menu

        required property var modelData

        screen: modelData
        visible: root.menuOpen && root.menuScreen === modelData
        color: "transparent"
        implicitWidth: root.menuWidth
        implicitHeight: root.menuHeight
        WlrLayershell.namespace: "mihai-edgeapp-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors {
          top: true
          left: root.leftSide
          right: !root.leftSide
        }
        margins.top: root.menuTop(menu.modelData)
        margins.left: root.leftSide ? root.stripWidth + root.gap * 2 : 0
        margins.right: root.leftSide ? 0 : root.stripWidth + root.gap * 2

        onVisibleChanged: if (visible) search.text = ""

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: Commons.Color.popups.background
          border.color: Commons.Color.popups.border
          border.width: Style.normalBorderWidth

          focus: true
          Keys.onEscapePressed: root.closeMenu()

          Column {
            anchors.fill: parent
            anchors.margins: Style.spacing.sm
            spacing: Style.spacing.sm

            Text {
              textFormat: Text.PlainText
              text: "Edge App"
              color: Commons.Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              text: "Side"
              color: Commons.Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Row {
              spacing: Style.spacing.sm

              Repeater {
                model: ["left", "right"]

                delegate: Rectangle {
                  required property string modelData

                  width: 120
                  height: 32
                  radius: Style.cornerRadius
                  color: (root.leftSide ? "left" : "right") === modelData ? Commons.Color.accent : "transparent"
                  border.color: Commons.Color.popups.border
                  border.width: Style.normalBorderWidth

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData === "left" ? "Left" : "Right"
                    color: (root.leftSide ? "left" : "right") === modelData ? Commons.Color.popups.background : Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chooseSide(modelData)
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "Open on"
              color: Commons.Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Row {
              spacing: Style.spacing.sm

              Repeater {
                model: ["click", "hover"]

                delegate: Rectangle {
                  required property string modelData

                  width: 120
                  height: 32
                  radius: Style.cornerRadius
                  color: (root.hoverTrigger ? "hover" : "click") === modelData ? Commons.Color.accent : "transparent"
                  border.color: Commons.Color.popups.border
                  border.width: Style.normalBorderWidth

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData === "click" ? "Click" : "Hover"
                    color: (root.hoverTrigger ? "hover" : "click") === modelData ? Commons.Color.popups.background : Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chooseTrigger(modelData)
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "App"
              color: Commons.Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            Rectangle {
              width: parent.width
              height: 32
              radius: Style.cornerRadius
              color: root.appListOpen ? Style.hoverFill : "transparent"
              border.color: Commons.Color.popups.border
              border.width: Style.normalBorderWidth

              Text {
                anchors.verticalCenter: parent.verticalCenter
                x: Style.spacing.sm
                width: parent.width - Style.spacing.sm * 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: root.edgeEntry ? root.edgeEntry.name : (root.appKey || "Choose an app")
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.appListOpen = !root.appListOpen
              }
            }

            Rectangle {
              visible: root.appListOpen
              width: parent.width
              height: 32
              radius: Style.cornerRadius
              color: "transparent"
              border.color: Commons.Color.popups.border
              border.width: Style.normalBorderWidth

              TextInput {
                id: search

                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                focus: menu.visible && root.appListOpen
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                clip: true
                Keys.onEscapePressed: root.closeMenu()
                onVisibleChanged: if (visible) forceActiveFocus()

                Text {
                  visible: search.text.length === 0
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Search apps"
                  color: Commons.Color.muted
                  font: search.font
                }
              }
            }

            ListView {
              visible: root.appListOpen
              width: parent.width
              height: 240
              clip: true
              model: root.filterApps(search.text)

              delegate: Rectangle {
                required property var modelData

                width: ListView.view.width
                height: 32
                radius: Style.cornerRadius
                color: rowMouse.containsMouse ? Style.hoverFill : "transparent"

                Image {
                  id: rowIcon
                  x: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter
                  width: 20
                  height: 20
                  sourceSize: Qt.size(40, 40)
                  source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                  asynchronous: true
                  fillMode: Image.PreserveAspectFit
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  x: rowIcon.x + 28
                  width: parent.width - x - Style.spacing.sm
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: modelData.name
                  color: Commons.Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.chooseApp(modelData.id)
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 32
              radius: Style.cornerRadius
              color: closeMouse.containsMouse ? Style.hoverFill : "transparent"
              border.color: Commons.Color.popups.border
              border.width: Style.normalBorderWidth

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "Close (Esc)"
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeMenu()
              }
            }
          }
        }
      }
    }
  }
}
