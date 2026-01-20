import QtQuick

QtObject {
  id: store

  // Inject Settings; we persist to settings.recentJson
  property var settings
  property int maxItems: 24

  ListModel { id: model }
  property alias items: model

  function _clear() {
    while (model.count > 0) model.remove(0)
  }

  function load() {
    _clear()
    if (!settings) return
    var raw = settings.recentJson || "[]"
    var arr = []
    try { arr = JSON.parse(raw) } catch (e) { arr = [] }
    if (!arr || arr.length === 0) return
    for (var i = 0; i < arr.length; i++) {
      var it = arr[i] || {}
      model.append({
        provider: it.provider || "",
        id: it.id || "",
        name: it.name || "",
        cover: it.cover || "",
        ts: it.ts || 0
      })
    }
  }

  function save() {
    if (!settings) return
    var arr = []
    for (var i = 0; i < model.count; i++) {
      var it = model.get(i)
      arr.push({ provider: it.provider, id: it.id, name: it.name, cover: it.cover, ts: it.ts })
    }
    settings.recentJson = JSON.stringify(arr)
  }

  function recordLaunch(game) {
    if (!game) return
    var provider = game.provider || ""
    var id = "" + (game.appid !== undefined ? game.appid : game.id)
    var name = game.name || ""
    var cover = game.cover || ""
    var ts = Date.now()

    // Deduplicate
    for (var i = 0; i < model.count; i++) {
      var it = model.get(i)
      if (it.provider === provider && ("" + it.id) === id) {
        model.remove(i)
        break
      }
    }

    model.insert(0, { provider: provider, id: id, name: name, cover: cover, ts: ts })
    while (model.count > maxItems) model.remove(model.count - 1)
    save()
  }

  Component.onCompleted: load()
}
