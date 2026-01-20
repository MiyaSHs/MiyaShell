import QtQuick

Item {
  id: root

  property var theme
  property var sfx
  property var game // object from model

  signal launchRequested(var game)
  signal installRequested(var game)

  implicitWidth: 200
  implicitHeight: 292

  focus: true

  property bool hovered: false
  readonly property bool focused: root.activeFocus

  // “Melt out” pop amount (expand from top + sides)
  property real pop: 0
  readonly property real popTarget: (focused || hovered) ? (theme ? theme.popCard : 14) : 0
  onPopTargetChanged: {
    popAnim.to = popTarget
    popAnim.restart()
  }

  // Subtle lift (no drop shadow)
  y: (focused || hovered) ? -(theme ? theme.focusLift : 2.0) : 0
  Behavior on y { NumberAnimation { duration: theme ? theme.animMed : 170; easing.type: Easing.OutCubic } }

  onActiveFocusChanged: {
    if (root.activeFocus && sfx && sfx.focus) sfx.focus()
  }

  function _activate() {
    if (!game) return
    if (sfx && sfx.select) sfx.select()
    if (game.provider === "steam" && !game.installed) {
      installRequested(game)
    } else {
      launchRequested(game)
    }
  }

  Keys.onReturnPressed: root._activate()
  Keys.onEnterPressed: root._activate()

  Rectangle {
    id: card
    anchors.fill: parent
    anchors.leftMargin: -root.pop
    anchors.rightMargin: -root.pop
    anchors.topMargin: -root.pop
    anchors.bottomMargin: 0

    radius: theme ? theme.radiusCard : 34
    color: focused ? (theme ? theme.cardActive : "#45475a")
                 : (hovered ? (theme ? theme.cardHover : "#313244")
                            : (theme ? theme.cardBg : "#181825"))
    Behavior on color { ColorAnimation { duration: theme ? theme.animMed : 170 } }
  }

  // Content stays anchored to the original (non-expanded) card bounds
  Column {
    anchors.fill: parent
    anchors.margins: theme ? theme.padding : 18
    spacing: 10

    Item {
      width: parent.width
      height: 190

      Rectangle {
        anchors.fill: parent
        radius: theme ? theme.radiusInner : 26
        color: theme ? theme.surface0 : "#313244"
        clip: true

        Image {
          anchors.fill: parent
          source: (game && game.cover) ? (game.cover.startsWith("file://") ? game.cover : "file://" + game.cover) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          visible: source !== ""
        }

        // Provider badge (solid)
        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: 10
          radius: 999
          color: theme ? theme.surface1 : "#45475a"
          height: 24
          width: providerText.implicitWidth + 18

          Text {
            id: providerText
            anchors.centerIn: parent
            text: game ? ("" + game.provider).toUpperCase() : ""
            color: theme ? theme.text : "white"
            font.pixelSize: 11
            font.bold: true
          }
        }

        // Installed badge (Steam)
        Rectangle {
          visible: game && game.provider === "steam" && game.installed
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 10
          radius: 999
          color: theme ? theme.accent : "#89dceb"
          height: 24
          width: installedText.implicitWidth + 18

          Text {
            id: installedText
            anchors.centerIn: parent
            text: "INSTALLED"
            color: theme ? theme.bg : "black"
            font.pixelSize: 11
            font.bold: true
          }
        }
      }
    }

    Text {
      text: game ? game.name : ""
      color: theme ? theme.text : "white"
      font.pixelSize: 15
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      text: (game && game.provider === "steam" && !game.installed) ? "Install" : "Play"
      color: theme ? theme.textMuted : "#a6adc8"
      font.pixelSize: 12
    }

    Item { height: 2 }
  }

  NumberAnimation {
    id: popAnim
    target: root
    property: "pop"
    to: 0
    duration: theme ? theme.animMed : 170
    easing.type: Easing.OutBack
    easing.overshoot: 1.05
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onContainsMouseChanged: {
      root.hovered = containsMouse
      if (containsMouse) root.forceActiveFocus()
      if (containsMouse && sfx && sfx.focus) sfx.focus()
    }
    onClicked: root._activate()
  }
}
