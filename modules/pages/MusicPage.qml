import QtQuick
import QtQuick.Layouts
import "../components" as C
import "../services" as Svc

Item {
  id: page
  property var theme
  property var sfx
  property var settings
  property var music

  anchors.fill: parent

  Svc.LocalMusicPlayer { id: player }

  ColumnLayout {
    anchors.fill: parent
    spacing: theme ? theme.spacing : 12

    Text {
      text: "Music"
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

        C.DeckTabBar {
          theme: page.theme
          tabs: [ { id: "local", title: "LOCAL" } ]
          currentId: "local"
          onSelected: { }
          Layout.fillWidth: true
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            text: (music && music.lastError && music.lastError.length > 0)
                  ? music.lastError
                  : "Local music (~/Music)"
            color: (music && music.lastError && music.lastError.length > 0)
                   ? (theme ? theme.warn : "#ffcc66")
                   : (theme ? theme.textMuted : "#aaa")
            font.pixelSize: 14
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }

          C.DeckButton {
            theme: theme
            sfx: page.sfx
            text: "Rescan"
            compact: true
            onClicked: if (music) music.reload()
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.surface2 : "#222" }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 12

          // Albums (folder groups)
          Rectangle {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            radius: theme ? theme.radius : 16
            color: theme ? theme.surface2 : "#1a1a1a"

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 8

              Text {
                text: "Albums (folders)"
                color: theme ? theme.text : "white"
                font.pixelSize: 16
                font.bold: true
              }

              ListView {
                id: albumsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: false
                spacing: 6
                model: music ? music.albums : null

                delegate: Rectangle {
                  width: albumsList.width
                  height: 44
                  radius: 12
                  color: (music && music.selectedAlbum === album_id) ? (theme ? theme.accent : "#2aa") : (theme ? theme.surface : "#111")

                  MouseArea {
                    anchors.fill: parent
                    onClicked: if (music) music.selectAlbum(album_id)
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Text {
                      text: title
                      color: theme ? theme.text : "white"
                      font.pixelSize: 13
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      text: track_count
                      color: theme ? theme.textMuted : "#aaa"
                      font.pixelSize: 12
                    }
                  }
                }
              }
            }
          }

          // Tracks
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: theme ? theme.radius : 16
            color: theme ? theme.surface2 : "#1a1a1a"

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 8

              RowLayout {
                Layout.fillWidth: true

                Text {
                  text: "Tracks"
                  color: theme ? theme.text : "white"
                  font.pixelSize: 16
                  font.bold: true
                  Layout.fillWidth: true
                }

                Text {
                  text: player.playing ? "Playing" : ""
                  color: theme ? theme.good : "#5bd6a0"
                  font.pixelSize: 12
                  visible: player.playing
                }
              }

              ListView {
                id: tracksList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: false
                spacing: 6
                model: music ? music.tracks : null

                delegate: Rectangle {
                  width: tracksList.width
                  height: 44
                  radius: 12
                  color: (player.currentPath === path) ? (theme ? theme.accent2 : "#77f") : (theme ? theme.surface : "#111")

                  MouseArea {
                    anchors.fill: parent
                    onClicked: player.play(path)
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Text {
                      text: title
                      color: theme ? theme.text : "white"
                      font.pixelSize: 13
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      text: ext
                      color: theme ? theme.textMuted : "#aaa"
                      font.pixelSize: 12
                    }
                  }
                }
              }

              Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.surface : "#222" }

              // Transport
              RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                  text: player.currentPath && player.currentPath.length > 0 ? player.currentPath.split('/').pop() : "No track selected"
                  color: theme ? theme.textMuted : "#aaa"
                  font.pixelSize: 13
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                C.DeckButton {
                  theme: theme
                  sfx: page.sfx
                  text: player.playing ? "Pause" : "Play"
                  compact: true
                  enabled: player.currentPath && player.currentPath.length > 0
                  onClicked: player.toggle()
                }

                C.DeckButton {
                  theme: theme
                  sfx: page.sfx
                  text: "Stop"
                  compact: true
                  enabled: player.playing
                  onClicked: player.stop()
                }
              }

              Text {
                text: player.lastError
                color: theme ? theme.warn : "#ffcc66"
                font.pixelSize: 12
                visible: player.lastError && player.lastError.length > 0
                wrapMode: Text.Wrap
                Layout.fillWidth: true
              }
            }
          }
        }
      }
    }
  }
}
