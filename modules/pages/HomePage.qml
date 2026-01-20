import QtQuick
import QtQuick.Layouts
import "../components" as C

Item {
  id: page
  property var theme
  property var sfx
  property var library
  property var launcher
  property var recent

  anchors.fill: parent

  ColumnLayout {
    anchors.fill: parent
    spacing: theme ? theme.spacing : 18

    // Page header lives WITH the page (but the main surface does not move)
    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      Text {
        text: "Home"
        color: theme ? theme.text : "white"
        font.pixelSize: 22
        font.bold: true
        Layout.fillWidth: true
      }

      C.DeckButton {
        theme: theme
        sfx: page.sfx
        text: "Steam"
        compact: true
        onClicked: if (launcher) launcher.openSteamUI()
      }
      C.DeckButton {
        theme: theme
        sfx: page.sfx
        text: "Lutris"
        compact: true
        onClicked: if (launcher) launcher.openLutrisUI()
      }
    }

    Text {
      visible: recent && recent.items && recent.items.count === 0
      text: "No recent games yet. Launch something from Library."
      color: theme ? theme.textMuted : "#aaa"
      font.pixelSize: 13
      wrapMode: Text.Wrap
      Layout.fillWidth: true
    }

    GridView {
      id: grid
      Layout.fillWidth: true
      Layout.fillHeight: true
      cellWidth: 228
      cellHeight: 330
      model: (recent && recent.items) ? recent.items : null
      clip: true
      focus: true

      delegate: C.GameCard {
        theme: page.theme
        sfx: page.sfx
        game: ({
          provider: provider,
          id: id,
          appid: id,
          name: name,
          cover: cover,
          installed: true
        })
        onLaunchRequested: {
          var g = ({ provider: provider, id: id, appid: id, name: name, cover: cover, installed: true })
          if (recent) recent.recordLaunch(g)
          if (provider === "steam") launcher.launchSteam(id)
          else if (provider === "lutris") launcher.launchLutris(id)
        }
      }
    }
  }
}
