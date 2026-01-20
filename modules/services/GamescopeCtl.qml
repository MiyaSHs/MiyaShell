import QtQuick
import Quickshell

QtObject {
  id: ctl

  readonly property string script: Quickshell.shellDir + "/backend/gamescope_ctl.py"

  function setFps(limit) {
    Quickshell.execDetached(["python3", script, "set-fps", "" + limit])
  }

  function setScaler(mode) {
    Quickshell.execDetached(["python3", script, "set-scaler", "" + mode])
  }

  function setFsr(enabled) {
    Quickshell.execDetached(["python3", script, "set-fsr", enabled ? "1" : "0"])
  }

  function setFsrSharpness(sharpness) {
    Quickshell.execDetached(["python3", script, "set-fsr-sharpness", "" + sharpness])
  }
}
