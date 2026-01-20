import QtQuick
import "../utils/FileUtil.js" as FileUtil

QtObject {
  id: store

  property string path: ""

  property string generatedAt: ""
  property var libraries: []
  property string error: ""

  function refresh() {
    if (!path || path.length === 0) return
    FileUtil.readJson(path, function(err, obj) {
      if (err) {
        store.error = "" + err
        return
      }
      store.error = ""
      store.generatedAt = obj.generated_at || ""
      store.libraries = obj.libraries || []
    })
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: store.refresh()
  }

  Component.onCompleted: refresh()
}
