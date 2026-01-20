import QtQuick

QtObject {
  id: theme

  // Style ID (shapes, layout tokens)
  property string themeId: "default"        // default = Caelestia-ish

  // Palette selection
  // Default palette: Catppuccin Latte + Sky (can be changed in Settings)
  property string variant: "latte"          // mocha|macchiato|frappe|latte
  property string accentKey: "sky"          // sky|blue|mauve|pink|teal|peach|green

  // Motion
  property bool reduceMotion: false

  // Core colors (computed)
  property color bg: "#1e1e2e"
  property color panel: "#181825"
  property color surface0: "#313244"
  property color surface1: "#45475a"
  property color surface2: "#585b70"

  // Back-compat aliases (older UI files still reference these)
  property color surface: panel
  property real radius: radiusCard
  property real focusScale: reduceMotion ? 1.0 : 1.02

  property color text: "#cdd6f4"
  property color textMuted: "#a6adc8"

  property color accent: "#89dceb"
  property color accent2: "#cba6f7"
  property color good: "#a6e3a1"
  property color warn: "#f9e2af"
  property color bad: "#f38ba8"

  // Component color tokens (solid, no glass)
  property color buttonBg: surface0
  property color buttonHover: surface1
  property color buttonActive: accent
  property color buttonText: text
  property color buttonTextOnAccent: bg

  property color cardBg: panel
  property color cardHover: surface0
  property color cardActive: surface1

  // Layout tokens (rounder, Caelestia-like)
  property real radiusPanel: 40
  property real radiusCard: 34
  property real radiusControl: 28
  property real radiusInner: 26
  property real radiusPill: 999

  property real padding: 24
  property real spacing: 20

 // Shell layout
  property real shellMargins: 24
  property real contentPadding: 22

  // Page pan timing (ms)
  property int pagePanMs: 300

  // Pop-out magnitudes ("melt out" illusion)
  property real popButton: 10
  property real popCard: 14
  property real popToggle: 8

  // Animation durations (ms)
  readonly property int animFast: reduceMotion ? 70 : 110
  readonly property int animMed: reduceMotion ? 110 : 170
  readonly property int animSlow: reduceMotion ? 150 : 260

  // Useful for subtle focus lift
  readonly property real focusLift: 2.5

  // Catppuccin palettes (subset)
  readonly property var catppuccin: ({
    mocha: {
      base: "#1e1e2e",
      mantle: "#181825",
      crust: "#11111b",
      surface0: "#313244",
      surface1: "#45475a",
      surface2: "#585b70",
      text: "#cdd6f4",
      subtext0: "#a6adc8",
      green: "#a6e3a1",
      yellow: "#f9e2af",
      peach: "#fab387",
      red: "#f38ba8",
      pink: "#f5c2e7",
      mauve: "#cba6f7",
      blue: "#89b4fa",
      sky: "#89dceb",
      teal: "#94e2d5"
    },
    macchiato: {
      base: "#24273a",
      mantle: "#1e2030",
      crust: "#181926",
      surface0: "#363a4f",
      surface1: "#494d64",
      surface2: "#5b6078",
      text: "#cad3f5",
      subtext0: "#a5adcb",
      green: "#a6da95",
      yellow: "#eed49f",
      peach: "#f5a97f",
      red: "#ed8796",
      pink: "#f5bde6",
      mauve: "#c6a0f6",
      blue: "#8aadf4",
      sky: "#91d7e3",
      teal: "#8bd5ca"
    },
    frappe: {
      base: "#303446",
      mantle: "#292c3c",
      crust: "#232634",
      surface0: "#414559",
      surface1: "#51576d",
      surface2: "#626880",
      text: "#c6d0f5",
      subtext0: "#a5adce",
      green: "#a6d189",
      yellow: "#e5c890",
      peach: "#ef9f76",
      red: "#e78284",
      pink: "#f4b8e4",
      mauve: "#ca9ee6",
      blue: "#8caaee",
      sky: "#99d1db",
      teal: "#81c8be"
    },
    latte: {
      base: "#eff1f5",
      mantle: "#e6e9ef",
      crust: "#dce0e8",
      surface0: "#ccd0da",
      surface1: "#bcc0cc",
      surface2: "#acb0be",
      text: "#4c4f69",
      subtext0: "#6c6f85",
      green: "#40a02b",
      yellow: "#df8e1d",
      peach: "#fe640b",
      red: "#d20f39",
      pink: "#ea76cb",
      mauve: "#8839ef",
      blue: "#1e66f5",
      sky: "#04a5e5",
      teal: "#179299"
    }
  })

  function _applyPalette() {
    var p = catppuccin[variant]
    if (!p) p = catppuccin.mocha

    bg = p.base
    panel = p.mantle

    surface0 = p.surface0
    surface1 = p.surface1
    surface2 = p.surface2

    text = p.text
    textMuted = p.subtext0

    good = p.green
    warn = p.yellow
    bad = p.red

    accent = p[accentKey] ? p[accentKey] : p.blue

    // Theme style presets
    // "default" aims for a Caelestia-like feel: flatter panels, rounder controls, and solid filled buttons.
    if (themeId === "default") {
      bg = p.crust
      panel = p.base
      // Slightly lighter components on top of the panel
      buttonBg = p.surface1
      buttonHover = p.surface2
      cardBg = p.surface0
      cardHover = p.surface1
      cardActive = p.surface2
    } else if (themeId === "steam") {
      panel = p.mantle
      bg = p.base
    }
    // Component tokens
    // Default assignments (may be overwritten by themeId presets above)
    if (themeId !== "default") {
      buttonBg = surface0
      buttonHover = surface1
      cardBg = panel
      cardHover = surface0
      cardActive = surface1
    }

    buttonActive = accent
    buttonText = text
    buttonTextOnAccent = bg

    // Latte needs special handling to avoid a washed UI
    if (variant === "latte") {
      if (themeId !== "default") {
        panel = p.crust
        cardBg = panel
      }
    }
  }

  onThemeIdChanged: _applyPalette()
  onVariantChanged: _applyPalette()
  onAccentKeyChanged: _applyPalette()
  Component.onCompleted: _applyPalette()
}