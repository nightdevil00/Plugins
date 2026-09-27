import QtQuick
import QtQuick.Controls
import qs.Commons
import "../model"
import "../model/Schema.js" as Schema
import "."

// Renders any schema page: groups in order, rows within each group, controls
// chosen from the setting type. One component covers Appearance, Window,
// Motion, and Input.
Item {
  id: root

  property string pageId: ""
  property bool embedded: false

  readonly property var groups: Schema.groupsForPage(pageId)

  readonly property real contentHeight: embedded
      ? embeddedContent.implicitHeight
      : (flick ? flick.contentHeight : 0)

  implicitHeight: contentHeight

  // Embedded mode: Column directly in root, parent handles scrolling
  Column {
    id: embeddedContent
    width: parent.width
    spacing: 26
    bottomPadding: 24
    visible: embedded

    Repeater {
      model: root.groups
      delegate: Column {
        required property var modelData
        width: embeddedContent.width
        spacing: 2

        Text {
          text: modelData.name.length > 0 ? modelData.name.toUpperCase() : ""
          visible: text.length > 0
          leftPadding: 2
          bottomPadding: 6
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1.2
          color: Color.muted
        }

        Repeater {
          model: modelData.items
          delegate: SettingRow {
            required property var modelData
            width: parent.width
            setting: modelData
            onChanged: function (v) { SettingsStore.set(modelData.id, v) }
          }
        }
      }
    }
  }

  // Standalone mode: Flickable fills parent, content scrolls inside
  Flickable {
    id: flick
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    visible: !embedded

    Column {
      id: col
      width: flick.width
      spacing: 26
      bottomPadding: 24

      Repeater {
        model: root.groups
        delegate: Column {
          required property var modelData
          width: col.width
          spacing: 2

          Text {
            text: modelData.name.length > 0 ? modelData.name.toUpperCase() : ""
            visible: text.length > 0
            leftPadding: 2
            bottomPadding: 6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
            color: Color.muted
          }

          Repeater {
            model: modelData.items
            delegate: SettingRow {
              required property var modelData
              width: parent.width
              setting: modelData
              onChanged: function (v) { SettingsStore.set(modelData.id, v) }
            }
          }
        }
      }
    }
  }
}
