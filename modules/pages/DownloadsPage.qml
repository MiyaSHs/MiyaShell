import QtQuick
import QtQuick.Layouts
import "../components" as C

Item {
  id: page
  property var theme
  property var sfx
  property var downloads
  property var launcher

  anchors.fill: parent

  ColumnLayout {
    anchors.fill: parent
    spacing: theme ? theme.spacing : 12

    Text {
      text: "Downloads"
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

        Text {
          text: downloads && downloads.error && downloads.error.length > 0 ? ("Error: " + downloads.error) : ""
          color: theme ? theme.bad : "#f66"
          visible: downloads && downloads.error && downloads.error.length > 0
          wrapMode: Text.Wrap
          Layout.fillWidth: true
        }

        ListView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: downloads ? downloads.downloads : []

          delegate: Rectangle {
            width: ListView.view.width
            height: 74
            radius: theme ? theme.radius : 14
            color: theme ? theme.surface2 : "#222"

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 12

              ColumnLayout {
                Layout.fillWidth: true

                Text {
                  text: modelData.name + " (" + modelData.appid + ")"
                  color: theme ? theme.text : "white"
                  font.pixelSize: 16
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 10
                  radius: 5
                  color: Qt.rgba(1, 1, 1, 0.10)

                  Rectangle {
                    width: Math.max(2, parent.width * (modelData.progress || 0))
                    height: parent.height
                    radius: 5
                    color: theme ? theme.accent : "#29a3ff"
                  }
                }

                Text {
                  text: Math.round((modelData.progress || 0) * 100) + "%  •  Remaining: " + formatBytes(modelData.bytes_to_download || 0)
                  color: theme ? theme.textMuted : "#aaa"
                  font.pixelSize: 13
                }
              }

              C.DeckButton {
                theme: theme
                sfx: page.sfx
                text: "Open Steam"
                compact: true
                onClicked: launcher.openSteamDownloads()
              }
            }

            function formatBytes(n) {
              n = parseInt(n)
              if (!n || n <= 0) return "0 B"
              var units = ["B", "KiB", "MiB", "GiB", "TiB"]
              var i = 0
              var v = n
              while (v > 1024 && i < units.length - 1) {
                v = v / 1024.0
                i++
              }
              return v.toFixed(i === 0 ? 0 : 1) + " " + units[i]
            }
          }
        }

        // Empty state
        Text {
          Layout.fillWidth: true
          visible: (downloads && downloads.downloads && downloads.downloads.length === 0)
          text: "No active downloads detected."
          color: theme ? theme.textMuted : "#aaa"
          font.pixelSize: 14
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
