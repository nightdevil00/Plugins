// simple.dock — centered autohiding app dock opposite the bar.
//
// A full-screen, click-through overlay with an interactive dock card at the
// bottom center (opposite the bar). Shows the apps-menu button, pinned apps,
// and running apps. Pinned apps persist to ~/.config/omarchy/dock.json.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

Item {
  id: root

  // ----------------------------------------------------- inline components
  // App icon entry: hover highlight, icon, running indicator, click actions.
  component DockItem: Item {
    id: item

    property string appId: ""
    property string name: ""
    property string icon: ""
    property bool running: false
    property int windows: 0
    property bool active: false

    signal activateRequested(string appId)
    signal menuRequested(string appId, real x, real y)

    width: root.iconSlot
    height: root.iconSlot

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: Style.cornerRadius
      color: area.containsMouse
        ? (area.pressed ? Style.pressedFill : Style.hoverFill)
        : (item.active ? Style.selectedFill : "transparent")
      border.color: area.containsMouse ? Style.hoverBorderColor : "transparent"
      border.width: Style.hoverBorderWidth

      Image {
        anchors.centerIn: parent
        width: root.iconSize - Style.space(10)
        height: width
        source: item.icon !== "" ? item.icon : Quickshell.iconPath("application-x-executable", true)
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        visible: source !== ""
        mipmap: true
        smooth: true
      }
    }

    // Running indicator: bright/solid when the app is focused, dim otherwise.
    Rectangle {
      id: indicator
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(2)
      width: item.active ? Style.space(8) : Style.space(5)
      height: item.active ? Style.space(3) : Style.space(2)
      radius: height / 2
      color: item.active ? Color.bar.active : Util.alpha(Color.bar.text, 0.6)
      visible: item.running
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          var center = item.mapToItem(dockWindow.contentItem, item.width / 2, item.height / 2)
          item.menuRequested(item.appId, center.x, center.y)
        } else {
          item.activateRequested(item.appId)
        }
      }
      onEntered: {
        root.cardEnter()
        root.showTooltip(item.name, item)
      }
      onExited: {
        root.cardLeave()
        root.hideTooltip()
      }
    }
  }

  // Glyph button (used for the apps-menu launcher).
  component DockIconButton: Item {
    id: btn

    property string glyph: ""
    property string tooltip: ""
    property color glyphColor: Color.bar.text
    property real glyphSize: root.iconSize * 0.42
    signal pressed()

    width: root.iconSlot
    height: root.iconSlot

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: Style.cornerRadius
      color: area.containsMouse ? (area.pressed ? Style.pressedFill : Style.hoverFill) : "transparent"
      border.color: area.containsMouse ? Style.hoverBorderColor : "transparent"
      border.width: Style.hoverBorderWidth

      Text {
        anchors.centerIn: parent
        text: btn.glyph
        font.family: "omarchy"
        font.pixelSize: btn.glyphSize
        color: btn.glyphColor
      }
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.pressed()
      onEntered: {
        root.cardEnter()
        root.showTooltip(btn.tooltip, btn)
      }
      onExited: {
        root.cardLeave()
        root.hideTooltip()
      }
    }
  }

  // One row of the right-click context menu.
  component ContextRow: Item {
    id: crow

    property string text: ""
    property color textColor: Color.menu.text
    property bool danger: false
    signal triggered()

    width: 150
    height: Math.max(26, Style.space(26))

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: area.containsMouse
        ? (crow.danger ? Util.alpha(Color.urgent, 0.14) : Color.menu.selectedBackground)
        : "transparent"
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: crow.text
      color: area.containsMouse && crow.danger ? Color.urgent : crow.textColor
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: crow.triggered()
    }
  }

  // Injected by omarchy-shell (overlay kind, keepLoaded).
  property var shell: null
  property string omarchyPath: ""
  property var manifest: null

  readonly property string dockPath: Quickshell.env("HOME") + "/.config/omarchy/dock.json"
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/simple.dock.json"

  // Monitor to attach the dock to ("screen" in simple.dock.json). Defaults to
  // the first screen Quickshell reports.
  property string screenName: ""
  readonly property var dockScreen: root.screenName
    ? root.screenForName(root.screenName)
    : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

  function screenForName(name) {
    var list = Quickshell.screens
    for (var i = 0; i < list.length; i++)
      if (list[i].name === name) return list[i]
    return null
  }

  readonly property var appLibrary: shell ? shell.appLibrary : null

  // Sizing. The icon sits in a slightly padded slot; the card wraps the row.
  readonly property int iconSize: Math.max(28, Math.round(Style.bar.sizeHorizontal * 0.9))
  readonly property int iconSlot: root.iconSize + Style.space(10)

  // Model. Built imperatively so it updates from explicit signals — a QML
  // binding through ToplevelManager.toplevels.values (a V4Sequence exposed on
  // a CONSTANT property) is not reliably reactive.
  property var pinnedIds: []
  property var appRows: []
  property var dockModel: ({ pinned: [], running: [] })
  readonly property var pinnedSection: root.dockModel.pinned
  readonly property var runningSection: root.dockModel.running

  function refreshDock() {
    root.dockModel = root.shell && root.shell.appLibrary
      ? DockModel.buildEntries(root.pinnedIds, ToplevelManager.toplevels.values, root.appRows, root.shell.appLibrary)
      : { pinned: [], running: [] }
  }

  readonly property string activeId: ToplevelManager.activeToplevel
    ? DockModel.normalizeId(ToplevelManager.activeToplevel.appId)
    : ""

  // Context menu state ("" = closed).
  property string contextAppId: ""
  property string contextName: ""
  property bool contextPinned: false
  property int contextWindows: 0
  property real contextX: 0
  property real contextY: 0

  // Tooltip state.
  property string tooltipText: ""
  property real tooltipX: 0
  property real tooltipY: 0

  // Autohide. Hidden by default; the bottom edge acts as a reveal strip, and
  // the dock slides up while the cursor is over it (or a context menu is
  // open) and slides away shortly after the cursor leaves. Set "autohide" to
  // false in ~/.config/omarchy/simple.dock.json to keep the dock pinned.
  property bool autohide: true
  property bool dockVisible: false
  property bool revealHovered: false
  property int cardHoverers: 0
  readonly property int revealHeight: 6

  Timer {
    id: hideTimer
    interval: 400
    onTriggered: {
      root.dockVisible = false
      root.hideTooltip()
    }
  }

  function cardEnter() {
    root.cardHoverers += 1
    root.syncVisibility()
  }
  function cardLeave() {
    root.cardHoverers = Math.max(0, root.cardHoverers - 1)
    root.syncVisibility()
  }
  function syncVisibility() {
    if (!root.autohide) {
      hideTimer.stop()
      root.dockVisible = true
      return
    }
    if (root.revealHovered || root.cardHoverers > 0 || root.contextAppId !== "") {
      hideTimer.stop()
      if (!root.dockVisible) root.dockVisible = true
    } else if (root.dockVisible) {
      hideTimer.restart()
    }
  }

  onRevealHoveredChanged: root.syncVisibility()
  onContextAppIdChanged: root.syncVisibility()
  onAutohideChanged: root.syncVisibility()
  // Rebuilds can destroy a hovered item (e.g. a window closes) and leak a
  // hover count; drop it so the dock can still autohide.
  onDockModelChanged: root.cardHoverers = 0

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    onLoaded: root.loadConfig()
    onFileChanged: configFile.reload()
  }

  FileView {
    id: dockFile
    path: root.dockPath
    watchChanges: true
    atomicWrites: true
    onLoaded: root.loadPinned()
    onFileChanged: dockFile.reload()
  }

  Connections {
    target: root.appLibrary
    enabled: target !== null
    function onAppsChanged() { root.rescanApps() }
  }

  // ToplevelList exposes `values` (a V4Sequence) on a CONSTANT property, so
  // bindings through it never re-run. Listen explicitly to keep the running
  // section in sync as windows open/close.
  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.refreshDock() }
  }

  onShellChanged: root.rescanApps()
  onPinnedIdsChanged: root.refreshDock()

  function loadPinned() {
    root.pinnedIds = DockModel.parsePinned(dockFile.text())
  }

  function loadConfig() {
    var raw = String(configFile.text() || "").trim()
    var parsed = {}
    if (raw) {
      try {
        parsed = JSON.parse(raw)
      } catch (e) {
        parsed = {}
      }
    }
    root.autohide = parsed && parsed.autohide !== false
    root.screenName = parsed && typeof parsed.screen === "string" ? parsed.screen : ""
  }

  function rescanApps() {
    root.appRows = root.shell && root.shell.appLibrary ? root.shell.appLibrary.sortedEntries("") : []
    root.refreshDock()
  }

  function toggleAppsMenu() {
    if (root.shell) root.shell.toggle("omarchy.menu", '{"menu":"apps"}')
  }

  function activate(appId) {
    if (!root.shell || !root.shell.appLibrary) return
    var entry = root.entryForId(appId)
    if (entry && entry.running) {
      DockModel.activateApp(ToplevelManager.toplevels.values, ToplevelManager.activeToplevel, appId)
    } else {
      root.shell.appLibrary.launch(appId, entry ? entry.name : appId)
    }
  }

  function entryForId(appId) {
    var i
    for (i = 0; i < root.pinnedSection.length; i++)
      if (root.pinnedSection[i].appId === appId) return root.pinnedSection[i]
    for (i = 0; i < root.runningSection.length; i++)
      if (root.runningSection[i].appId === appId) return root.runningSection[i]
    return null
  }

  function setPinned(next) {
    root.pinnedIds = next
    dockFile.setText(DockModel.serializePinned(next))
  }

  function togglePin(appId) {
    root.setPinned(DockModel.togglePinned(root.pinnedIds, appId))
  }

  function openContext(appId, x, y) {
    var entry = root.entryForId(appId)
    root.contextName = entry ? entry.name : appId
    root.contextWindows = entry ? entry.windows : 0
    root.contextPinned = DockModel.isPinned(root.pinnedIds, appId)
    root.contextX = x
    root.contextY = y
    root.contextAppId = appId
  }

  function closeContext() {
    root.contextAppId = ""
  }

  function showTooltip(text, anchorItem) {
    if (!text) return
    var pt = anchorItem.mapToItem(dockWindow.contentItem, anchorItem.width / 2, 0)
    root.tooltipText = text
    root.tooltipX = pt.x
    root.tooltipY = pt.y
  }

  function hideTooltip() {
    root.tooltipText = ""
  }

  // ------------------------------------------------------------------ window
  // Full-screen, click-through overlay surface. Only the dock card (and an
  // open context menu) receive input; the rest of the screen passes through.

  PanelWindow {
    id: dockWindow

    screen: root.dockScreen
    color: "transparent"
    WlrLayershell.namespace: "simple-dock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    mask: Region {
      item: dockCard
      regions: [
        Region { item: contextMenu },
        Region { item: root.autohide ? revealStrip : undefined }
      ]
    }

    // Bottom edge reveal strip. Part of the input mask at all times so the
    // compositor delivers pointer events when the cursor reaches the screen
    // bottom; hovering it pops the dock up.
    Item {
      id: revealStrip
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: root.revealHeight

      MouseArea {
        id: revealArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.revealHovered = true
        onExited: root.revealHovered = false
      }
    }

    // ---------------------------------------------------------------- dock card

  BorderSurface {
    id: dockCard
    color: Color.bar.background
    borderSpec: Border.flat(Color.bar.text, 1)
    radius: Math.min(Style.cornerRadius, height / 2)
    padding: Style.space(4)
    z: 1

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.dockVisible ? Style.gapsOut : -(dockCard.height + Style.gapsOut)

    Behavior on anchors.bottomMargin {
      NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    opacity: root.dockVisible ? 1 : 0
    Behavior on opacity {
      NumberAnimation { duration: 180 }
    }

    width: row.implicitWidth + contentLeftInset + contentRightInset
    height: row.implicitHeight + contentTopInset + contentBottomInset

    // Clicking the card padding dismisses an open context menu.
    MouseArea {
      id: cardArea
      anchors.fill: parent
      z: 0
      hoverEnabled: true
      onEntered: root.cardEnter()
      onExited: root.cardLeave()
      onClicked: if (root.contextAppId !== "") root.closeContext()
    }

    Row {
      id: row
      z: 1
      spacing: Style.space(2)

      anchors.left: parent.left
      anchors.leftMargin: dockCard.contentLeftInset
      anchors.right: parent.right
      anchors.rightMargin: dockCard.contentRightInset
      anchors.top: parent.top
      anchors.topMargin: dockCard.contentTopInset
      anchors.bottom: parent.bottom
      anchors.bottomMargin: dockCard.contentBottomInset

      DockIconButton {
        glyph: "\ue900"
        tooltip: "Apps"
        onPressed: root.toggleAppsMenu()
      }

      Repeater {
        model: root.pinnedSection
        delegate: DockItem {
          appId: modelData.appId
          name: modelData.name
          icon: modelData.icon
          running: modelData.running
          windows: modelData.windows
          active: modelData.appId === root.activeId
          onActivateRequested: root.activate(appId)
          onMenuRequested: root.openContext(appId, x, y)
        }
      }

      Rectangle {
        id: separator
        visible: root.pinnedSection.length > 0 && root.runningSection.length > 0
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(1)
        height: root.iconSize
        color: Util.alpha(Color.bar.text, 0.35)
      }

      Repeater {
        model: root.runningSection
        delegate: DockItem {
          appId: modelData.appId
          name: modelData.name
          icon: modelData.icon
          running: modelData.running
          windows: modelData.windows
          active: modelData.appId === root.activeId
          onActivateRequested: root.activate(appId)
          onMenuRequested: root.openContext(appId, x, y)
        }
      }
    }
  }

  // ------------------------------------------------------------ context menu

  BorderSurface {
    id: contextMenu
    visible: root.contextAppId !== ""
    z: 100
    color: Color.menu.background
    borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, 1)
    radius: Style.cornerRadius
    padding: Style.space(3)

    width: root.contextAppId !== ""
      ? menuColumn.implicitWidth + contentLeftInset + contentRightInset
      : 0
    height: root.contextAppId !== ""
      ? menuColumn.implicitHeight + contentTopInset + contentBottomInset
      : 0
    x: Math.max(0, Math.min(dockWindow.width - width, root.contextX - width / 2))
    y: Math.max(0, root.contextY - height - Style.space(12))

    Column {
      id: menuColumn
      spacing: Style.space(1)

      anchors.left: parent.left
      anchors.leftMargin: contextMenu.contentLeftInset
      anchors.right: parent.right
      anchors.rightMargin: contextMenu.contentRightInset
      anchors.top: parent.top
      anchors.topMargin: contextMenu.contentTopInset
      anchors.bottom: parent.bottom
      anchors.bottomMargin: contextMenu.contentBottomInset

      ContextRow {
        text: "Launch"
        onTriggered: {
          if (root.shell && root.shell.appLibrary)
            root.shell.appLibrary.launch(root.contextAppId, root.contextName)
          root.closeContext()
        }
      }

      ContextRow {
        text: root.contextPinned ? "Unpin from Dock" : "Pin to Dock"
        onTriggered: {
          root.togglePin(root.contextAppId)
          root.closeContext()
        }
      }

      ContextRow {
        text: "Close Window(s)"
        visible: root.contextWindows > 0
        danger: true
        onTriggered: {
          DockModel.closeApp(ToplevelManager.toplevels.values, root.contextAppId)
          root.closeContext()
        }
      }
    }
  }

  // ------------------------------------------------------------------ tooltip

  BorderSurface {
    id: tooltipCard
    visible: root.tooltipText !== ""
    z: 200
    color: Color.tooltip.background
    borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
    radius: Style.cornerRadius
    padding: Style.space(4)

    x: Math.max(0, Math.min(dockWindow.width - width, root.tooltipX - width / 2))
    y: Math.max(0, root.tooltipY - height - Style.space(8))
    width: tooltipLabel.implicitWidth + contentLeftInset + contentRightInset
    height: tooltipLabel.implicitHeight + contentTopInset + contentBottomInset

    Text {
      id: tooltipLabel
      text: root.tooltipText
      color: Color.tooltip.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
  }
}
