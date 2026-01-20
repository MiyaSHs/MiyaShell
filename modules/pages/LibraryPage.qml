import QtQuick
import QtQuick.Layouts
import "../components" as C

Item {
  id: page
  property var theme
  property var sfx
  property var settings
  property var library
  property var launcher
  property var recent

  anchors.fill: parent

  property var providerTabs: ([])
  property string providerTab: "" // steam|lutris
  property string steamTab: "installed" // installed|uninstalled|all

  property var currentItems: ([])

  function rebuildProviderTabs() {
    var tabs = []
    if (!settings || settings.moduleSteam) tabs.push({ id: "steam", title: "STEAM" })
    if (!settings || settings.moduleLutris) tabs.push({ id: "lutris", title: "LUTRIS" })
    providerTabs = tabs

    if (tabs.length === 0) {
      providerTab = ""
      return
    }
    var ok = false
    for (var i = 0; i < tabs.length; i++) if (tabs[i].id === providerTab) ok = true
    if (!ok) providerTab = tabs[0].id
  }

  function _sortedByName(arr) {
    arr.sort(function(a, b) {
      return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase())
    })
    return arr
  }

  function rebuildCurrent() {
    var out = []
    if (!library) {
      currentItems = []
      return
    }

    if (providerTab === "steam") {
      if (!library.steam) { currentItems = []; return }
      for (var i = 0; i < library.steam.count; i++) {
        var it = library.steam.get(i)
        if (steamTab === "installed") {
          if (it.installed) out.push(it)
        } else if (steamTab === "uninstalled") {
          if (!it.installed) out.push(it)
        } else {
          out.push(it)
        }
      }
      currentItems = _sortedByName(out)
      return
    }

    if (providerTab === "lutris") {
      if (!library.lutris) { currentItems = []; return }
      for (var j = 0; j < library.lutris.count; j++) out.push(library.lutris.get(j))
      currentItems = _sortedByName(out)
      return
    }

    currentItems = []
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      rebuildProviderTabs()
      rebuildCurrent()
    }
  }

  Component.onCompleted: {
    rebuildProviderTabs()
    rebuildCurrent()
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: theme ? theme.spacing : 18

    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      Text {
        text: "Library"
        color: theme ? theme.text : "white"
        font.pixelSize: 22
        font.bold: true
        Layout.fillWidth: true
      }

      C.DeckButton {
        theme: theme
        sfx: page.sfx
        text: "Rescan"
        compact: true
        onClicked: if (library) library.reload()
      }
    }

    Text {
      visible: library && library.lastError !== ""
      text: library ? ("Data: " + library.lastError) : ""
      color: theme ? theme.warn : "orange"
      font.pixelSize: 13
      wrapMode: Text.Wrap
      Layout.fillWidth: true
    }

    Text {
      visible: settings && (!settings.moduleSteam) && (!settings.moduleLutris)
      text: "No modules enabled. Enable Steam and/or Lutris in Settings → Modules to populate your library."
      color: theme ? theme.textMuted : "#aaa"
      font.pixelSize: 13
      wrapMode: Text.Wrap
      Layout.fillWidth: true
    }

    // Provider tabs (STEAM / LUTRIS)
    C.DeckTabBar {
      id: providers
      theme: page.theme
      sfx: page.sfx
      tabs: page.providerTabs
      currentId: page.providerTab
      onSelected: {
        page.providerTab = tabId
        page.rebuildCurrent()
      }
      Layout.fillWidth: true
      visible: providerTabs.length > 0
    }

    // Steam subtabs
    C.DeckTabBar {
      id: steamTabs
      theme: page.theme
      sfx: page.sfx
      tabs: [
        { id: "installed", title: "Installed" },
        { id: "uninstalled", title: "Uninstalled" },
        { id: "all", title: "All" }
      ]
      currentId: page.steamTab
      onSelected: {
        page.steamTab = tabId
        if (settings) settings.showSteamUninstalled = (tabId !== "installed")
        page.rebuildCurrent()
      }
      Layout.fillWidth: true
      visible: page.providerTab === "steam" && (!settings || settings.moduleSteam)
    }

    GridView {
      id: grid
      Layout.fillWidth: true
      Layout.fillHeight: true
      cellWidth: 228
      cellHeight: 330
      model: page.currentItems
      clip: true
      focus: true

      delegate: C.GameCard {
        theme: page.theme
        sfx: page.sfx
        game: modelData
        onLaunchRequested: {
          if (recent) recent.recordLaunch(game)
          if (game.provider === "steam") launcher.launchSteam(game.appid)
          else if (game.provider === "lutris") launcher.launchLutris(game.id)
        }
        onInstallRequested: {
          if (game.provider === "steam") launcher.installSteam(game.appid)
        }
      }
    }
  }
}
