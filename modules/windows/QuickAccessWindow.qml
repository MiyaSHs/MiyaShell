import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../components" as C

PanelWindow {
  id: win
  required property WlOutput output

  property var theme
  property var settings
  property var sfx
  property var appState
  property var launcher
  property var recent
  property var gamescopeCtl

  // UI scale (auto adapts to resolution; manual from Settings)
  property real uiScale: 1.0

  function _autoUiScale() {
    var w = output ? output.geometry.width : win.width
    var h = output ? output.geometry.height : win.height
    var minDim = Math.min(w, h)
    if (minDim >= 2160) return 1.60
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

  Component.onCompleted: _refreshUiScale()
  Connections {
    target: settings
    function onUiScaleAutoChanged() { win._refreshUiScale() }
    function onUiScaleManualChanged() { win._refreshUiScale() }
  }

  // Visible only when requested.
  property bool open: appState ? appState.overlayVisible : false
  visible: true

  readonly property int baseW: 520
  readonly property int targetW: Math.max(1, Math.round(baseW * uiScale))

  // “Melt out from the side” (no background dimming, no blur)
  // Keep the window anchored at the right edge and animate WIDTH only.
  width: open ? targetW : 1
  height: output ? Math.min(output.geometry.height * 0.90, Math.round(700 * uiScale)) : Math.round(700 * uiScale)

  anchors.right: parent.right
  anchors.verticalCenter: parent.verticalCenter
  anchors.margins: theme ? theme.padding : 24

  color: "#00000000"

  Behavior on width {
    NumberAnimation {
      duration: (theme && theme.reduceMotion) ? 0 : (theme ? theme.animSlow : 260)
      easing.type: Easing.OutBack
      easing.overshoot: 1.02
    }
  }

  onOpenChanged: {
    if (!sfx) return
    if (open && sfx.open) sfx.open()
    if (!open && sfx.close) sfx.close()
  }

  Keys.onPressed: function(e) {
    if (e.key === Qt.Key_Escape) {
      e.accepted = true
      if (appState) appState.overlayVisible = false
    }
  }

  // Clip to window bounds so the panel feels like it is emerging
  Item {
    anchors.fill: parent
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: theme ? theme.radiusPanel : 40
      color: theme ? theme.panel : "#111"
    }

    // Scaled overlay UI (keeps sizing consistent across resolutions)
    Item {
      id: scaledRoot
      x: 0; y: 0
      width: win.width / win.uiScale
      height: win.height / win.uiScale
      scale: win.uiScale
      transformOrigin: Item.TopLeft

      ColumnLayout {
      anchors.fill: parent
      anchors.margins: theme ? theme.padding : 24
      spacing: theme ? theme.spacing : 18

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Quick Access"
          color: theme ? theme.text : "white"
          font.pixelSize: 18
          font.bold: true
          Layout.fillWidth: true
        }
        C.DeckButton {
          theme: theme
          sfx: sfx
          text: "Close"
          compact: true
          onClicked: if (appState) appState.overlayVisible = false
        }
      }

      Text {
        text: "System overlay: gamescope controls + launch toggles. No dimming, no blur."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 12
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Performance"
        color: theme ? theme.text : "white"
        font.pixelSize: 14
        font.bold: true
      }

      Text { text: "FPS limit"; color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 12 }
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        C.DeckButton { theme: theme; sfx: sfx; text: "Uncapped"; compact: true; onClicked: { if (settings) settings.fpsLimit = 0; if (gamescopeCtl) gamescopeCtl.setFps(0) } }
        C.DeckButton { theme: theme; sfx: sfx; text: "30"; compact: true; onClicked: { if (settings) settings.fpsLimit = 30; if (gamescopeCtl) gamescopeCtl.setFps(30) } }
        C.DeckButton { theme: theme; sfx: sfx; text: "40"; compact: true; onClicked: { if (settings) settings.fpsLimit = 40; if (gamescopeCtl) gamescopeCtl.setFps(40) } }
        C.DeckButton { theme: theme; sfx: sfx; text: "60"; compact: true; onClicked: { if (settings) settings.fpsLimit = 60; if (gamescopeCtl) gamescopeCtl.setFps(60) } }
      }

      Text { text: "Scaling"; color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 12 }
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        C.DeckButton { theme: theme; sfx: sfx; text: "Auto"; compact: true; onClicked: { if (settings) settings.fsrEnabled = false; if (gamescopeCtl) gamescopeCtl.setScaler("auto") } }
        C.DeckButton { theme: theme; sfx: sfx; text: "FSR"; compact: true; onClicked: { if (settings) settings.fsrEnabled = true; if (gamescopeCtl) gamescopeCtl.setScaler("fsr") } }
        C.DeckButton { theme: theme; sfx: sfx; text: "NIS"; compact: true; onClicked: { if (settings) settings.fsrEnabled = false; if (gamescopeCtl) gamescopeCtl.setScaler("nis") } }
        C.DeckButton { theme: theme; sfx: sfx; text: "Integer"; compact: true; onClicked: { if (settings) settings.fsrEnabled = false; if (gamescopeCtl) gamescopeCtl.setScaler("integer") } }
      }

      Text { text: "FSR sharpness"; color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 12 }
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Repeater {
          model: [0,1,2,3,4,5]
          delegate: C.DeckButton {
            theme: win.theme
            sfx: win.sfx
            text: "" + modelData
            compact: true
            onClicked: { if (settings) settings.fsrSharpness = modelData; if (gamescopeCtl) gamescopeCtl.setFsrSharpness(modelData) }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Launch environment"
        color: theme ? theme.text : "white"
        font.pixelSize: 14
        font.bold: true
      }

      C.DeckToggle {
        theme: theme
        sfx: sfx
        label: "Enable MangoHUD (non-Steam launches)"
        checked: settings ? settings.mangohudEnabled : false
        onToggled: if (settings) settings.mangohudEnabled = checked
      }

      C.DeckToggle {
        theme: theme
        sfx: sfx
        label: "Prefer Proton Wayland (experimental)"
        checked: settings ? settings.protonWaylandDefault : false
        onToggled: if (settings) settings.protonWaylandDefault = checked
      }

      Item { Layout.fillHeight: true }

      RowLayout {
        Layout.fillWidth: true
        C.DeckButton { theme: theme; sfx: sfx; text: "Open HHD"; onClicked: launcher.openHHD() }
        C.DeckButton { theme: theme; sfx: sfx; text: "Force Steam Input 769"; onClicked: launcher.forceSteamInputAppid(769) }
      }
    }
  }
}
}
