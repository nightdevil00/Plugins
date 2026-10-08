import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "mihai.renderer"
  ipcTarget: "mihai.renderer"

  // The plugin registry loads this file from ~/.config/omarchy/plugins/, so
  // the entry point's own URL is the one reliable way to reach the script.
  // Nothing else about the layout is assumed.
  readonly property string script: root.filePath(Qt.resolvedUrl("lib/mihai-renderer.sh"))

  function filePath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") !== 0) return value
    var path = value.substring("file://".length)
    try { return decodeURIComponent(path) } catch (e) { return path }
  }

  // One `json` call feeds the whole panel: the script reads sysfs, the saved
  // order file and the Hyprland log. None of that is re-derived in QML.
  property var info: ({
    multi: false,
    hybrid: false,
    internal: -1,
    auto: true,
    order: [],
    default: [],
    running: [],
    runningExplicit: false,
    hook: "missing",
    rules: "missing",
    duplicates: [],
    stray: [],
    gpus: []
  })

  property bool busy: false
  property string error: ""

  // House aliases, matching the first-party panels. `barForeground` is the
  // animated, transparency-aware color; `bar.foreground` is the static theme
  // color, so reading that one here left the hero at full brightness while the
  // rest of the panel dimmed with the bar.
  readonly property color foreground: root.barForeground
  readonly property color dim: Qt.darker(root.foreground, 1.55)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // Every list the panel renders is derived here, on the root, from the raw
  // `info` object — never inside a delegate. Model.choices() and friends expect
  // the plain arrays that JSON.parse produced; a Repeater hands its delegate a
  // wrapped copy instead, and a wrapped array fails Array.isArray, so any array
  // touched from a delegate silently reads as empty. Deriving everything up
  // front keeps that trap out of reach and leaves the delegates doing nothing
  // but drawing strings.
  readonly property var choiceList: Model.choices(info)
  readonly property string selectedId: Model.selectedChoiceId(info)
  readonly property bool needsLogin: Model.pending(info)
  readonly property var active: Model.activeGpu(info)
  readonly property var warningList: Model.warnings(info)

  // Actions sit under the pick list, and only the ones that make sense right
  // now are there at all.
  readonly property var actionList: {
    var out = []
    if (needsLogin) out.push({ id: "logout", text: "Log out and back in", hint: "Applies the saved renderer" })
    if (info.multi) {
      if (info.rules === "ok") out.push({ id: "links-remove", text: "Remove stable GPU names", hint: "No longer needed" })
      else out.push({ id: "links-install", text: "Install stable GPU names", hint: "Asks for your password" })
    }
    return out
  }

  // Flat cursor model: choices first, then actions, in one vertical list. The
  // keyboard and the mouse both write selectedIndex, so there is only ever one
  // highlight.
  readonly property var rows: {
    var out = []
    for (var i = 0; i < choiceList.length; i++) out.push({ section: "choices", index: i })
    for (var a = 0; a < actionList.length; a++) out.push({ section: "actions", index: a })
    return out
  }
  property int selectedIndex: 0
  property bool cursorActive: false

  // The bar button is a single glyph, so everything it has to say goes in the
  // tooltip: which GPU is drawing, and whether a saved choice is still
  // waiting for a login.
  readonly property string barTip: {
    if (!root.active) return "Renderer: unknown"
    var tip = "Renderer: " + Model.title(root.active)
    return root.needsLogin ? tip + " — a saved change applies at the next login" : tip
  }

  function clampCursor() {
    if (rows.length === 0) { selectedIndex = 0; return }
    if (selectedIndex >= rows.length) selectedIndex = rows.length - 1
    if (selectedIndex < 0) selectedIndex = 0
  }

  function moveCursor(delta) {
    if (rows.length === 0) return
    if (delta > 0) {
      if (selectedIndex < rows.length - 1) selectedIndex++
    } else if (selectedIndex > 0) {
      selectedIndex--
    }
    cursorActive = true
  }

  function rowSelected(section, index) {
    var row = rows[selectedIndex]
    return cursorActive && row !== undefined && row.section === section && row.index === index
  }

  // Hover moves the highlight rather than jumping the cursor, so the keyboard
  // does not teleport on the next key press.
  function hoverRow(absoluteIndex) {
    cursorActive = true
    selectedIndex = absoluteIndex
  }

  function activateCursor() {
    if (busy) return
    cursorActive = true
    var row = rows[selectedIndex]
    if (row === undefined) return
    if (row.section === "choices") { applyChoice(row.index); return }
    var action = actionList[row.index]
    if (action) runAction(action.id)
  }

  // Takes an index into choiceList rather than the choice object, so the PCI
  // addresses that end up on the command line are read from the raw list. The
  // order decides what the Hyprland hook does to the DRM backends, so it is not
  // worth the chance of handing a wrapped array to the script.
  function applyChoice(choiceIndex) {
    var choice = choiceList[choiceIndex]
    if (!choice || choice.id === selectedId) return
    var order = Model.pciList(choice.order)
    busy = true
    error = ""
    changeProc.command = choice.kind === "auto"
      ? [script, "auto"]
      : [script, "order"].concat(order)
    changeProc.running = true
  }

  function runAction(id) {
    if (id === "logout") {
      // No arguments: omarchy-system-logout already shows its own OSD and
      // closes the windows before stopping the session.
      Util.execDetached("omarchy logout")
      return
    }
    if (id !== "links-install" && id !== "links-remove") return
    busy = true
    error = ""
    linksProc.command = [script, id]
    linksProc.running = true
  }

  function refresh() {
    stateProc.running = true
  }

  function applyState(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (parsed && typeof parsed === "object" && Array.isArray(parsed.gpus)) info = parsed
    } catch (e) {
      // Keep what is already on screen rather than blanking the panel.
    }
    clampCursor()
  }

  function showError(message) {
    var value = String(message || "").replace(/^\s+|\s+$/g, "")
    // The script prefixes its own diagnostics; the panel just relays them.
    error = value.replace(/^mihai-renderer:\s*/, "")
  }

  onOpenedChanged: if (opened) refresh()
  onNeedsLoginChanged: clampCursor()
  onChoiceListChanged: clampCursor()
  Component.onCompleted: refresh()

  // ------------------------------------------------------- bar button

  // Icon only: the bar slot is narrow, and the name of the GPU that is
  // rendering right now is what the panel and the tooltip are for. It turns
  // the warning colour while a saved choice still needs a new login.
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰚚"
    active: root.needsLogin
    useActiveColor: true
    tooltipText: root.barTip
    onPressed: function(b) { if (b !== Qt.RightButton) root.toggle() }
  }

  // The bar sizes a panel slot from its root item's implicit size. Panel is a
  // plain Item and reports 0 for both, so a panel that forgets these two lines
  // is silently given no width at all — the button then exists and works, but
  // there is nothing on screen to click. Same as every first-party panel.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ----------------------------------------------------------- the panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }
    }

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.spacing.panelGap

      // ---------- Hero: which GPU renders right now ----------
      PanelHero {
        id: hero
        width: parent.width
        title: root.active ? Model.title(root.active) : "Unknown renderer"
        meta: {
          var gpus = Model.pickableGpus(root.info)
          if (gpus.length === 0) return "no display controller found"
          if (gpus.length === 1) return "one graphics card — nothing to switch"
          return gpus.length + " graphics cards" + (root.info.hybrid ? " · hybrid laptop" : "")
        }
        detail: root.needsLogin ? "next login" : ""
        foreground: root.foreground
        fontFamily: root.fontFamily

        iconComponent: Component {
          Text {
            width: Style.font.display
            height: Style.font.display
            text: "\uf069a"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      // ---------- Pick list ----------
      Column {
        width: parent.width
        spacing: Style.spacing.xs

        PanelSectionHeader {
          width: parent.width
          text: "Renderer"
        }

        Repeater {
          model: root.choiceList

          delegate: ChoiceRow {
            required property var modelData
            required property int index
            title: modelData.title
            detail: modelData.detail
            current: modelData.id === root.selectedId
            rowSelected: root.rowSelected("choices", index)
            onHovered: root.hoverRow(index)
            onClicked: root.applyChoice(index)
          }
        }

        Text {
          width: parent.width
          visible: root.choiceList.length > 1
          textFormat: Text.PlainText
          text: root.needsLogin
            ? "Saved. Log out and back in to switch over."
            : "Picking the other GPU keeps this one in use for the screens plugged into it."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }

      // ---------- Problems worth saying out loud ----------
      Column {
        width: parent.width
        spacing: Style.spacing.sm
        visible: root.error !== "" || root.warningList.length > 0

        Repeater {
          model: {
            var notes = []
            if (root.error !== "") notes.push({ text: root.error, action: "" })
            for (var i = 0; i < root.warningList.length; i++) notes.push(root.warningList[i])
            return notes
          }

          delegate: NoteRow {
            required property var modelData
            text: modelData.text
            actionText: modelData.action === "links-install"
              ? "Install"
              : (modelData.action === "links-remove" ? "Remove" : "")
            onActionClicked: if (modelData.action) root.runAction(modelData.action)
          }
        }
      }

      // ---------- Actions ----------
      Column {
        width: parent.width
        spacing: Style.spacing.sm
        visible: root.actionList.length > 0

        Repeater {
          model: root.actionList

          delegate: ActionRow {
            required property var modelData
            required property int index
            text: modelData.text
            hint: modelData.hint
            rowSelected: root.rowSelected("actions", index)
            onHovered: root.hoverRow(root.choiceList.length + index)
            onActivated: root.runAction(modelData.id)
          }
        }
      }

      // ---------- What each card is ----------
      Column {
        width: parent.width
        spacing: Style.spacing.lg
        visible: Model.pickableGpus(root.info).length > 0

        Repeater {
          model: Model.pickableGpus(root.info)

          delegate: Column {
            required property var modelData
            width: parent.width
            spacing: Style.spacing.xxs

            PanelSectionHeader {
              width: parent.width
              // `title` is a helper in Model.js, not a field on the card, so
              // it has to be called rather than read. It only touches `name` and
              // `brand`, which survive being handed over as plain strings.
              text: Model.title(modelData)
            }

            // modelData here is the card the Repeater handed over, not the object
            // the JSON parser built, so the detail rows come out of a helper
            // that reads wrapped lists as well as raw ones. Reading `outputs`
            // with Array.isArray from in here silently found nothing on every
            // card, which is what reported a plugged-in monitor as absent.
            Repeater {
              model: Model.gpuDetails(modelData)
              delegate: DetailRow {
                required property var modelData
                label: modelData.label
                value: modelData.value
              }
            }
          }
        }
      }

      // ---------- Footer ----------
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.busy ? "Working…" : "r re-check · esc close"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ------------------------------------------------------------- components

  component ChoiceRow: CursorSurface {
    id: choiceRow
    required property string title
    required property string detail
    required property bool current
    required property bool rowSelected

    signal hovered()
    signal clicked()

    hasCursor: rowSelected
    foreground: root.foreground
    accent: ShellColor.accent
    // BorderSurface reports no implicitWidth and a Column does not stretch its
    // children, so without this the row is zero-width and nothing in it — glyph,
    // title, or the MouseArea — is on screen to click.
    width: parent ? parent.width : 0
    implicitHeight: Math.max(marker.implicitHeight, labels.implicitHeight) + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) choiceRow.hovered()
      onClicked: choiceRow.clicked()
    }

    Text {
      id: marker
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: choiceRow.current ? "󰄬" : "󰄰"
      color: choiceRow.current ? choiceRow.accent : Qt.darker(choiceRow.foreground, 1.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Column {
      id: labels
      anchors.left: marker.right
      anchors.leftMargin: Style.spacing.labelGap * 2
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.rowPaddingX
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: choiceRow.title
        color: choiceRow.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: choiceRow.detail !== ""
        textFormat: Text.PlainText
        text: choiceRow.detail
        color: Qt.darker(choiceRow.foreground, 1.45)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    required property string text
    required property string hint
    required property bool rowSelected

    signal hovered()
    signal activated()

    hasCursor: rowSelected
    foreground: root.foreground
    accent: ShellColor.accent
    width: parent ? parent.width : 0
    implicitHeight: Math.max(label.implicitHeight, hintLabel.implicitHeight) + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) actionRow.hovered()
      onClicked: actionRow.activated()
    }

    Text {
      id: label
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.right: hintLabel.left
      anchors.rightMargin: Style.spacing.labelGap * 2
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: actionRow.text
      color: actionRow.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      id: hintLabel
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.rowPaddingX
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: actionRow.hint
      color: Qt.darker(actionRow.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component NoteRow: Item {
    id: noteRow
    required property string text
    property string actionText: ""

    signal actionClicked()

    width: parent ? parent.width : 0
    implicitHeight: Math.max(textLabel.implicitHeight, actionButton.implicitHeight)

    Text {
      id: textLabel
      anchors.left: parent.left
      anchors.right: actionButton.visible ? actionButton.left : parent.right
      anchors.rightMargin: actionButton.visible ? Style.spacing.labelGap * 2 : 0
      textFormat: Text.PlainText
      text: noteRow.text
      color: Qt.darker(root.foreground, 1.25)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Button {
      id: actionButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: noteRow.actionText !== ""
      text: noteRow.actionText
      foreground: root.foreground
      accent: ShellColor.accent
      fontFamily: root.fontFamily
      onClicked: noteRow.actionClicked()
    }
  }

  component DetailRow: Item {
    id: detailRow
    required property string label
    required property string value

    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    // The label takes a fixed share of the row and the value fills the rest.
    // Anchoring labelText.right to valueText.left while valueText.left was
    // anchored back to labelText.right made each one depend on the other, and
    // the two drew on top of each other.
    readonly property real labelWidth: Math.min(labelText.implicitWidth, Math.max(0, detailRow.width * 0.4))

    Text {
      id: labelText
      anchors.left: parent.left
      width: detailRow.labelWidth
      textFormat: Text.PlainText
      text: detailRow.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Text {
      id: valueText
      anchors.left: labelText.right
      anchors.leftMargin: Style.spacing.labelGap * 2
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: detailRow.value
      color: Qt.darker(root.foreground, 1.15)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideMiddle
    }
  }

  // --------------------------------------------------------------- plumbing

  Process {
    id: stateProc
    command: [root.script, "json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.busy = false; root.applyState(text) }
    }
  }

  // Writing the order file. A failed write leaves the file untouched, so the
  // next json call is the truth; stderr is only shown when there is some.
  Process {
    id: changeProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      root.busy = false
      root.showError(changeProc.stderr.text)
      root.refresh()
    }
  }

  // Installing or removing the udev rules needs a password, which Omarchy's
  // polkit agent puts in front of the user.
  Process {
    id: linksProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      root.busy = false
      root.showError(linksProc.stderr.text)
      root.refresh()
    }
  }

  // A GPU can come and go under a running session (a hotplugged eGPU, a lid
  // switch), so keep reading while the panel is open. One sysfs walk plus a
  // tail of the Hyprland log, every five seconds.
  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: if (!root.busy) root.refresh()
  }
}
