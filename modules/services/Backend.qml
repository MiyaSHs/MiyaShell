import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: backend

  // Inject Settings so we can enable/disable modules.
  property var settings

  // Backends write JSON into Quickshell's per-shell data dir.
  // QuickshellGlobal exposes dataDir/shellDir. (See Quickshell docs.)
  property string dataDir: Quickshell.dataDir
  property string shellDir: Quickshell.shellDir

  property string steamJson: dataDir + "/steam_library.json"
  property string lutrisJson: dataDir + "/lutris_library.json"
  property string downloadsJson: dataDir + "/steam_downloads.json"
  property string storageJson: dataDir + "/storage.json"
  property string friendsJson: dataDir + "/friends.json"
  property string musicJson: dataDir + "/local_music.json"
  property string protonGeJson: dataDir + "/proton_ge.json"

  property bool enabled: true

  function _steamEnabled() {
    return backend.enabled && (!backend.settings || backend.settings.moduleSteam)
  }

  function _lutrisEnabled() {
    return backend.enabled && (!backend.settings || backend.settings.moduleLutris)
  }

  function _protonGeEnabled() {
    // Proton-GE is useful for Steam games and also for Lutris when using the GE-Proton runner.
    var want = backend.enabled && (!backend.settings || backend.settings.protonGeUpdaterEnabled)
    var steamOrLutris = (!backend.settings) || backend.settings.moduleSteam || backend.settings.moduleLutris
    return want && steamOrLutris
  }

  // Steam library generator (installed games offline; optional owned games via Steam Web API).
  Process {
    id: steamProc
    running: backend._steamEnabled()
    command: [
      "python3",
      backend.shellDir + "/backend/steam_library.py",
      "--out", backend.steamJson,
      "--watch",
      "--interval", "2"
    ]
  }

  // Lutris library generator.
  Process {
    id: lutrisProc
    running: backend._lutrisEnabled()
    command: [
      "python3",
      backend.shellDir + "/backend/lutris_library.py",
      "--out", backend.lutrisJson,
      "--watch",
      "--interval", "2"
    ]
  }

  // Steam downloads / updates (best-effort derived from app manifests)
  Process {
    id: downloadsProc
    running: backend._steamEnabled()
    command: [
      "python3",
      backend.shellDir + "/backend/steam_downloads.py",
      "--out", backend.downloadsJson,
      "--watch",
      "--interval", "2"
    ]
  }

  // Storage usage report (periodic)
  Process {
    id: storageProc
    running: backend.enabled
    command: [
      "python3",
      backend.shellDir + "/backend/storage_report.py",
      "--out", backend.storageJson,
      "--watch",
      "--interval", "15"
    ]
  }

  // Friends list (module-driven). Currently only Steam is supported.
  Process {
    id: friendsProc
    running: backend._steamEnabled()
    command: [
      "python3",
      backend.shellDir + "/backend/steam_friends.py",
      "--out", backend.friendsJson,
      "--watch",
      "--interval", "10",
      "--api-key", (backend.settings ? backend.settings.steamApiKey : ""),
      "--steamid", (backend.settings ? backend.settings.steamId64 : "")
    ]
  }

  // Local music scanner (built-in provider)
  Process {
    id: musicProc
    running: backend.enabled
    command: [
      "python3",
      backend.shellDir + "/backend/local_music.py",
      "--out", backend.musicJson,
      "--watch",
      "--interval", "10",
      "--root", (backend.settings ? backend.settings.musicRoot : "")
    ]
  }

  // Proton-GE updater (best-effort, optional)
  Process {
    id: protonGeProc
    running: backend._protonGeEnabled()

    // NOTE: command is a binding, so changes to Settings can cause a restart.
    command: {
      var cmd = [
        "python3",
        backend.shellDir + "/backend/proton_ge_updater.py",
        "--out", backend.protonGeJson,
        "--watch",
        "--interval", "" + ((backend.settings && backend.settings.protonGeCheckIntervalSec) ? backend.settings.protonGeCheckIntervalSec : 3600),
        "--repo", (backend.settings ? backend.settings.protonGeRepo : "GloriousEggroll/proton-ge-custom"),
        "--keep", "" + ((backend.settings && backend.settings.protonGeKeepVersions !== undefined) ? backend.settings.protonGeKeepVersions : 2)
      ]

      if (backend.settings && backend.settings.protonGeInstallDir && backend.settings.protonGeInstallDir.length > 0) {
        cmd.push("--install-dir")
        cmd.push(backend.settings.protonGeInstallDir)
      }

      // Notifications are on by default.
      if (!backend.settings || backend.settings.protonGeNotify) {
        cmd.push("--notify")
      }

      if (backend.settings && backend.settings.protonGeAutoInstall) {
        cmd.push("--auto-install")
      }

      return cmd
    }
  }
}
