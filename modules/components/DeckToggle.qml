import QtQuick
import QtQuick.Layouts

Item {
  id: root
  property var theme
  property var sfx

  property string label: ""
  property bool checked: false
  signal toggled(bool checked)

  implicitHeight: 46
  implicitWidth: 360

  property bool hovered: false

  // “Melt out” for the row (expand from top + sides, never down)
  property real pop: 0
  readonly property real popTarget: (root.activeFocus || hovered) ? (theme ? theme.popToggle : 8) : 0
  onPopTargetChanged: { popAnim.to = popTarget; popAnim.restart() }

  function _toggle() {
    root.checked = !root.checked
    if (sfx && sfx.toggle) sfx.toggle()
    root.toggled(root.checked)
  }

  Keys.onReturnPressed: root._toggle()
  Keys.onEnterPressed: root._toggle()

  onActiveFocusChanged: {
    if (root.activeFocus && sfx && sfx.focus) sfx.focus()
  }

  Rectangle {
    id: bgRow
    anchors.fill: parent
    anchors.leftMargin: -root.pop
    anchors.rightMargin: -root.pop
    anchors.topMargin: -root.pop
    anchors.bottomMargin: 0

    radius: theme ? theme.radiusControl : 28
    color: theme ? theme.surface0 : "#313244"
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: theme ? Math.max(14, theme.padding - 8) : 16
    spacing: theme ? theme.spacing : 14

    Text {
      text: root.label
      color: theme ? theme.text : "white"
      font.pixelSize: 15
      font.bold: true
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      wrapMode: Text.NoWrap
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignLeft
    }

    Rectangle {
      id: track
      width: 66
      height: 32
      radius: 16
      color: root.checked ? (theme ? theme.accent : "#89dceb") : (theme ? theme.surface2 : "#585b70")
      Behavior on color { ColorAnimation { duration: theme ? theme.animMed : 170 } }

      Layout.alignment: Qt.AlignVCenter

      Rectangle {
        id: knob
        width: 28
        height: 28
        radius: 14
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? (parent.width - width - 2) : 2
        Behavior on x { NumberAnimation { duration: theme ? theme.animMed : 170; easing.type: Easing.OutCubic } }
        color: theme ? theme.bg : "#1e1e2e"
      }
    }
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
    onClicked: root._toggle()
  }
}
