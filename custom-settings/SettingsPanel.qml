import QtQuick
import Quickshell
import qs.Commons

// Panel entry point. The shell mounts this once (keepLoaded) and calls open() /
// close() when the gear is clicked or `omarchy-shell shell toggle` runs. The UI
// lives in SettingsApp.qml so it can be hosted anywhere.
Item {
  id: root

  // Host injections.
  property var shell: null

  readonly property string pluginId: "nightdevil00.custom-settings"

  // True only while the host is closing us, so the window's own
  // visibleChanged handler does not echo a hide() back to the shell.
  property bool closingFromHost: false

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    Qt.callLater(function() { app.activate() })
  }

  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  // Esc and the window close button: tell the shell so its open-panel map and
  // toggle() stay consistent.
  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else window.visible = false
  }

  FloatingWindow {
    id: window
    title: "Omarchy Settings"
    color: ShellColor.background
    implicitWidth: 1080
    implicitHeight: 720
    minimumSize: Qt.size(900, 580)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide(root.pluginId)
    }

    SettingsApp {
      id: app
      anchors.fill: parent
      onCloseRequested: root.requestClose()
    }
  }
}
