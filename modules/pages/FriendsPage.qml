import QtQuick
import QtQuick.Layouts
import "../components" as C

Item {
  id: page
  property var theme
  property var sfx
  property var settings
  property var friends
  property var launcher

  anchors.fill: parent

  ColumnLayout {
    anchors.fill: parent
    spacing: theme ? theme.spacing : 12

    Text {
      text: "Friends"
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

          Text {
            text: friends && friends.lastError && friends.lastError.length > 0
                  ? friends.lastError
                  : "Steam friends (presence)"
            color: friends && friends.lastError && friends.lastError.length > 0
                   ? (theme ? theme.warn : "#ffcc66")
                   : (theme ? theme.textMuted : "#aaa")
            font.pixelSize: 14
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }

          C.DeckButton {
            theme: theme
            sfx: page.sfx
            text: "Open Steam Friends"
            compact: true
            onClicked: if (launcher) launcher.openSteamFriends()
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.surface2 : "#222" }

        ListView {
          id: list
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: friends ? friends.friends : null
          clip: true
          spacing: 10

          delegate: Rectangle {
            width: list.width
            height: 86
            radius: theme ? theme.radius : 16
            color: theme ? theme.surface2 : "#1a1a1a"

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              Image {
                source: avatar
                width: 56
                height: 56
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  Text {
                    text: name
                    color: theme ? theme.text : "white"
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: status
                    color: theme ? theme.textMuted : "#aaa"
                    font.pixelSize: 12
                  }
                }

                Text {
                  text: (game_name && game_name.length > 0) ? ("Playing: " + game_name) : ""
                  color: theme ? theme.textMuted : "#aaa"
                  font.pixelSize: 13
                  elide: Text.ElideRight
                  visible: game_name && game_name.length > 0
                }

                Text {
                  text: (join_url && join_url.length > 0)
                        ? (join_url.indexOf("joinlobby") >= 0 ? "Joinable (lobby)" : "Joinable (server)")
                        : ""
                  color: theme ? theme.good : "#5bd6a0"
                  font.pixelSize: 12
                  visible: join_url && join_url.length > 0
                }
              }

              ColumnLayout {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                C.DeckButton {
                  theme: theme
                  sfx: page.sfx
                  text: "Join"
                  compact: true
                  visible: join_url && join_url.length > 0
                  onClicked: if (launcher) launcher.openSteamUri(join_url)
                }
              }
            }
          }
        }
      }
    }
  }
}
