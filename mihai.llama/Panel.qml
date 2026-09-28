import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The local llama popup: the three local models with their live state and a
// Load / Unload action per row. State is a direct read-out of the JSON record
// that BarWidget.qml's status process keeps fresh; actions hand off to
// hostWidget.doAction, which runs llama_ctl.py without blocking this panel.
Panel {
  id: root
  moduleName: "mihai.llama"
  ipcTarget: "mihai.llama"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var record: hostWidget ? hostWidget.record : ({})
  readonly property var models: record && record.models ? record.models : []
  readonly property bool ready: record.ready === true
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int loadedCount: root.models.filter(function(m) { return m.state === "loaded" }).length
  readonly property int startingCount: root.models.filter(function(m) { return m.state === "starting" }).length

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function gpuFree(unit) {
    var g = record.gpu || {}
    var free = Number(g.total_mb || 0) - Number(g.used_mb || 0)
    return unit === "gb" ? (free / 1024).toFixed(1) : String(free)
  }

  function stateLabel(m) {
    if (m.state === "loaded") return "loaded"
    if (m.state === "starting") return "loading…"
    return "idle"
  }

  function refreshViews() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
  }

  function open() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
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
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                           Math.max(0, panelFlick.contentHeight - panelFlick.height))
      }
      onActivateRequested: root.refreshViews()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refreshViews() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ---------- Hero ----------
          PanelHero {
            id: hero
            width: parent.width
            title: "local llama"
            meta: root.ready
              ? root.loadedCount + " loaded · " + root.gpuFree("gb") + " GB VRAM free"
              : "local llama"
            detail: root.ready ? "" : "checking…"
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                width: Style.font.display
                height: Style.font.display
                text: "\uf233"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          // ---------- Unavailable ----------
          Column {
            visible: !root.ready
            width: parent.width
            topPadding: Style.space(12)
            spacing: Style.spacing.md

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: "Status not available yet."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          // ---------- Model list ----------
          PanelSeparator {
            visible: root.ready
            foreground: root.foreground
          }

          Column {
            visible: root.ready
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              text: "MODELS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.models

              ModelRow {
                required property var modelData
                required property int index

                width: parent.width
                m: modelData
                foreground: root.foreground
                urgent: root.urgent
                dim: root.dim
                fontFamily: root.fontFamily
                onLoadRequested: { if (hostWidget) hostWidget.doAction("load", modelData.id) }
                onUnloadRequested: { if (hostWidget) hostWidget.doAction("unload", modelData.id) }
              }
            }

            Text {
              textFormat: Text.PlainText
              visible: root.startingCount > 0 && root.loadedCount === 0
              width: parent.width
              topPadding: Style.space(2)
              text: "Loading into memory — a few seconds for the 4B, up to a minute for the 30B."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ---------- Footer ----------
          Text {
            textFormat: Text.PlainText
            width: parent.width
            topPadding: Style.space(2)
            text: "Nothing is resident until you click Load. Unload frees the memory. Then pick the model in opencode's /models."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // One row per local model: name + meta on the left, state and action on the
  // right. Load when idle, Unload when loaded, nothing clickable while loading.
  component ModelRow: Item {
    id: modelRow
    property var m: null
    property color foreground: Color.foreground
    property color urgent: Color.urgent
    property color dim: Qt.darker(foreground, 1.55)
    property string fontFamily: Style.font.family
    signal loadRequested()
    signal unloadRequested()

    implicitHeight: Math.max(modelName.implicitHeight + modelMeta.implicitHeight + Style.space(8), Style.space(52))

    Rectangle {
      id: rowBg
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.06)
    }

    Column {
      anchors.left: parent.left
      anchors.right: rightCol.left
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        id: modelName
        textFormat: Text.PlainText
        width: parent.width
        text: modelRow.m ? String(modelRow.m.name) : ""
        color: modelRow.m && modelRow.m.state === "loaded" ? modelRow.foreground : modelRow.dim
        font.family: modelRow.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: modelRow.m && modelRow.m.state === "loaded"
        elide: Text.ElideRight
      }

      Text {
        id: modelMeta
        textFormat: Text.PlainText
        width: parent.width
        text: modelRow.m
          ? String(modelRow.m.size) + " · :" + String(modelRow.m.port) + " · " + String(modelRow.m.opencode)
          : ""
        color: modelRow.dim
        font.family: modelRow.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Column {
      id: rightCol
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      Text {
        id: stateLabel
        textFormat: Text.PlainText
        text: modelRow.m ? root.stateLabel(modelRow.m) : ""
        color: modelRow.m && modelRow.m.state === "loaded"
          ? modelRow.foreground
          : (modelRow.m && modelRow.m.state === "starting" ? modelRow.urgent : modelRow.dim)
        font.family: modelRow.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: modelRow.m && modelRow.m.state !== "idle"
        horizontalAlignment: Text.AlignRight
        width: actionButton.width
      }

      ActionButton {
        id: actionButton
        width: Style.space(64)
        labelText: modelRow.m && modelRow.m.state === "loaded" ? "Unload" : "Load"
        enabledFlag: modelRow.m && modelRow.m.state !== "starting"
        fill: modelRow.m && modelRow.m.state === "loaded"
          ? root.alpha(modelRow.urgent, 0.28)
          : root.alpha(modelRow.foreground, 0.15)
        foreground: modelRow.foreground
        dim: modelRow.dim
        fontFamily: modelRow.fontFamily
        onClicked: modelRow.m && modelRow.m.state === "loaded" ? modelRow.unloadRequested() : modelRow.loadRequested()
      }
    }
  }

  component ActionButton: Rectangle {
    id: btn
    property string labelText: ""
    property bool enabledFlag: true
    property color fill: Color.foreground
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.55)
    property string fontFamily: Style.font.family
    signal clicked

    implicitHeight: Style.spacing.controlHeight
    radius: Style.cornerRadius
    color: enabledFlag ? (hover.hovered ? lighter(fill, 1.15) : fill) : dim

    function lighter(c, f) {
      return Qt.rgba(Math.min(1, c.r * f), Math.min(1, c.g * f), Math.min(1, c.b * f), c.a)
    }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: btn.labelText
      color: btn.enabledFlag ? btn.foreground : btn.dim
      font.family: btn.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: hover
      anchors.fill: parent
      hoverEnabled: true
      enabled: btn.enabledFlag
      onClicked: btn.clicked()
    }
  }
}