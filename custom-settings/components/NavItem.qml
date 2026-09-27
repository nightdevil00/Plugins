import QtQuick
import qs.Commons

// One entry in the left rail. Selected uses a soft accent wash; hover uses a
// faint foreground wash. Focus is an accent ring, never confused with hover.
Item {
  id: root
  property string icon: ""
  property string label: ""
  property bool selected: false
  property bool hasCursor: false
  signal activated()

  implicitHeight: 40
  activeFocusOnTab: true

  readonly property bool hot: hasCursor || mouse.containsMouse
  readonly property int _radius: Style.cornerRadius > 0 ? Math.round(Style.cornerRadius * 0.5) : 4

  Rectangle {
    anchors.fill: parent
    radius: root._radius
    color: root.selected
      ? Util.alpha(Color.accent, 0.16)
      : (root.hot ? Util.alpha(Color.foreground, 0.06) : "transparent")
    border.width: root.activeFocus ? 1 : 0
    border.color: Util.alpha(Color.accent, 0.9)
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      Text {
        text: root.icon
        anchors.verticalCenter: parent.verticalCenter
        font.family: Style.font.family
        font.pixelSize: Style.font.icon
        color: root.selected ? Color.accent : (root.hot ? Color.foreground : Color.muted)
      }
      Text {
        text: root.label
        anchors.verticalCenter: parent.verticalCenter
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.weight: root.selected ? Font.DemiBold : Font.Normal
        color: root.selected ? Color.foreground : (root.hot ? Color.foreground : Color.muted)
        elide: Text.ElideRight
        width: parent.width - parent.spacing - 24
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.forceActiveFocus()
      root.activated()
    }
  }

  Keys.onReturnPressed: root.activated()
  Keys.onEnterPressed: root.activated()
  Keys.onSpacePressed: root.activated()
  Keys.onRightPressed: root.activated()
}
