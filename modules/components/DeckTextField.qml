import QtQuick

Item {
  id: root
  property var theme
  property string label: ""
  property string text: ""
  property string placeholder: ""
  property bool password: false
  signal changed(string text)

  implicitHeight: 76
  implicitWidth: 520

  property real pop: 0
  readonly property real popTarget: field.activeFocus ? (theme ? theme.popButton : 10) : 0
  onPopTargetChanged: {
    popAnim.to = popTarget
    popAnim.restart()
  }

  Column {
    anchors.fill: parent
    spacing: 6

    Text {
      text: root.label
      color: theme ? theme.text : "white"
      font.pixelSize: 13
      font.bold: true
    }

    Item {
      width: parent.width
      height: 44

      Rectangle {
        id: box
        anchors.fill: parent
        anchors.leftMargin: -root.pop
        anchors.rightMargin: -root.pop
        anchors.topMargin: -root.pop
        anchors.bottomMargin: 0

        radius: theme ? theme.radiusInner : 26
        color: field.activeFocus
               ? (theme ? theme.surface1 : "#45475a")
               : (theme ? theme.surface0 : "#313244")
        Behavior on color { ColorAnimation { duration: theme ? theme.animMed : 170 } }
      }

      TextInput {
        id: field
        anchors.fill: parent
        anchors.margins: 12
        color: theme ? theme.text : "white"
        font.pixelSize: 13
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        text: root.text
        onTextChanged: {
          root.text = text
          root.changed(text)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          text: (field.text.length === 0) ? root.placeholder : ""
          color: theme ? theme.textMuted : "#a6adc8"
          font.pixelSize: 13
          visible: field.text.length === 0
        }
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
}
