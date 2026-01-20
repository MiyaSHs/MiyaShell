import QtQuick
import QtQuick.Layouts
import "." as C

Item {
  id: root
  property var theme
  property var sfx

  // Array of objects: [{id:"steam", title:"STEAM"}, ...]
  property var tabs: []
  property string currentId: (tabs && tabs.length>0) ? (tabs[0].id||"") : ""
  signal selected(string tabId)

  implicitHeight: 40

  RowLayout {
    anchors.fill: parent
    spacing: 8

    Repeater {
      model: root.tabs
      delegate: C.DeckButton {
        theme: root.theme
        sfx: root.sfx
        text: modelData.title
        compact: true
        bg: (modelData.id === root.currentId) ? (root.theme ? root.theme.accent : "#4aa3ff") : (root.theme ? root.theme.surface2 : "#222")
        bgFocused: root.theme ? root.theme.accent : "#4aa3ff"
        fg: (modelData.id === root.currentId) ? (root.theme ? root.theme.bg : "#000") : (root.theme ? root.theme.text : "white")
        onClicked: root.selected(modelData.id)
      }
    }
    Item { Layout.fillWidth: true }
  }
}
