import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import "model"
import "components"
import "pages"

// The settings UI itself, independent of where it is hosted. SettingsPanel.qml
// puts this inside a FloatingWindow; a standalone harness can place it in any
// window.
Item {
  id: win

  // Raised when the user asks to leave (Esc). The host decides what that means.
  signal closeRequested()

  property string currentPage: "appearance"
  property string search: ""

  readonly property var genericPages: ["appearance", "window", "motion", "input"]

  function isGeneric(id) {
    return genericPages.indexOf(id) !== -1
  }

  function currentMeta() {
    var p = SettingsStore.pageById(currentPage)
    return p ? p : { label: "", desc: "" }
  }

  function moveFocus(delta) {
    var item = Window.activeFocusItem
    if (!item) return
    var next = item.nextItemInFocusChain(delta > 0)
    if (next) next.forceActiveFocus()
  }

  // Re-read live values and re-focus, called by the host each time it opens.
  function activate() {
    SettingsStore.refresh()
    Omarchy.reload()
    searchField.forceActiveFocus()
  }

  Item {
    id: rootItem
    anchors.fill: parent
    focus: true

    Keys.onDownPressed: {
      win.moveFocus(1)
      event.accepted = true
    }
    Keys.onUpPressed: {
      win.moveFocus(-1)
      event.accepted = true
    }
    Keys.onEscapePressed: win.closeRequested()

    Row {
      anchors.fill: parent

      Sidebar {
        id: sidebar
        width: 236
        height: parent.height
        currentPage: win.currentPage
        filter: win.search
        onSelected: function (id) {
          win.search = ""
          searchField.text = ""
          win.currentPage = id
        }
      }

      Item {
        id: rightPane
        width: parent.width - sidebar.width
        height: parent.height

        StatusBar {
          id: status
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: 30
          anchors.rightMargin: 30
        }

        Column {
          id: topCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.topMargin: 22
          anchors.leftMargin: 30
          anchors.rightMargin: 30
          spacing: 12

          PageHeader {
            width: parent.width
            visible: win.search.length === 0
            height: visible ? implicitHeight : 0
            title: win.search.length === 0 ? win.currentMeta().label : "Search"
            description: win.search.length === 0 ? win.currentMeta().desc : ""
          }

          SearchField {
            id: searchField
            width: parent.width
            onTextChanged: win.search = text
          }
        }

        Item {
          id: contentArea
          anchors.top: topCol.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: status.top
          anchors.topMargin: 10
          anchors.leftMargin: 30
          anchors.rightMargin: 30
          anchors.bottomMargin: 8

          GenericPage {
            anchors.fill: parent
            visible: win.search.length === 0 && win.isGeneric(win.currentPage)
            pageId: win.currentPage
          }

          Loader {
            id: customLoader
            anchors.fill: parent
            visible: win.search.length === 0 && !win.isGeneric(win.currentPage)
            source: visible ? win.sourceFor(win.currentPage) : ""
          }

          SearchResults {
            anchors.fill: parent
            visible: win.search.length > 0
            query: win.search
          }
        }
      }
    }
  }

  function sourceFor(id) {
    if (id === "display") return "pages/DisplayPage.qml"
    if (id === "environment") return "pages/EnvironmentPage.qml"
    if (id === "bar") return "pages/BarPage.qml"
    if (id === "idle") return "pages/IdlePage.qml"
    if (id === "nightlight") return "pages/NightlightPage.qml"
    if (id === "updates") return "pages/UpdatesPage.qml"
    if (id === "about") return "pages/AboutPage.qml"
    return ""
  }

  Component.onCompleted: searchField.forceActiveFocus()
}
