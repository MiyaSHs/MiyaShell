import QtQuick
import QtQuick.Layouts
import "../components" as C
import "settings" as S

Item {
  id: page
  property var theme
  property var sfx
  property var settings
  property var launcher
  property var protonGe

  anchors.fill: parent

  property string tab: "system" // system|steam|lutris|music

  function _ensureTabValid() {
    if (tab === "steam" && settings && !settings.moduleSteam) tab = "system"
    if (tab === "lutris" && settings && !settings.moduleLutris) tab = "system"
  }

  Component.onCompleted: _ensureTabValid()
  onSettingsChanged: _ensureTabValid()

  ColumnLayout {
    anchors.fill: parent
    spacing: theme ? theme.spacing : 12

    Text {
      text: "Settings"
      color: theme ? theme.text : "white"
      font.pixelSize: 26
      font.bold: true
      Layout.fillWidth: true
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: theme ? theme.radius : 16
      color: theme ? theme.surface : "#111"

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme ? theme.padding : 14
        spacing: theme ? theme.spacing : 12

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          C.DeckButton {
            theme: theme
            sfx: page.sfx
            text: "System"
            compact: true
            onClicked: tab = "system"
          }

          C.DeckButton {
            theme: theme
            sfx: page.sfx
            text: "Steam"
            compact: true
            visible: settings ? settings.moduleSteam : true
            onClicked: tab = "steam"
          }

          C.DeckButton {
            theme: theme
            sfx: page.sfx
            text: "Lutris"
            compact: true
            visible: settings ? settings.moduleLutris : true
            onClicked: tab = "lutris"
          }

          C.DeckButton {
            theme: theme
            sfx: page.sfx
            text: "Music"
            compact: true
            visible: true
            onClicked: tab = "music"
          }

          Item { Layout.fillWidth: true }

          Text {
            text: tab.toUpperCase()
            color: theme ? theme.textMuted : "#aaa"
            font.pixelSize: 12
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.surface2 : "#222" }

        Loader {
          id: loader
          Layout.fillWidth: true
          Layout.fillHeight: true
          sourceComponent: tab === "steam" ? steamComp
                          : tab === "lutris" ? lutrisComp
                          : tab === "music" ? musicComp
                          : systemComp
        }

        Component {
          id: systemComp
          S.SettingsSystem { theme: page.theme; sfx: page.sfx; settings: page.settings; launcher: page.launcher }
        }

        Component {
          id: steamComp
          S.SettingsSteam { theme: page.theme; sfx: page.sfx; settings: page.settings; launcher: page.launcher; protonGe: page.protonGe }
        }

        Component {
          id: lutrisComp
          S.SettingsLutris { theme: page.theme; sfx: page.sfx; settings: page.settings; launcher: page.launcher }
        }

        Component {
          id: musicComp
          S.SettingsMusic { theme: page.theme; sfx: page.sfx; settings: page.settings }
        }
      }
    }
  }
}
