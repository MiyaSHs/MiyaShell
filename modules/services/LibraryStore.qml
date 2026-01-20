import QtQuick
import Quickshell
import "../utils/FileUtil.js" as FileUtil

QtObject {
  id: lib

  property string steamJson: Quickshell.dataDir + "/steam_library.json"
  property string lutrisJson: Quickshell.dataDir + "/lutris_library.json"

  // Inject Settings for filters.
  property var settings

  property bool ready: false
  property string lastError: ""

  ListModel { id: steamModel }
  ListModel { id: lutrisModel }
  ListModel { id: allModel }

  property alias steam: steamModel
  property alias lutris: lutrisModel
  property alias all: allModel

  function _clear(model) {
    while (model.count > 0) model.remove(0)
  }

  function _pushSteam(g) {
    steamModel.append({
      provider: "steam",
      id: g.appid,
      appid: g.appid,
      name: g.name,
      installed: !!g.installed,
      cover: g.cover || "",
      size_on_disk: g.size_on_disk || 0
    })
  }

  function _pushLutris(g) {
    // We keep the raw object around because Lutris fields vary by version.
    var name = g.name || g.title || ("Lutris #" + g.id)
    lutrisModel.append({
      provider: "lutris",
      id: g.id,
      name: name,
      slug: g.slug || "",
      runner: g.runner || "",
      platform: g.platform || "",
      installed: (g.installed === undefined) ? true : !!g.installed,
      cover: g.cover || g.banner || g.icon || "",
      raw: g
    })
  }

  function _rebuildAll() {
    _clear(allModel)

    // Steam first (installed first, then uninstalled if allowed)
    for (var i = 0; i < steamModel.count; i++) {
      var it = steamModel.get(i)
      if (!it.installed && settings && !settings.showSteamUninstalled) continue
      allModel.append(it)
    }

    // Lutris
    for (var j = 0; j < lutrisModel.count; j++) {
      allModel.append(lutrisModel.get(j))
    }

    // Sort by name (casefold-ish)
    // QML ListModel doesn't have built-in sort; do a manual rebuild.
    var tmp = []
    for (var k = 0; k < allModel.count; k++) tmp.push(allModel.get(k))
    tmp.sort(function(a, b) {
      return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase())
    })
    _clear(allModel)
    for (var k2 = 0; k2 < tmp.length; k2++) allModel.append(tmp[k2])
  }

  function reload() {
    lastError = ""
    var pending = 0

    function doneOne() {
      pending -= 1
      if (pending <= 0) {
        _rebuildAll()
        ready = true
      }
    }


    var wantSteam = (!settings) || settings.moduleSteam
    var wantLutris = (!settings) || settings.moduleLutris

    // Always clear models so UI reflects module toggles immediately.
    _clear(steamModel)
    _clear(lutrisModel)

    if (wantSteam) pending += 1
    if (wantLutris) pending += 1

    if (pending === 0) {
      _rebuildAll()
      ready = true
      return
    }

    if (wantSteam) {
      FileUtil.readJson(steamJson, function(err, obj) {
        _clear(steamModel)
        if (!err && obj && obj.games) {
          for (var i = 0; i < obj.games.length; i++) {
            _pushSteam(obj.games[i])
          }
        } else {
          if (err) lastError = "Steam: " + err
        }
        doneOne()
      })
    }

    if (wantLutris) {
      FileUtil.readJson(lutrisJson, function(err, obj) {
        _clear(lutrisModel)
        if (!err && obj && obj.games) {
          for (var i = 0; i < obj.games.length; i++) {
            _pushLutris(obj.games[i])
          }
        } else {
          if (err) lastError = (lastError ? lastError + " | " : "") + "Lutris: " + err
        }
        doneOne()
      })
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: lib.reload()
  }

  Component.onCompleted: reload()
}
