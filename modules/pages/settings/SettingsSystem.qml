import QtQuick
import QtQuick.Layouts
import "../../components" as C

Item {
  id: root
  property var theme
  property var sfx
  property var settings
  property var launcher

  anchors.fill: parent

  function _styleBtnBg(id) {
    if (!settings) return theme ? theme.surface2 : "#222"
    return (settings.themeId === id) ? (theme ? theme.accent : "#4aa3ff") : (theme ? theme.surface2 : "#222")
  }

  function _styleBtnFg(id) {
    if (!settings) return theme ? theme.text : "white"
    return (settings.themeId === id) ? (theme ? theme.bg : "#000") : (theme ? theme.text : "white")
  }

  function _variantBtnBg(v) {
    if (!settings) return theme ? theme.surface2 : "#222"
    return (settings.themeVariant === v) ? (theme ? theme.accent : "#4aa3ff") : (theme ? theme.surface2 : "#222")
  }

  function _accentBtnBg(a) {
    if (!settings) return theme ? theme.surface2 : "#222"
    return (settings.themeAccent === a) ? (theme ? theme.accent : "#4aa3ff") : (theme ? theme.surface2 : "#222")
  }

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight
    clip: true

    Column {
      id: col
      width: parent.width
      spacing: theme ? theme.spacing : 12
      anchors.margins: theme ? theme.padding : 14
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top

      Text {
        text: "Appearance"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        text: "Style"
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
      }

      Row {
        spacing: 10
        C.DeckButton {
          theme: theme; sfx: root.sfx
          text: "Default"
          compact: true
          bg: _styleBtnBg("default")
          fg: _styleBtnFg("default")
          onClicked: settings.themeId = "default"
        }
        C.DeckButton {
          theme: theme; sfx: root.sfx
          text: "Steam"
          compact: true
          bg: _styleBtnBg("steam")
          fg: _styleBtnFg("steam")
          onClicked: settings.themeId = "steam"
        }
      }

      Text {
        text: "Palette"
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
      }

      Row {
        spacing: 10
        Repeater {
          model: ["mocha", "macchiato", "frappe", "latte"]
          delegate: C.DeckButton {
            theme: root.theme; sfx: root.sfx
            text: ("" + modelData).charAt(0).toUpperCase() + ("" + modelData).slice(1)
            compact: true
            bg: _variantBtnBg(modelData)
            fg: (settings && settings.themeVariant === modelData) ? (theme ? theme.bg : "#000") : (theme ? theme.text : "white")
            onClicked: settings.themeVariant = modelData
          }
        }
      }

      Text {
        text: "Accent"
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
      }

      Flow {
        width: parent.width
        spacing: 10
        Repeater {
          model: ["sky", "blue", "mauve", "pink", "teal", "peach", "green"]
          delegate: C.DeckButton {
            theme: root.theme; sfx: root.sfx
            text: ("" + modelData).toUpperCase()
            compact: true
            bg: _accentBtnBg(modelData)
            fg: (settings && settings.themeAccent === modelData) ? (theme ? theme.bg : "#000") : (theme ? theme.text : "white")
            onClicked: settings.themeAccent = modelData
          }
        }
      }

      // Typography
      Text {
        text: "Typography"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        text: "Nerd fonts look best (CaskaydiaCove is the default). If a font isn't installed, Qt will fall back."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
        wrapMode: Text.Wrap
        width: parent.width
      }

      Text {
        text: "Font"
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
      }

      Flow {
        width: parent.width
        spacing: 10
        Repeater {
          model: [
            "CaskaydiaCove Nerd Font",
            "JetBrainsMono Nerd Font",
            "FiraCode Nerd Font",
            "Iosevka Nerd Font",
            "Noto Sans",
            "System Default"
          ]
          delegate: C.DeckButton {
            theme: root.theme; sfx: root.sfx
            text: modelData.replace(" Nerd Font", "")
            compact: true
            bg: (settings && settings.fontFamily === modelData) ? (theme ? theme.accent : "#4aa3ff") : (theme ? theme.surface2 : "#222")
            fg: (settings && settings.fontFamily === modelData) ? (theme ? theme.bg : "#000") : (theme ? theme.text : "white")
            onClicked: settings.fontFamily = modelData
          }
        }
      }

      C.DeckTextField {
        theme: theme
        label: "Custom font family"
        placeholder: "e.g. CaskaydiaCove Nerd Font"
        text: settings ? settings.fontFamily : ""
        onChanged: { if (settings && text.length > 0) settings.fontFamily = text }
      }

      Text {
        text: "Font size"
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
      }

      Row {
        spacing: 10
        Repeater {
          model: [14, 15, 16, 17, 18]
          delegate: C.DeckButton {
            theme: root.theme; sfx: root.sfx
            compact: true
            text: modelData + "px"
            bg: (settings && settings.fontPixelSize === modelData) ? (theme ? theme.accent : "#4aa3ff") : (theme ? theme.surface2 : "#222")
            fg: (settings && settings.fontPixelSize === modelData) ? (theme ? theme.bg : "#000") : (theme ? theme.text : "white")
            onClicked: settings.fontPixelSize = modelData
          }
        }
      }

      // UI scale
      Text {
        text: "UI scale"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        text: "Auto scale adapts to Steam Deck / Ally / 4K displays. Manual is useful if your monitor/TV needs bigger UI."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "Auto UI scale"
        checked: settings ? settings.uiScaleAuto : true
        onToggled: if (settings) settings.uiScaleAuto = checked
      }

      Column {
        visible: settings ? !settings.uiScaleAuto : false
        spacing: 10

        Row {
          spacing: 10
          C.DeckButton {
            theme: root.theme; sfx: root.sfx
            text: "−"
            compact: true
            onClicked: if (settings) settings.uiScaleManual = Math.max(0.75, Math.round((settings.uiScaleManual - 0.05) * 100) / 100)
          }
          Text {
            text: settings ? (Math.round(settings.uiScaleManual * 100) + "%") : "100%"
            color: theme ? theme.text : "white"
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
            width: 80
          }
          C.DeckButton {
            theme: root.theme; sfx: root.sfx
            text: "+"
            compact: true
            onClicked: if (settings) settings.uiScaleManual = Math.min(2.0, Math.round((settings.uiScaleManual + 0.05) * 100) / 100)
          }
        }

        Flow {
          width: parent.width
          spacing: 10
          Repeater {
            model: [0.9, 1.0, 1.1, 1.15, 1.25, 1.35, 1.5, 1.6, 1.75]
            delegate: C.DeckButton {
              theme: root.theme; sfx: root.sfx
              compact: true
              text: Math.round(modelData*100) + "%"
              bg: (settings && Math.abs(settings.uiScaleManual - modelData) < 0.001) ? (theme ? theme.accent : "#4aa3ff") : (theme ? theme.surface2 : "#222")
              fg: (settings && Math.abs(settings.uiScaleManual - modelData) < 0.001) ? (theme ? theme.bg : "#000") : (theme ? theme.text : "white")
              onClicked: if (settings) settings.uiScaleManual = modelData
            }
          }
        }
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Motion & Sound"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "Reduce motion (less animation)"
        checked: settings ? settings.reduceMotion : false
        onToggled: settings.reduceMotion = checked
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "UI sound effects"
        checked: settings ? settings.uiSfxEnabled : true
        onToggled: settings.uiSfxEnabled = checked
      }

      Row {
        spacing: 10
        Text {
          text: "SFX volume"
          color: theme ? theme.textMuted : "#aaa"
          font.pixelSize: 13
          width: 120
          verticalAlignment: Text.AlignVCenter
        }
        Repeater {
          model: [0.0, 0.25, 0.5, 0.65, 0.8, 1.0]
          delegate: C.DeckButton {
            theme: root.theme; sfx: root.sfx
            text: Math.round(modelData*100) + "%"
            compact: true
            bg: (settings && Math.abs(settings.uiSfxVolume - modelData) < 0.001) ? (theme ? theme.accent : "#4aa3ff") : (theme ? theme.surface2 : "#222")
            fg: (settings && Math.abs(settings.uiSfxVolume - modelData) < 0.001) ? (theme ? theme.bg : "#000") : (theme ? theme.text : "white")
            onClicked: settings.uiSfxVolume = modelData
          }
        }
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Modules"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        text: "Enable modules to populate Library/Friends. Base UI stays usable with zero modules."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "Steam (library + installs + friends)"
        checked: settings.moduleSteam
        onToggled: settings.moduleSteam = checked
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "Lutris (library + launch)"
        checked: settings.moduleLutris
        onToggled: settings.moduleLutris = checked
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Performance (session)"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        text: "These are stored defaults. Live application depends on your gamescope build; Quick Access can apply some live via gamescope atoms."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "Enable VRR (Adaptive Sync)"
        checked: settings.vrrEnabled
        onToggled: settings.vrrEnabled = checked
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "Enable FSR scaling (global default)"
        checked: settings.fsrEnabled
        onToggled: settings.fsrEnabled = checked
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Input & Overlay"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        text: "Overlay toggle key: F1 (map a gamepad combo to F1 using inputplumber / hhd / Steam Input)."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckButton {
        theme: theme
        sfx: root.sfx
        text: "Open HHD UI"
        onClicked: if (launcher) launcher.openHHD()
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Experimental"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      C.DeckToggle {
        theme: theme
        sfx: root.sfx
        label: "Prefer Proton Wayland by default (may break overlay/input)"
        checked: settings.protonWaylandDefault
        onToggled: settings.protonWaylandDefault = checked
      }

      Item { height: 24; width: 1 }
    }
  }
}