import QtQuick
import Quickshell

QtObject {
  id: launcher

  // Inject your Settings object so launcher can consult defaults.
  property var settings

  readonly property string gamescopeFg: Quickshell.shellDir + "/tools/gamescope-fg-lite"

  function _asString(x) {
    return "" + x
  }

  function openSteamUri(uri) {
    if (!uri || uri.length === 0) return
    Quickshell.execDetached(["steam", uri])
  }

  function launchSteam(appid) {
    Quickshell.execDetached(["steam", "-applaunch", _asString(appid)])
  }

  function openSteamUI() {
    // If Steam is already running, this usually focuses it.
    // If not, it launches Steam. gamepadui is optional.
    Quickshell.execDetached(["steam", "-gamepadui"]) 
  }

  function openSteamDownloads() {
    // Best-effort: open the Downloads view inside Steam.
    openSteamUri("steam://open/downloads")
  }

  function openSteamFriends() {
    // Best-effort: opens the Friends UI (Steam client).
    openSteamUri("steam://open/friends")
  }

  function installSteam(appid) {
    // Steam understands many steam:// URLs. Install is commonly supported,
    // but you should test on your build.
    openSteamUri("steam://install/" + _asString(appid))
  }

  function uninstallSteam(appid) {
    openSteamUri("steam://uninstall/" + _asString(appid))
  }

  function launchLutris(gameId) {
    var appid = 2000000000 + parseInt(gameId)
    // Wrap with gamescope-fg-lite to tag windows with STEAM_GAME=<appid>.
    //
    // We also apply a few optional env vars for *non-Steam* launches.
    var envPrefix = ""
    if (settings && settings.mangohudEnabled) {
      envPrefix += "MANGOHUD=1 "
    }
    if (settings && settings.protonWaylandDefault) {
      // WARNING: this is known to break Steam overlay/input for many setups.
      envPrefix += "PROTON_ENABLE_WAYLAND=1 PROTON_USE_WAYLAND=1 "
    }

    var cmd = envPrefix + "lutris lutris:rungameid/" + _asString(gameId)
    Quickshell.execDetached([
      gamescopeFg,
      "--appid", _asString(appid),
      "--",
      "sh", "-c", cmd
    ])
  }

  function openLutrisUI() {
    Quickshell.execDetached(["lutris"])
  }

  function forceSteamInputAppid(appidOrShortcutName) {
    // Steam Browser Protocol: forceinputappid can apply a layout without
    // launching the game. Useful if you're relying on Steam Input for gyro.
    openSteamUri("steam://forceinputappid/" + _asString(appidOrShortcutName))
  }

  function openHHD() {
    // Best-effort: if hhd-ui is installed, launch it. Otherwise do nothing.
    Quickshell.execDetached(["sh", "-c", "command -v hhd-ui >/dev/null 2>&1 && hhd-ui || true"])
  }
}
