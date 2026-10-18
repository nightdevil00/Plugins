import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.Commons as Commons

// The local llama popup: every verified preset, split into what is already on
// disk (Load / Unload) and what still needs fetching (Download), with a badge
// for how much of each model lands in VRAM. State is a direct read-out of the
// JSON record that BarWidget.qml's status process keeps fresh; actions hand off
// to hostWidget.doAction, which runs llama_ctl.py without blocking this panel.
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
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int loadedCount: root.models.filter(function(m) { return m.state === "loaded" }).length
  readonly property int startingCount: root.models.filter(function(m) { return m.state === "starting" }).length
  readonly property int idleSleepSec: (hostWidget && hostWidget.idleSleepSec !== undefined)
    ? hostWidget.idleSleepSec : 0

  // Present models keep their preset order first, missing ones follow, so the
  // eye lands on what you can actually run.
  readonly property var presentModels: root.models.filter(function(m) { return m.present === true })
  readonly property var missingModels: root.models.filter(function(m) { return m.present !== true })

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function gb(mb) { return (Number(mb || 0) / 1024).toFixed(1) }

  function vramFreeMb() {
    var g = record.gpu || {}
    return Number(g.total_mb || 0) - Number(g.used_mb || 0)
  }

  function ramFreeMb() {
    var r = record.ram || {}
    return Number(r.available_mb || 0)
  }

  function fmtBytes(n) {
    var b = Number(n || 0)
    if (b <= 0) return ""
    var gbs = b / 1073741824
    if (gbs >= 1) return gbs.toFixed(1) + " GB"
    return Math.round(b / 1048576) + " MB"
  }

  function gpuLabel(g) {
    if (g === "vram") return "VRAM"
    if (g === "partial") return "partial"
    if (g === "cpu") return "CPU"
    return "?"
  }

  function gpuColor(g) {
    if (g === "vram") return root.foreground
    if (g === "partial") return root.urgent
    return root.dim
  }

  function stateLabel(m) {
    if (!m) return ""
    if (m.state === "loaded") return "loaded"
    if (m.state === "starting") return "loading…"
    if (m.downloading) return "downloading…"
    return "idle"
  }

  function metaText(m) {
    if (!m) return ""
    var size = m.present ? (root.fmtBytes(m.bytes) || m.size) : (m.size + " to download")
    return size + " · :" + m.port + " · " + m.opencode
  }

  function dlPercent(m) {
    if (!m || !m.downloading) return -1
    var total = Number(m.totalBytes || 0)
    if (total <= 0) return -1
    return root.clamp(Math.round(Number(m.downloadedBytes || 0) * 100 / total), 0, 100)
  }

  function progressText(m) {
    var done = root.fmtBytes(m.downloadedBytes) || "0 MB"
    var total = m.totalBytes ? root.fmtBytes(m.totalBytes) : m.size
    var pct = root.dlPercent(m)
    return done + " / " + total + (pct >= 0 ? " · " + pct + "%" : "")
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

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
              ? root.loadedCount + " loaded · " + root.gb(root.vramFreeMb()) + " GB VRAM · "
                + root.gb(root.ramFreeMb()) + " GB RAM"
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

          // ---------- Ready models (on disk) ----------
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
              text: "READY · " + root.presentModels.length
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.presentModels

              ModelRow {
                required property var modelData

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
              visible: root.presentModels.length === 0
              width: parent.width
              text: "No models on disk yet — download one below."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
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

            Text {
              textFormat: Text.PlainText
              visible: root.loadedCount > 0 && root.idleSleepSec > 0
              width: parent.width
              topPadding: Style.space(2)
              text: "Auto-sleep on: this model frees its memory after " + root.idleSleepSec
                + "s idle and wakes on the next request."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ---------- Missing models (need a download) ----------
          Column {
            visible: root.ready && root.missingModels.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              width: parent.width
              text: "NOT DOWNLOADED · " + root.missingModels.length
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.missingModels

              ModelRow {
                required property var modelData

                width: parent.width
                m: modelData
                foreground: root.foreground
                urgent: root.urgent
                dim: root.dim
                fontFamily: root.fontFamily
                onDownloadRequested: { if (hostWidget) hostWidget.doAction("download", modelData.id) }
                onCancelRequested: { if (hostWidget) hostWidget.doAction("cancel", modelData.id) }
              }
            }
          }

          // ---------- Footer ----------
          Text {
            textFormat: Text.PlainText
            width: parent.width
            topPadding: Style.space(2)
            text: root.idleSleepSec > 0
              ? "Nothing is resident until you click Load; Unload or the idle timer frees the memory. Then pick the model in opencode's /models."
              : "Nothing is resident until you click Load. Unload frees the memory. Then pick the model in opencode's /models."
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

  // One row per model: name, fit badge and file detail on the left; state and a
  // single context action on the right — Load/Unload when the GGUF is on disk,
  // Download/Cancel while it is not.
  component ModelRow: Item {
    id: modelRow
    property var m: null
    property color foreground: Commons.Color.foreground
    property color urgent: Commons.Color.urgent
    property color dim: Qt.darker(foreground, 1.55)
    property string fontFamily: Style.font.family
    signal loadRequested()
    signal unloadRequested()
    signal downloadRequested()
    signal cancelRequested()

    readonly property bool present: m && m.present === true
    readonly property bool downloading: m && m.downloading === true
    readonly property bool starting: m && m.state === "starting"
    readonly property bool loaded: m && m.state === "loaded"

    implicitHeight: Math.max(leftCol.implicitHeight + Style.space(8), Style.space(52))

    Rectangle {
      id: rowBg
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, modelRow.loaded ? 0.10 : 0.06)
    }

    Column {
      id: leftCol
      anchors.left: parent.left
      anchors.right: rightCol.left
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Row {
        width: parent.width
        spacing: Style.space(6)

        Text {
          id: modelName
          textFormat: Text.PlainText
          width: Math.min(implicitWidth,
                         parent.width - (badge.visible ? badge.width : 0) - Style.space(6))
          text: modelRow.m ? String(modelRow.m.name) : ""
          color: modelRow.loaded ? modelRow.foreground
            : (modelRow.present ? modelRow.dim : root.alpha(modelRow.dim, 0.75))
          font.family: modelRow.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: modelRow.loaded
          elide: Text.ElideRight
        }

        Rectangle {
          id: badge
          visible: modelRow.m && modelRow.present
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: badgeText.implicitWidth + Style.space(8)
          implicitHeight: badgeText.implicitHeight + Style.space(2)
          radius: Style.cornerRadius
          color: root.alpha(root.gpuColor(modelRow.m ? modelRow.m.gpu : ""), 0.16)

          Text {
            id: badgeText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: root.gpuLabel(modelRow.m ? modelRow.m.gpu : "")
            color: root.gpuColor(modelRow.m ? modelRow.m.gpu : "")
            font.family: modelRow.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        id: modelMeta
        textFormat: Text.PlainText
        width: parent.width
        text: modelRow.m ? root.metaText(modelRow.m) : ""
        color: modelRow.dim
        font.family: modelRow.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        id: progressLine
        textFormat: Text.PlainText
        visible: modelRow.downloading
        width: parent.width
        text: modelRow.downloading ? root.progressText(modelRow.m) : ""
        color: modelRow.urgent
        font.family: modelRow.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        id: noSourceLine
        textFormat: Text.PlainText
        visible: modelRow.m && !modelRow.present && !modelRow.downloading
          && modelRow.m.hasSource !== true
        width: parent.width
        text: "no download source — fetch it in ~/models (see README)"
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
        color: modelRow.loaded ? modelRow.foreground
          : (modelRow.starting || modelRow.downloading ? modelRow.urgent : modelRow.dim)
        font.family: modelRow.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: modelRow.loaded || modelRow.starting || modelRow.downloading
        horizontalAlignment: Text.AlignRight
        width: actionButton.width
      }

      ActionButton {
        id: actionButton
        visible: actionVisible()
        width: Style.space(74)
        labelText: actionLabel()
        enabledFlag: modelRow.m && !modelRow.starting
        fill: (modelRow.loaded || modelRow.downloading)
          ? root.alpha(modelRow.urgent, 0.28)
          : root.alpha(modelRow.foreground, 0.15)
        foreground: modelRow.foreground
        dim: modelRow.dim
        fontFamily: modelRow.fontFamily
        onClicked: {
          if (!modelRow.m) return
          if (modelRow.downloading) modelRow.cancelRequested()
          else if (modelRow.present && modelRow.loaded) modelRow.unloadRequested()
          else if (modelRow.present) modelRow.loadRequested()
          else if (modelRow.m.hasSource === true) modelRow.downloadRequested()
        }

        function actionVisible() {
          if (!modelRow.m) return false
          if (modelRow.present || modelRow.downloading) return true
          return modelRow.m.hasSource === true
        }

        function actionLabel() {
          if (modelRow.downloading) return "Cancel"
          if (modelRow.present) return modelRow.loaded ? "Unload" : "Load"
          return "Download"
        }
      }
    }
  }

  component ActionButton: Rectangle {
    id: btn
    property string labelText: ""
    property bool enabledFlag: true
    property color fill: Commons.Color.foreground
    property color foreground: Commons.Color.foreground
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
