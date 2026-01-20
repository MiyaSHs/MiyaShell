import QtQuick
import Quickshell
import "../utils/FileUtil.js" as FileUtil

QtObject {
  id: store

  // Path to friends.json written by backends.
  property string path: Quickshell.dataDir + "/friends.json"
  property var settings

  property bool ready: false
  property string lastError: ""

  ListModel { id: friendsModel }
  property alias friends: friendsModel

  function _clear() {
    while (friendsModel.count > 0) friendsModel.remove(0)
  }

  function _makeJoinUrl(f) {
    if (!f) return ""
    if ((f.server_ip || "") !== "") {
      return "steam://connect/" + f.server_ip
    }
    if ((f.game_id || "") !== "" && (f.lobby_id || "") !== "") {
      // Lobby join format (appid/lobbySteamID/hostSteamID)
      return "steam://joinlobby/" + f.game_id + "/" + f.lobby_id + "/" + f.steamid
    }
    return ""
  }

  function reload() {
    if (settings && settings.moduleSteam === false) {
      _clear()
      lastError = ""
      ready = true
      return
    }
    lastError = ""
    FileUtil.readJson(path, function(err, obj) {
      _clear()
      if (err) {
        lastError = err
        ready = true
        return
      }
      if (!obj) {
        ready = true
        return
      }
      if (obj.error) {
        lastError = obj.error
      }
      var list = obj.friends || []
      for (var i = 0; i < list.length; i++) {
        var f = list[i]
        var item = {
          provider: f.provider || "",
          steamid: f.steamid || "",
          name: f.name || "",
          avatar: f.avatar || "",
          status: f.status || "offline",
          game_name: f.game_name || "",
          game_id: f.game_id || "",
          server_ip: f.server_ip || "",
          lobby_id: f.lobby_id || "",
          join_url: ""
        }
        item.join_url = _makeJoinUrl(item)
        friendsModel.append(item)
      }
      ready = true
    })
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: store.reload()
  }

  Component.onCompleted: reload()
}
