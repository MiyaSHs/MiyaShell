import QtQuick
import "../utils/FileUtil.js" as FileUtil

QtObject {
  id: store

  // Set this to Backend.downloadsJson
  property string path: ""
  property var settings

  property string generatedAt: ""
  property var downloads: []
  property string error: ""

  function refresh() {
    if (settings && settings.moduleSteam === false) {
      store.generatedAt = ""
      store.downloads = []
      store.error = "Steam module disabled"
      return
    }
    if (!path || path.length === 0) return
    FileUtil.readJson(path, function(err, obj) {
      if (err) {
        store.error = "" + err
        return
      }
      store.error = ""
      store.generatedAt = obj.generated_at || ""
      store.downloads = obj.downloads || []
    })
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: store.refresh()
  }

  Component.onCompleted: refresh()
}
