// MiyaShell Quickshell UI
//
// Philosophy:
// - Keep the UI in Quickshell/QML.
// - Keep heavy lifting (Steam/Lutris scanning) in tiny Python scripts.
// - Keep game launching detached so the UI stays alive.

import QtQuick
import Quickshell
import Quickshell.Wayland

import "modules" as M
import "modules/config" as Cfg
import "modules/services" as Svc
import "modules/windows" as Win

ShellRoot {
  id: root

  // Shared singletons/objects
  M.AppState { id: state }
  Cfg.Settings { id: settings }
  Cfg.ThemeManager {
    id: theme
    themeId: settings.themeId
    variant: settings.themeVariant
    accentKey: settings.themeAccent
    reduceMotion: settings.reduceMotion
  }

  // Global font (nerd fonts by default)
  function applyFont() {
    if (!settings) return
    var f = Qt.application.font
    if (settings.fontFamily && settings.fontFamily.length > 0 && settings.fontFamily !== "System Default")
      f.family = settings.fontFamily
    f.pixelSize = settings.fontPixelSize > 0 ? settings.fontPixelSize : 16
    Qt.application.font = f
  }
  Component.onCompleted: applyFont()
  Connections {
    target: settings
    function onFontFamilyChanged() { root.applyFont() }
    function onFontPixelSizeChanged() { root.applyFont() }
  }

  // UI sound effects
  Svc.Sfx { id: sfx; settings: settings }

  // Background JSON generators
  Svc.Backend {
    id: backend
    settings: settings
  }

  // Library loaders
  Svc.LibraryStore {
    id: library
    settings: settings
  }

  // Downloads + storage loaders
  Svc.DownloadsStore {
    id: downloads
    path: backend.downloadsJson
    settings: settings
  }
  Svc.StorageStore {
    id: storage
    path: backend.storageJson
  }

  // Friends (module-driven; Steam adds friends, other modules can later add Discord, etc.)
  Svc.FriendsStore {
    id: friends
    path: backend.friendsJson
    settings: settings
  }

  // Music (built-in provider: local folder scanner)
  Svc.MusicStore {
    id: music
    path: backend.musicJson
    settings: settings
  }

  // Proton-GE status (best-effort)
  Svc.ProtonGeStore { id: protonGe }

  // Launcher helpers
  Svc.Launcher {
    id: launcher
    settings: settings
  }

  // Home recents
  Svc.RecentStore {
    id: recent
    settings: settings
  }

  // gamescope runtime control (best-effort)
  Svc.GamescopeCtl { id: gamescopeCtl }

  // One window per screen (handhelds: typically 1)
  Variants {
    model: Quickshell.screens

    delegate: Component {
      Scope {
        required property var modelData
        property var screen: modelData

        Variants {
          model: screen.outputs

          delegate: Component {
            Scope {
              required property WlOutput modelData
              property WlOutput output: modelData

              Win.LauncherWindow {
                output: output
                theme: theme
                settings: settings
                sfx: sfx
                appState: state
                library: library
                downloads: downloads
                storage: storage
                friends: friends
                music: music
                launcher: launcher
                recent: recent
                protonGe: protonGe
              }

              Win.QuickAccessWindow {
                output: output
                theme: theme
                settings: settings
                sfx: sfx
                appState: state
                launcher: launcher
                recent: recent
                gamescopeCtl: gamescopeCtl
              }
            }
          }
        }
      }
    }
  }
}
