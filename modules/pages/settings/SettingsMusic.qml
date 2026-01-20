import QtQuick
import QtQuick.Layouts
import "../../components" as C

Item {
  id: root
  property var theme
  property var sfx
  property var settings

  anchors.fill: parent

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
        text: "Music"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }


      Text {
        text: "Local music is built-in. Future providers (e.g. Spotify) will appear as tabs in Music.\n\nBy default we scan ~/Music (recursive). You can override the root folder below.\n\nTip: leaving it empty uses ~/Music."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckTextField {
        theme: theme
        label: "Music root (absolute path)"
        placeholder: "(empty = ~/Music)"
        text: settings ? settings.musicRoot : ""
        onChanged: if (settings) settings.musicRoot = text
      }

      Row {
        spacing: 10
        C.DeckButton {
          theme: theme
          text: "Use default (~/Music)"
          onClicked: if (settings) settings.musicRoot = ""
        }
      }

      Item { height: 24; width: 1 }
    }
  }
}
