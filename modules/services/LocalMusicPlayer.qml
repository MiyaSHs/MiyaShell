import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: player

  // Current absolute file path
  property string currentPath: ""

  property bool playing: proc.running
  property string lastError: ""

  // Basic transport
  function play(path) {
    if (!path || path.length === 0) return
    currentPath = path
    _start()
  }

  function stop() {
    if (!proc.running) return
    proc.running = false
  }

  function toggle() {
    if (proc.running) {
      stop()
    } else if (currentPath && currentPath.length > 0) {
      _start()
    }
  }

  function _start() {
    lastError = ""
    // Restart if currently playing.
    if (proc.running) proc.running = false
    proc.command = [
      "mpv",
      "--no-video",
      "--audio-display=no",
      "--force-window=no",
      "--quiet",
      "--",
      currentPath
    ]
    proc.running = true
  }

  Process {
    id: proc
    running: false
    command: ["true"]

    onExited: function(code, status) {
      // status is platform-specific; keep message simple.
      if (code === 127) {
        lastError = "mpv not found (install media-video/mpv)"
      } else if (code !== 0 && code !== 143) {
        lastError = "Player exited (code " + code + ")"
      }
    }
  }
}
