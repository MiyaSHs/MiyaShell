import QtQuick
import QtQuick.Layouts
import "../components" as C

Item {
  id: page
  property var theme
  property var sfx
  property var storage

  anchors.fill: parent

  ColumnLayout {
    anchors.fill: parent
    spacing: theme ? theme.spacing : 12

    Text {
      text: "Storage"
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

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true

        Column {
          id: col
          width: parent.width
          spacing: theme ? theme.spacing : 14
          anchors.margins: theme ? theme.padding : 14
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top

          Text {
            text: storage && storage.error && storage.error.length > 0 ? ("Error: " + storage.error) : ""
            color: theme ? theme.bad : "#f66"
            visible: storage && storage.error && storage.error.length > 0
            wrapMode: Text.Wrap
            width: parent.width
          }

          Repeater {
            model: storage ? storage.libraries : []

            delegate: Rectangle {
              width: parent.width
              height: 140
              radius: theme ? theme.radius : 16
              color: theme ? theme.surface2 : "#222"

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                  text: modelData.path
                  color: theme ? theme.text : "white"
                  font.pixelSize: 14
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 12
                  radius: 6
                  color: Qt.rgba(1, 1, 1, 0.10)

                  Rectangle {
                    width: Math.max(2, parent.width * usedFrac(modelData))
                    height: parent.height
                    radius: 6
                    color: theme ? theme.accent : "#29a3ff"
                  }
                }

                RowLayout {
                  Layout.fillWidth: true

                  ColumnLayout {
                    Layout.fillWidth: true
                    Text {
                      text: "Used: " + fmt(modelData.fs_used) + " / " + fmt(modelData.fs_total)
                      color: theme ? theme.textMuted : "#aaa"
                      font.pixelSize: 13
                    }
                    Text {
                      text: "Steam: " + fmt(modelData.steam_bytes) + " • Other: " + fmt(modelData.other_bytes)
                      color: theme ? theme.textMuted : "#aaa"
                      font.pixelSize: 13
                    }
                  }

                  Item { Layout.fillWidth: true }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  C.DeckButton {
                    theme: theme
                    text: "Details"
                    compact: true
                    onClicked: detailsOpen = !detailsOpen
                  }

                  Item { Layout.fillWidth: true }
                }

                Column {
                  Layout.fillWidth: true
                  visible: detailsOpen

                  Text { text: "Breakdown"; color: theme ? theme.text : "white"; font.bold: true; font.pixelSize: 13 }
                  Text { text: "common: " + fmt(modelData.steam_breakdown.common); color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 13 }
                  Text { text: "compatdata: " + fmt(modelData.steam_breakdown.compatdata); color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 13 }
                  Text { text: "shadercache: " + fmt(modelData.steam_breakdown.shadercache); color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 13 }
                  Text { text: "workshop: " + fmt(modelData.steam_breakdown.workshop); color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 13 }
                  Text { text: "downloading: " + fmt(modelData.steam_breakdown.downloading); color: theme ? theme.textMuted : "#aaa"; font.pixelSize: 13 }
                }
              }

              property bool detailsOpen: false

              function usedFrac(d) {
                var total = (d.fs_total || 0)
                var used = (d.fs_used || 0)
                if (total <= 0) return 0
                return Math.max(0.0, Math.min(1.0, used / total))
              }

              function fmt(n) {
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

          Text {
            visible: storage && storage.libraries && storage.libraries.length === 0
            text: "No Steam libraries detected yet."
            color: theme ? theme.textMuted : "#aaa"
            font.pixelSize: 14
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }

          Item { height: 24; width: 1 }
        }
      }
    }
  }
}
