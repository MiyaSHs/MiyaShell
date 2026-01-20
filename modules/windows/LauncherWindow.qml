import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../components" as C
import "../pages" as Pages

PanelWindow {
  id: win
  required property WlOutput output

  // Inject shared objects
  property var theme
  property var settings
  property var sfx
  property var appState
  property var library
  property var downloads
  property var storage
  property var friends
  property var music
  property var launcher
  property var recent
  property var protonGe

  // UI scale (auto adapts to resolution; manual from Settings)
  property real uiScale: 1.0

  function _autoUiScale() {
    var minDim = Math.min(win.width, win.height)
    // Handheld baselines: Deck 800p -> 1.0, Ally 1080p -> 1.15
    if (minDim >= 2160) return 1.60  // 4K
    if (minDim >= 1440) return 1.35
    if (minDim >= 1080) return 1.15
    if (minDim >= 900)  return 1.08
    return 1.00
  }

  function _refreshUiScale() {
    var s = 1.0
    if (settings) {
      if (settings.uiScaleAuto) s = _autoUiScale()
      else if (settings.uiScaleManual > 0) s = settings.uiScaleManual
    }
    uiScale = Math.max(0.75, Math.min(2.0, s))
  }

  onWidthChanged: _refreshUiScale()
  onHeightChanged: _refreshUiScale()
  Component.onCompleted: _refreshUiScale()
  Connections {
    target: settings
    function onUiScaleAutoChanged() { win._refreshUiScale() }
    function onUiScaleManualChanged() { win._refreshUiScale() }
  }

  anchors.fill: parent

  color: theme ? theme.bg : "#000"

  // Hotkeys (map gamepad combos to these keys if needed)
  Keys.onPressed: function(e) {
    if (settings && e.key === settings.overlayKey) {
      e.accepted = true
      if (appState) {
        appState.overlayVisible = !appState.overlayVisible
        if (sfx && appState.overlayVisible && sfx.open) sfx.open()
        if (sfx && !appState.overlayVisible && sfx.close) sfx.close()
      }
    }
  }

  Rectangle { anchors.fill: parent; color: theme ? theme.bg : "#000" }

  // Scaled UI root (keeps layout consistent across Deck/Ally/4K)
  Item {
    id: scaledRoot
    x: 0; y: 0
    width: win.width / win.uiScale
    height: win.height / win.uiScale
    scale: win.uiScale
    transformOrigin: Item.TopLeft

    ColumnLayout {
    anchors.fill: parent
    anchors.margins: theme ? theme.shellMargins : 24
    spacing: theme ? theme.spacing : 18

    // Top nav (static)
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Text {
        text: "MiyaShell"
        color: theme ? theme.text : "white"
        font.pixelSize: 19
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }

      Item { Layout.fillWidth: true }

      C.DeckButton { theme: theme; sfx: sfx; text: "Home"; compact: true; onClicked: if (appState) appState.pageIndex = 0 }
      C.DeckButton { theme: theme; sfx: sfx; text: "Library"; compact: true; onClicked: if (appState) appState.pageIndex = 1 }
      C.DeckButton { theme: theme; sfx: sfx; text: "Friends"; compact: true; onClicked: if (appState) appState.pageIndex = 2 }
      C.DeckButton { theme: theme; sfx: sfx; text: "Music"; compact: true; onClicked: if (appState) appState.pageIndex = 3 }
      C.DeckButton { theme: theme; sfx: sfx; text: "Downloads"; compact: true; onClicked: if (appState) appState.pageIndex = 4 }
      C.DeckButton { theme: theme; sfx: sfx; text: "Storage"; compact: true; onClicked: if (appState) appState.pageIndex = 5 }
      C.DeckButton { theme: theme; sfx: sfx; text: "Settings"; compact: true; onClicked: if (appState) appState.pageIndex = 6 }
    }

    // Middle surface stays put; ONLY the inner content pans.
    Rectangle {
      id: contentFrame
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: theme ? theme.radiusPanel : 40
      color: theme ? theme.panel : "#111"
      clip: true

      Item {
        id: contentViewport
        anchors.fill: parent
        anchors.margins: theme ? theme.contentPadding : 26
        clip: true

        // Main content (smooth workspace-like pan). No opacity changes.
        Item {
          id: pageHost
          anchors.fill: parent
          clip: true

          property int activeIndex: 0
          property int pendingIndex: -1
          property int panDir: 1 // 1 = forward/right-to-left, -1 = back/left-to-right

          function componentFor(i) {
            if (i === 0) return homePage
            if (i === 1) return libraryPage
            if (i === 2) return friendsPage
            if (i === 3) return musicPage
            if (i === 4) return downloadsPage
            if (i === 5) return storagePage
            if (i === 6) return settingsPage
            return homePage
          }

          Component.onCompleted: {
            pageHost.activeIndex = appState ? appState.pageIndex : 0
            curLoader.sourceComponent = pageHost.componentFor(pageHost.activeIndex)
            curLoader.x = 0
            nextLoader.x = pageHost.width
          }

          Connections {
            target: appState
            function onPageIndexChanged() {
              if (!appState) return
              if (pageHost.pendingIndex !== -1) return
              if (appState.pageIndex === pageHost.activeIndex) return

              pageHost.pendingIndex = appState.pageIndex
              pageHost.panDir = (pageHost.pendingIndex > pageHost.activeIndex) ? 1 : -1

              nextLoader.sourceComponent = pageHost.componentFor(pageHost.pendingIndex)
              nextLoader.x = pageHost.panDir * pageHost.width
              curLoader.x = 0

              pageAnim.restart()
            }
          }

          Loader {
            id: curLoader
            anchors.fill: parent
            x: 0
          }

          Loader {
            id: nextLoader
            anchors.fill: parent
            x: width
          }

          ParallelAnimation {
            id: pageAnim
            running: false

            NumberAnimation {
              target: curLoader
              property: "x"
              to: -pageHost.panDir * pageHost.width
              duration: (theme && theme.reduceMotion) ? 0 : (theme ? theme.pagePanMs : 320)
              easing.type: Easing.InOutCubic
            }

            NumberAnimation {
              target: nextLoader
              property: "x"
              to: 0
              duration: (theme && theme.reduceMotion) ? 0 : (theme ? theme.pagePanMs : 320)
              easing.type: Easing.InOutCubic
            }

            onStopped: {
              if (pageHost.pendingIndex === -1) return
              pageHost.activeIndex = pageHost.pendingIndex
              pageHost.pendingIndex = -1

              curLoader.sourceComponent = pageHost.componentFor(pageHost.activeIndex)
              curLoader.x = 0

              nextLoader.sourceComponent = null
              nextLoader.x = pageHost.width
            }
          }

          // Page components
          Component {
            id: homePage
            Pages.HomePage {
              theme: win.theme
              sfx: win.sfx
              library: win.library
              launcher: win.launcher
              recent: win.recent
            }
          }

          Component {
            id: libraryPage
            Pages.LibraryPage {
              theme: win.theme
              sfx: win.sfx
              settings: win.settings
              library: win.library
              launcher: win.launcher
              recent: win.recent
            }
          }

          Component {
            id: downloadsPage
            Pages.DownloadsPage {
              theme: win.theme
              sfx: win.sfx
              downloads: win.downloads
              launcher: win.launcher
            }
          }

          Component {
            id: friendsPage
            Pages.FriendsPage {
              theme: win.theme
              sfx: win.sfx
              settings: win.settings
              friends: win.friends
              launcher: win.launcher
            }
          }

          Component {
            id: musicPage
            Pages.MusicPage {
              theme: win.theme
              sfx: win.sfx
              settings: win.settings
              music: win.music
            }
          }

          Component {
            id: storagePage
            Pages.StoragePage {
              theme: win.theme
              sfx: win.sfx
              storage: win.storage
            }
          }

          Component {
            id: settingsPage
            Pages.SettingsPage {
              theme: win.theme
              sfx: win.sfx
              settings: win.settings
              launcher: win.launcher
              protonGe: win.protonGe
            }
          }
        }
      }
    }
    }
  }
}
