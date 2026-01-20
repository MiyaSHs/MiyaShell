import QtQuick

Item {
  id: root

  // Theme + SFX injected by parent
  property var theme
  property var sfx

  property alias text: label.text

  // Solid button colors (no outlines)
  property color bg: theme ? theme.buttonBg : "#313244"
  property color bgHover: theme ? theme.buttonHover : "#45475a"
  property color bgFocused: theme ? theme.buttonActive : "#89dceb"

  property color fg: theme ? theme.buttonText : "white"
  property color fgFocused: theme ? theme.buttonTextOnAccent : "black"

  property bool compact: false
  property bool enabled: true

  signal clicked()

  // Slightly smaller controls, more modern spacing
  implicitWidth: Math.max(label.implicitWidth + 40, 120)
  implicitHeight: compact ? 36 : 44

  // Hover/focus detection
  property bool hovered: false

  // “Melt out” amount (expand UP + sideways; never down)
  property real pop: 0
  readonly property real popTarget: (root.activeFocus || root.hovered) ? (theme ? theme.popButton : 10) : 0

  onPopTargetChanged: {
    popAnim.to = popTarget
    popAnim.restart()
  }

  // Subtle press
  property real press: 0
  scale: 1.0 - 0.02 * press
  Behavior on scale { NumberAnimation { duration: theme ? theme.animFast : 110; easing.type: Easing.OutCubic } }

  // “Lift” without shadows (Caelestia feel is extrusion, not drop shadow)
  y: (root.activeFocus || root.hovered) ? -(theme ? theme.focusLift : 2.0) : 0
  Behavior on y { NumberAnimation { duration: theme ? theme.animMed : 170; easing.type: Easing.OutCubic } }

  Keys.onReturnPressed: _doClick()
  Keys.onEnterPressed: _doClick()
  Keys.onSpacePressed: _doClick()

  function _doClick() {
    if (!enabled) return
    if (sfx && sfx.select) sfx.select()
    clickAnim.restart()
    root.clicked()
  }

  onActiveFocusChanged: {
    if (root.activeFocus && sfx && sfx.focus) sfx.focus()
  }

  Rectangle {
    id: bgRect
    anchors.fill: parent
    // “Melt out of the top/side” — it grows outward from the surface
    anchors.leftMargin: -root.pop
    anchors.rightMargin: -root.pop
    anchors.topMargin: -root.pop
    anchors.bottomMargin: 0

    radius: theme ? theme.radiusControl : 28

    color: !enabled ? Qt.darker(root.bg, 1.2)
         : (root.activeFocus ? root.bgFocused : (root.hovered ? root.bgHover : root.bg))

    Behavior on color { ColorAnimation { duration: theme ? theme.animMed : 170 } }
  }

  Text {
    id: label
    // Fill + align avoids baseline quirks between fonts (esp Nerd Fonts)
    anchors.fill: parent
    anchors.leftMargin: 18
    anchors.rightMargin: 18
    color: root.activeFocus ? root.fgFocused : root.fg
    Behavior on color { ColorAnimation { duration: theme ? theme.animMed : 170 } }
    font.pixelSize: compact ? 13 : 14
    font.bold: true
    // Make text rendering more consistent across platforms.
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: "Button"
    elide: Text.ElideRight
    wrapMode: Text.NoWrap
    textFormat: Text.PlainText
  }

  NumberAnimation {
    id: popAnim
    target: root
    property: "pop"
    to: 0
    duration: theme ? theme.animMed : 170
    // Feels like extrusion instead of a scale-up
    easing.type: Easing.OutBack
    easing.overshoot: 1.05
  }

  SequentialAnimation {
    id: clickAnim
    NumberAnimation { target: root; property: "press"; to: 1.0; duration: theme ? theme.animFast : 110; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "press"; to: 0.0; duration: theme ? theme.animFast : 110; easing.type: Easing.OutCubic }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    onContainsMouseChanged: {
      root.hovered = containsMouse
      if (containsMouse) root.forceActiveFocus()
      if (containsMouse && sfx && sfx.focus) sfx.focus()
    }
    onPressed: root.press = 1.0
    onReleased: root.press = 0.0
    onClicked: root._doClick()
  }
}
