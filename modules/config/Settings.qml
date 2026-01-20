import QtQuick
import Qt.labs.settings 1.1

QtObject {
  id: root

  // Persisted settings.
  // Qt.labs.settings stores an ini-like file under XDG config.
  Settings {
    id: store
    category: "miyashell"

    // Theme system
    // themeId: visual style (shapes/motion tokens)
    // themeVariant: palette family (catppuccin variant)
    // themeAccent: accent key
    property string themeId: "default"
    // Default to Catppuccin Latte + Sky (user preference)
    property string themeVariant: "latte"
    property string themeAccent: "sky"

    // Back-compat: old preset name (ThemeManager will map this into themeId/variant).
    property string themePreset: "default"

    // Motion + sound
    property bool reduceMotion: false
    property bool uiSfxEnabled: true
    property real uiSfxVolume: 0.65

    // Typography
    // Default: Nerd Font variant of Cascadia Code
    property string fontFamily: "CaskaydiaCove Nerd Font"
    property int fontPixelSize: 16

    // UI scaling
    // Auto tries to pick a comfortable scale based on output resolution.
    // Manual applies the chosen scale factor (useful for 4K TVs/monitors).
    property bool uiScaleAuto: true
    property real uiScaleManual: 1.0

    // Overlay / menu hotkey (map gamepad button combos to this if desired)
    property int overlayKey: Qt.Key_F1

    // Default provider settings
    property bool showSteamUninstalled: true

    // Modules (providers)
    property bool moduleSteam: true
    property bool moduleLutris: true

    // Steam Web API (optional; used for Friends presence)
    property string steamApiKey: ""
    property string steamId64: ""

    // Experimental: prefer native Wayland for Proton (may break Steam overlay/input)
    property bool protonWaylandDefault: false

    // MangoHUD preferences for non-Steam launches
    property bool mangohudEnabled: false
    property string mangohudProfile: "default"

    // Gamescope preferences (best-effort)
    property int fpsLimit: 0            // 0 = uncapped
    property bool vrrEnabled: true
    property bool fsrEnabled: false
    property real fsrSharpness: 2.0

    // Proton-GE updater
    property bool protonGeUpdaterEnabled: true
    property bool protonGeNotify: true
    property bool protonGeAutoInstall: false
    property int protonGeKeepVersions: 2
    property int protonGeCheckIntervalSec: 3600
    property string protonGeRepo: "GloriousEggroll/proton-ge-custom"
    property string protonGeInstallDir: ""  // empty = auto-discover

    // Music
    property string musicRoot: "" // empty -> ~/Music

    // Home: recently launched entries (JSON array)
    property string recentJson: "[]"
  }

  // Expose store properties as "real" properties for easy binding.
  property alias themeId: store.themeId
  property alias themeVariant: store.themeVariant
  property alias themeAccent: store.themeAccent
  property alias themePreset: store.themePreset

  property alias reduceMotion: store.reduceMotion
  property alias uiSfxEnabled: store.uiSfxEnabled
  property alias uiSfxVolume: store.uiSfxVolume

  property alias fontFamily: store.fontFamily
  property alias fontPixelSize: store.fontPixelSize

  property alias uiScaleAuto: store.uiScaleAuto
  property alias uiScaleManual: store.uiScaleManual

  property alias overlayKey: store.overlayKey

  property alias showSteamUninstalled: store.showSteamUninstalled

  property alias moduleSteam: store.moduleSteam
  property alias moduleLutris: store.moduleLutris

  property alias steamApiKey: store.steamApiKey
  property alias steamId64: store.steamId64

  property alias protonWaylandDefault: store.protonWaylandDefault

  property alias mangohudEnabled: store.mangohudEnabled
  property alias mangohudProfile: store.mangohudProfile

  property alias fpsLimit: store.fpsLimit
  property alias vrrEnabled: store.vrrEnabled
  property alias fsrEnabled: store.fsrEnabled
  property alias fsrSharpness: store.fsrSharpness

  property alias protonGeUpdaterEnabled: store.protonGeUpdaterEnabled
  property alias protonGeNotify: store.protonGeNotify
  property alias protonGeAutoInstall: store.protonGeAutoInstall
  property alias protonGeKeepVersions: store.protonGeKeepVersions
  property alias protonGeCheckIntervalSec: store.protonGeCheckIntervalSec
  property alias protonGeRepo: store.protonGeRepo
  property alias protonGeInstallDir: store.protonGeInstallDir

  property alias musicRoot: store.musicRoot

  property alias recentJson: store.recentJson
}
