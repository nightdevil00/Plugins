import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import qs.Commons as Commons

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property int selectedIndex: 0
  property var windows: []

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property color selectedBackground: Commons.Color.menu.selectedBackground
  readonly property color selectedText: Commons.Color.menu.selectedText
  property color scrim: Commons.Color.menu.scrim
  property string fontFamily: Style.font.menuFamily

  readonly property int cardWidth: Style.space(220)
  readonly property int cardHeight: Style.space(290)
  readonly property int titleHeight: Style.space(40)
  readonly property int cardPadding: Style.space(8)
  readonly property int lift: Style.space(40)
  readonly property int fanRadius: Style.space(900)
  readonly property int bottomMargin: Style.space(150)
  readonly property real maxSpread: 56

  function open(payloadJson) {
    var list = root.collectWindows()
    root.windows = list
    root.selectedIndex = 0
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "mihai.cards")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function collectWindows() {
    var tops = Hyprland.toplevels.values
    var active = []
    var rest = []
    for (var i = 0; i < tops.length; i++) {
      var top = tops[i]
      var wayland = top.wayland
      if (!wayland || wayland.parent || !top.workspace) continue
      if (top.workspace.id < 1) continue
      var item = {
        address: String(top.address || ""),
        title: String(wayland.title || wayland.appId || ""),
        appId: String(wayland.appId || ""),
        toplevel: wayland
      }
      if (wayland.activated) active.push(item)
      else rest.push(item)
    }
    return active.concat(rest)
  }

  function iconFor(appId) {
    if (!appId) return ""
    return Quickshell.iconPath(appId.toLowerCase(), true)
  }

  function activate(index) {
    var item = root.windows[index]
    if (!item) return
    var address = item.address
    if (address.indexOf("0x") !== 0) address = "0x" + address
    var target = "window = \"address:" + address + "\""
    Util.execDetached("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ " + target + " })")
      + " && hyprctl dispatch " + Util.shellQuote("hl.dsp.window.alter_zorder({ mode = \"top\", " + target + " })"))
    root.dismiss()
  }

  function moveSelection(step) {
    var count = root.windows.length
    if (count === 0) return
    root.selectedIndex = (root.selectedIndex + step + count) % count
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "mihai-cards"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      id: scrim
      anchors.fill: parent
      color: root.scrim
      opacity: root.opened ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Item {
      id: fan
      anchors.fill: parent
      opacity: root.opened ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }

      readonly property real baseY: height - root.bottomMargin
      readonly property real pivotY: baseY + root.fanRadius
      readonly property real step: root.windows.length > 1
        ? Math.min(9, root.maxSpread / (root.windows.length - 1)) : 0

      Text {
        anchors.top: parent.top
        anchors.topMargin: Style.space(48)
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.windows.length > 0
          ? root.windows[root.selectedIndex].title
          : "No open windows on this workspace"
        color: root.foreground
        opacity: 0.85
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width - Style.space(80))
        horizontalAlignment: Text.AlignHCenter
      }

      Repeater {
        model: root.windows

        delegate: Item {
          id: card
          required property var modelData
          required property int index

          readonly property real angle: (index - (root.windows.length - 1) / 2) * fan.step
          readonly property bool selected: index === root.selectedIndex

          width: root.cardWidth
          height: root.cardHeight
          x: fan.width / 2 - width / 2
          y: fan.baseY - height - (selected ? root.lift : 0)
          z: selected ? 100 : index

          Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

          transform: Rotation {
            origin.x: card.width / 2
            origin.y: card.height + root.fanRadius
            angle: card.angle
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) root.selectedIndex = card.index
            onClicked: root.activate(card.index)
          }

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: root.background
            border.width: card.selected ? Style.space(3) : Style.space(1)
            border.color: card.selected ? root.selectedBackground : root.border
            clip: true

            ScreencopyView {
              id: shot
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: root.cardPadding
              height: card.height - root.titleHeight - root.cardPadding * 2
              captureSource: card.modelData.toplevel
              live: true
              paintCursor: false
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: root.titleHeight
              color: card.selected ? root.selectedBackground : "transparent"

              Image {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: root.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(24)
                height: Style.space(24)
                source: root.iconFor(card.modelData.appId)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              Text {
                anchors.left: icon.right
                anchors.right: parent.right
                anchors.leftMargin: root.cardPadding
                anchors.rightMargin: root.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                text: card.modelData.title
                textFormat: Text.PlainText
                color: card.selected ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(20)
        anchors.horizontalCenter: parent.horizontalCenter
        text: "← → select   ·   ↵ open   ·   esc close"
        color: root.foreground
        opacity: 0.5
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.dismiss()
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
          root.moveSelection(-1)
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
          root.moveSelection(1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activate(root.selectedIndex)
        } else {
          return
        }
        event.accepted = true
      }
    }
  }
}
