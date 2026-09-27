import QtQuick
import QtQuick.Controls
import qs.Commons
import "../model"
import "../model/Schema.js" as Schema
import "."

Item {
  id: root
  property string query: ""

  readonly property var results: Schema.matchingSettings(query)

  function showHeader(i) {
    if (i === 0) return true
    var prev = results[i - 1]
    var cur = results[i]
    return prev.page !== cur.page || prev.group !== cur.group
  }

  function headerText(s) {
    var p = Schema.pageById(s.page)
    var parts = []
    if (p) parts.push(p.label)
    if (s.group) parts.push(s.group)
    return parts.join(" · ").toUpperCase()
  }

  Text {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.topMargin: 4
    visible: root.results.length === 0
    text: "No settings match \"" + root.query + "\""
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    color: Color.muted
  }

  Flickable {
    anchors.fill: parent
    visible: root.results.length > 0
    contentWidth: width
    contentHeight: col.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: col
      width: parent.width
      spacing: 2

      Repeater {
        model: root.results
        delegate: Column {
          id: resultCol
          required property var modelData
          required property int index
          width: col.width
          spacing: 2

          Text {
            text: root.headerText(resultCol.modelData)
            visible: root.showHeader(index)
            topPadding: index === 0 ? 0 : 14
            bottomPadding: 4
            leftPadding: 2
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
            color: Color.muted
          }

          SettingRow {
            width: resultCol.width
            setting: resultCol.modelData
            onChanged: function (v) { SettingsStore.set(resultCol.modelData.id, v) }
          }
        }
      }
    }
  }
}
