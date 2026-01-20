import QtQuick
import Quickshell
import "../utils/FileUtil.js" as FileUtil

QtObject {
  id: store

  // Produced by backend/proton_ge_updater.py
  property string jsonPath: Quickshell.dataDir + "/proton_ge.json"

  property bool ready: false
  property string lastError: ""

  // Parsed fields
  property string repo: "GloriousEggroll/proton-ge-custom"
  property string installDir: ""
  property string latestTag: ""
  property bool updateAvailable: false
  property var installed: []
  property string lastNotified: ""

  function reload() {
    lastError = ""
    FileUtil.readJson(jsonPath, function(err, obj) {
      if (err) {
        // Don't spam errors if file doesn't exist yet.
        lastError = "" + err
        ready = false
        return
      }
      repo = obj.repo || repo
      installDir = (obj.install_dir !== undefined) ? obj.install_dir : (obj.installDir || installDir)
      latestTag = (obj.latest && obj.latest.tag) ? obj.latest.tag : (obj.latest_tag || latestTag)
      updateAvailable = !!obj.update_available
      installed = obj.installed || []
      lastNotified = obj.last_notified || ""
      ready = true
    })
  }

  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: store.reload()
  }

  Component.onCompleted: reload()
}
