import QtQuick
import qs.Commons

Item {
  id: root
  property bool checked: false
  signal toggled()

  implicitWidth: 48
  implicitHeight: 28
  activeFocusOnTab: true

  readonly property bool hot: mouse.containsMouse

  Rectangle {
    id: track
    anchors.fill: parent
    radius: Style.cornerRadius > 0 ? height / 2 : 4
    color: root.checked ? Util.alpha(Color.accent, 0.9) : Util.alpha(Color.foreground, 0.12)
    border.width: 1
    border.color: root.activeFocus
      ? Util.alpha(Color.accent, 1.0)
      : (root.hot ? Util.alpha(Color.foreground, 0.30) : Util.alpha(Color.foreground, 0.14))
    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
      width: height
      height: parent.height - 8
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? parent.width - width - 4 : 4
      radius: Style.cornerRadius > 0 ? height / 2 : 3
      color: root.checked ? Color.background : Color.foreground
      Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 120 } }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.forceActiveFocus()
      root.toggled()
    }
  }

  Keys.onSpacePressed: root.toggled()
  Keys.onReturnPressed: root.toggled()
  Keys.onEnterPressed: root.toggled()
  Keys.onLeftPressed: if (root.checked) root.toggled()
  Keys.onRightPressed: if (!root.checked) root.toggled()
}
