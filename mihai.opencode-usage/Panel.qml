import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The opencode usage popup: one hero for today, a seven-day chart, the
// per-model and per-agent breakdown, and an all-time footer. Everything is a
// read-out of the JSON record that BarWidget.qml's collector refreshed; this
// file owns no data extraction of its own.
Panel {
  id: root
  moduleName: "mihai.opencode-usage"
  ipcTarget: "mihai.opencode-usage"
  manageIpc: false

  property real nowMs: Date.now()
  property var anchorItem: null
  property var hostWidget: null

  readonly property var record: hostWidget ? hostWidget.record : ({})
  readonly property var today: record && record.today ? record.today : {}
  readonly property var days: record && record.days ? record.days : []
  readonly property var models: record && record.models ? record.models : []
  readonly property var agents: record && record.agents ? record.agents : []
  readonly property var totals: record && record.totals ? record.totals : {}

  readonly property bool ready: record.ready === true
  readonly property color foreground: bar ? bar.foreground : ShellColor.foreground
  readonly property color urgent: bar ? bar.urgent : ShellColor.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Util.alpha(foreground, 0.12)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property real dayPeak: {
    var peak = 1
    for (var i = 0; i < days.length; i++) peak = Math.max(peak, Number(days[i].tokens || 0))
    return peak
  }
  readonly property real modelPeak: models.length > 0 ? Math.max(1, Number(models[0].total || 0)) : 1

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function formatTokens(n) {
    n = Number(n || 0)
    if (n >= 1000000) return (n / 1000000).toFixed(2).replace(/\.?0+$/, "") + "M"
    if (n >= 10000) return (n / 1000).toFixed(0) + "K"
    if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "K"
    return String(n)
  }

  function formatMoney(n) {
    var value = Number(n || 0)
    if (value === 0) return ""
    return "$" + (value < 1 ? value.toFixed(4) : value.toFixed(2))
  }

  function todayDate() {
    var d = new Date()
    return String(d.getFullYear()) + "-" + String(d.getMonth() + 1).padStart(2, "0")
      + "-" + String(d.getDate()).padStart(2, "0")
  }

  function isToday(dateStr) { return String(dateStr || "") === todayDate() }

  function dayLabel(dateStr) {
    if (isToday(dateStr)) return "TODAY"
    var parsed = new Date(String(dateStr || "") + "T12:00:00")
    if (isNaN(parsed.getTime())) return String(dateStr || "")
    return String(Qt.formatDate(parsed, "ddd d")).toUpperCase()
  }

  function dayTooltip(day, todayFlag) {
    var parts = []
    parts.push((todayFlag ? "Today" : String(day.date)) + " · " + formatTokens(day.tokens) + " tokens")
    if (todayFlag) parts.push(Number(today.prompts || 0) + " prompts · " + Number(today.sessions || 0) + " sessions")
    return parts.join("\n")
  }

  function modelTooltip(row) {
    return String(row.name) + "\n" + String(row.provider || "opencode")
      + "\n" + formatTokens(row.input) + " in · " + formatTokens(row.output) + " out"
      + (Number(row.cacheRead) > 0 ? "\n" + formatTokens(row.cacheRead) + " cache read" : "")
      + (Number(row.cacheWrite) > 0 ? "\n" + formatTokens(row.cacheWrite) + " cache write" : "")
      + (Number(row.sessions) > 0 ? "\n" + row.sessions + " session" + (row.sessions === 1 ? "" : "s") : "")
  }

  function updatedLabel() {
    var raw = String((record && record.updatedAt) || "")
    if (!raw) return ""
    var parsed = new Date(raw)
    return isNaN(parsed.getTime()) ? "" : "updated " + Qt.formatTime(parsed, "HH:mm")
  }

  function refreshViews() {
    root.nowMs = Date.now()
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

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
      onTextKey: function(t) { if (t === "r" || t === "R") { if (hostWidget && hostWidget.refresh) hostWidget.refresh() } }

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
            visible: root.ready
            width: parent.width
            title: "opencode"
            meta: root.ready
              ? "today · " + root.formatTokens(Number(root.today.total || 0)) + " tokens · "
                + Number(root.today.sessions || 0) + " sessions"
              : "opencode usage"
            detail: root.formatMoney(root.today.cost)
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                width: Style.font.display
                height: Style.font.display
                text: "\uf1b0"
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
              text: record.error ? String(record.error) : "No opencode usage found yet."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          // ---------- Today ----------
          PanelSeparator {
            visible: root.ready
            foreground: root.foreground
          }

          Column {
            visible: root.ready
            width: parent.width
            spacing: Style.spacing.md

            PanelSectionHeader {
              width: parent.width
              text: "TODAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            StatRow {
              label: "Prompts"
              value: String(Number(root.today.prompts || 0))
              hint: "User messages"
            }

            StatRow {
              label: "Sessions"
              value: String(Number(root.today.sessions || 0))
              hint: "Active sessions"
            }

            StatRow {
              label: "Tokens"
              value: root.formatTokens(Number(root.today.total || 0))
              hint: root.formatTokens(Number(root.today.input || 0)) + " in · "
                + root.formatTokens(Number(root.today.output || 0)) + " out"
                + (Number(root.today.cacheRead) > 0 ? "\n" + root.formatTokens(Number(root.today.cacheRead)) + " cache read" : "")
            }

            StatRow {
              label: "Cost"
              value: root.formatMoney(root.today.cost) === "" ? "—" : root.formatMoney(root.today.cost)
              hint: Number(root.today.cost) > 0 ? "Estimated" : "Local / free models"
            }
          }

          // ---------- Tokens by day ----------
          PanelSeparator {
            visible: root.ready && root.days.length > 0
            foreground: root.foreground
          }

          Column {
            visible: root.ready && root.days.length > 0
            width: parent.width
            spacing: Style.spacing.md

            readonly property int dayCount: root.days.length

            PanelSectionHeader {
              width: parent.width
              text: "TOKENS BY DAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.days

              DayRow {
                required property var modelData
                required property int index

                width: parent.width
                day: modelData
                ratio: Number(modelData.tokens || 0) / root.dayPeak
                today: root.isToday(modelData.date)
                dayLabel: root.dayLabel(modelData.date)
                valueLabel: root.formatTokens(modelData.tokens)
                tooltipText: root.dayTooltip(modelData, root.isToday(modelData.date))
              }
            }
          }

          // ---------- Tokens by model ----------
          PanelSeparator {
            visible: root.ready && root.models.length > 0
            foreground: root.foreground
          }

          Column {
            visible: root.ready && root.models.length > 0
            width: parent.width
            spacing: Style.spacing.md

            PanelSectionHeader {
              width: parent.width
              text: "TOKENS BY MODEL"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.models

              ModelRow {
                required property var modelData

                width: parent.width
                row: modelData
                share: Number(modelData.total || 0) / root.modelPeak
                nameLabel: modelData.name
                valueLabel: root.formatTokens(modelData.total)
                tooltipText: root.modelTooltip(modelData)
              }
            }
          }

          // ---------- Tokens by agent ----------
          PanelSeparator {
            visible: root.ready && root.agents.length > 1
            foreground: root.foreground
          }

          Column {
            visible: root.ready && root.agents.length > 1
            width: parent.width
            spacing: Style.spacing.md

            PanelSectionHeader {
              width: parent.width
              text: "AGENT SPLIT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.agents

              ModelRow {
                required property var modelData

                width: parent.width
                row: modelData
                share: Number(modelData.total || 0) / Math.max(1, Number(root.agents[0] ? root.agents[0].total : 0))
                nameLabel: modelData.name
                valueLabel: root.formatTokens(modelData.total)
                tooltipText: modelData.name + "\n" + modelData.sessions + " session"
                  + (modelData.sessions === 1 ? "" : "s")
              }
            }
          }

          // ---------- Footer ----------
          Text {
            textFormat: Text.PlainText
            visible: root.ready && text !== ""
            width: parent.width
            topPadding: Style.space(2)
            text: root.footerText()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  function footerText() {
    if (!root.ready) return root.updatedLabel()
    var parts = []
    parts.push(root.formatTokens(Number(root.totals.tokens || 0)) + " tokens")
    if (Number(root.totals.sessions)) parts.push(Number(root.totals.sessions) + " sessions")
    if (Number(root.totals.activeDays)) parts.push(Number(root.totals.activeDays) + " days")
    var cost = root.formatMoney(root.totals.cost)
    if (cost !== "") parts.push(cost)
    var stamp = root.updatedLabel()
    if (stamp !== "") parts.push(stamp)
    return "ALL TIME · " + parts.join(" · ")
  }

  // A labeled stat with a dim hint under it.
  component StatRow: Column {
    id: statRow
    property string label: ""
    property string value: ""
    property string hint: ""

    spacing: Style.space(2)

    Item {
      width: parent.width
      implicitHeight: Math.max(name.implicitHeight, number.implicitHeight)

      Text {
        id: name
        textFormat: Text.PlainText
        text: statRow.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: number
        textFormat: Text.PlainText
        text: statRow.value
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignRight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: text !== ""
      width: parent.width
      text: statRow.hint
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  // One row per day: label, bar, tokens. Today renders at full foreground.
  component DayRow: Item {
    id: dayRow
    property var day: null
    property real ratio: 0
    property bool today: false
    property string dayLabel: ""
    property string valueLabel: ""
    property string tooltipText: ""

    implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Style.spacing.sm

    Text {
      id: dayLabel
      textFormat: Text.PlainText
      text: dayRow.dayLabel
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: dayRow.today
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(64)
    }

    Rectangle {
      id: dayTrack
      anchors.left: dayLabel.right
      anchors.right: dayValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(dayRow.ratio, 0, 1)
        color: dayRow.today ? root.foreground : root.alpha(root.foreground, 0.55)

        Behavior on width {
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      id: dayValue
      textFormat: Text.PlainText
      text: dayRow.valueLabel
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(56)
    }

    MouseArea {
      id: dayHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: dayHover.containsMouse && dayRow.tooltipText !== ""
      text: dayRow.tooltipText
      fontFamily: root.fontFamily
    }
  }

  // Model / agent rows: a share bar fills the row behind the label.
  component ModelRow: Item {
    id: modelRow
    property var row: null
    property real share: 0
    property string nameLabel: ""
    property string valueLabel: ""
    property string tooltipText: ""

    implicitHeight: modelName.implicitHeight + Style.spacing.lg

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.05)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * root.clamp(modelRow.share, 0, 1)
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.14)

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

    Text {
      id: modelName
      textFormat: Text.PlainText
      text: modelRow.nameLabel
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: modelTokens.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: modelTokens
      textFormat: Text.PlainText
      text: modelRow.valueLabel
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
      id: modelHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: modelHover.containsMouse && modelRow.tooltipText !== ""
      text: modelRow.tooltipText
      fontFamily: root.fontFamily
    }
  }
}