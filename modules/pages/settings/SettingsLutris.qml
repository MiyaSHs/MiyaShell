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
        text: "Lutris"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      Text {
        text: "Lutris is great for setup.exe workflows (prefix creation, runners).\n\nIn this UI, Lutris games show up in Library and launch via gamescope-fg-lite, so games are tagged as STEAM_GAME for better gamescope behavior."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckButton {
        theme: theme
        text: "Open Lutris"
        onClicked: if (launcher) launcher.openLutrisUI()
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "HUD"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      C.DeckToggle {
        theme: theme
        label: "Enable MangoHUD for non-Steam launches"
        checked: settings.mangohudEnabled
        onToggled: settings.mangohudEnabled = checked
      }

      Text {
        text: "Profile name (MANGOHUD_CONFIGFILE) is planned; for now this is a simple label you can use to drive env vars later."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 13
        wrapMode: Text.Wrap
        width: parent.width
      }

      Row {
        spacing: 10
        C.DeckButton {
          theme: theme
          text: "Profile: " + (settings.mangohudProfile || "default")
          onClicked: {
            var p = settings.mangohudProfile || "default"
            if (p === "default") settings.mangohudProfile = "minimal"
            else if (p === "minimal") settings.mangohudProfile = "detailed"
            else settings.mangohudProfile = "default"
          }
        }
      }

      Item { height: 24; width: 1 }
    }
  }
}
