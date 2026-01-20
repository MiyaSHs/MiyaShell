import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../components" as C

Item {
  id: root
  property var theme
  property var sfx
  property var settings
  property var launcher
  property var protonGe

  anchors.fill: parent

  readonly property string protonGeJsonPath: Quickshell.dataDir + "/proton_ge.json"
  readonly property string protonGeScript: Quickshell.shellDir + "/backend/proton_ge_updater.py"

  function _runProtonGe(args) {
    var cmd = [
      "python3",
      protonGeScript,
      "--out", protonGeJsonPath,
      "--repo", (settings ? settings.protonGeRepo : "GloriousEggroll/proton-ge-custom"),
      "--keep", "" + (settings ? settings.protonGeKeepVersions : 2)
    ]

    if (settings && settings.protonGeInstallDir && settings.protonGeInstallDir.length > 0) {
      cmd.push("--install-dir")
      cmd.push(settings.protonGeInstallDir)
    }

    // Best-effort notifications
    if (!settings || settings.protonGeNotify) cmd.push("--notify")

    for (var i = 0; i < args.length; i++) cmd.push(args[i])

    Quickshell.execDetached(cmd)
  }

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight
    clip: true

    Column {
      id: col
      width: parent.width
      spacing: theme ? theme.spacing : 12
      anchors.margins: theme ? theme.padding : 14
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top

      Text {
        text: "Steam"
        color: theme ? theme.text : "white"
        font.pixelSize: 18
        font.bold: true
      }

      C.DeckToggle {
        theme: theme
        label: "Show uninstalled Steam titles (if Web API enrichment is enabled)"
        checked: settings ? settings.showSteamUninstalled : true
        onToggled: if (settings) settings.showSteamUninstalled = checked
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Friends presence (Steam Web API)"
        color: theme ? theme.text : "white"
        font.pixelSize: 16
        font.bold: true
      }

      Text {
        text: "Steam doesn't provide a stable local friends API. If you want Friends presence + Join buttons, add a Web API key + your SteamID64 here.\n\nIf you prefer not to store this, you can set STEAM_API_KEY and STEAM_ID64 as environment variables instead."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckTextField {
        theme: theme
        label: "STEAM_API_KEY"
        placeholder: "(optional)"
        text: settings ? settings.steamApiKey : ""
        onChanged: if (settings) settings.steamApiKey = text
      }

      C.DeckTextField {
        theme: theme
        label: "STEAM_ID64"
        placeholder: "7656119..."
        text: settings ? settings.steamId64 : ""
        onChanged: if (settings) settings.steamId64 = text
      }

      Row {
        spacing: 10
        C.DeckButton {
          theme: theme
          text: "Open API Key Page"
          onClicked: Quickshell.execDetached(["xdg-open", "https://steamcommunity.com/dev/apikey"]) 
        }
        C.DeckButton {
          theme: theme
          text: "Open Steam Friends"
          onClicked: if (launcher) launcher.openSteamFriends()
        }
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Steam Input"
        color: theme ? theme.text : "white"
        font.pixelSize: 16
        font.bold: true
      }

      Text {
        text: "If you're using Steam Input for gyro, you can pre-apply a layout to an AppID without launching it (useful for non-Steam shortcuts)."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckButton {
        theme: theme
        text: "Force Steam Input layout: 769 (Steam Deck UI)"
        onClicked: if (launcher) launcher.forceSteamInputAppid(769)
      }

      Rectangle { height: 1; width: parent.width; color: theme ? theme.surface2 : "#222" }

      Text {
        text: "Proton-GE (GE-Proton)"
        color: theme ? theme.text : "white"
        font.pixelSize: 16
        font.bold: true
      }

      Text {
        text: "MiyaShell can check GitHub releases for GE-Proton and install it into Steam's compatibilitytools.d. This is useful if you're experimenting with PROTON_USE_WAYLAND / NTSYNC builds.\n\nAfter installing/updating, restart Steam to see the new Proton in the Compatibility dropdown."
        color: theme ? theme.textMuted : "#aaa"
        font.pixelSize: 14
        wrapMode: Text.Wrap
        width: parent.width
      }

      C.DeckToggle {
        theme: theme
        label: "Enable Proton-GE update checker"
        checked: settings ? settings.protonGeUpdaterEnabled : true
        onToggled: if (settings) settings.protonGeUpdaterEnabled = checked
      }

      C.DeckToggle {
        theme: theme
        label: "Notify when a new GE-Proton release is available (notify-send)"
        checked: settings ? settings.protonGeNotify : true
        onToggled: if (settings) settings.protonGeNotify = checked
      }

      C.DeckToggle {
        theme: theme
        label: "Auto-install updates (downloads in the background)"
        checked: settings ? settings.protonGeAutoInstall : false
        onToggled: if (settings) settings.protonGeAutoInstall = checked
      }

      C.DeckTextField {
        theme: theme
        label: "GitHub repo"
        placeholder: "GloriousEggroll/proton-ge-custom"
        text: settings ? settings.protonGeRepo : "GloriousEggroll/proton-ge-custom"
        onChanged: if (settings) settings.protonGeRepo = text
      }

      C.DeckTextField {
        theme: theme
        label: "Install directory override (optional)"
        placeholder: "(auto-discover Steam's compatibilitytools.d)"
        text: settings ? settings.protonGeInstallDir : ""
        onChanged: if (settings) settings.protonGeInstallDir = text
      }

      Row {
        spacing: 10
        C.DeckButton {
          theme: theme
          text: "Check now"
          onClicked: _runProtonGe([])
        }
        C.DeckButton {
          theme: theme
          text: "Install latest"
          onClicked: _runProtonGe(["--auto-install"])
        }
        C.DeckButton {
          theme: theme
          text: "Open Steam Settings"
          onClicked: if (launcher) launcher.openSteamUri("steam://open/settings")
        }
      }

      Rectangle {
        width: parent.width
        radius: theme ? theme.radius : 14
        color: theme ? theme.surface2 : "#222"
        height: statusCol.implicitHeight + (theme ? theme.padding : 14) * 2

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 8
          radius: 4
          color: (protonGe && protonGe.updateAvailable) ? (theme ? theme.accent : "#89dceb") : "transparent"
        }

        Column {
          id: statusCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: theme ? theme.padding : 14
          spacing: 6

          Text {
            text: (protonGe && protonGe.ready) ? "Latest: " + (protonGe.latestTag || "(unknown)") : "Latest: (checking...)"
            color: theme ? theme.text : "white"
            font.pixelSize: 14
            font.bold: true
          }

          Text {
            text: (protonGe && protonGe.ready) ? ("Installed: " + (protonGe.installed.length > 0 ? protonGe.installed.join(", ") : "(none)")) : ""
            color: theme ? theme.textMuted : "#aaa"
            font.pixelSize: 13
            wrapMode: Text.Wrap
            width: parent.width
            visible: protonGe && protonGe.ready
          }

          Text {
            text: (protonGe && protonGe.ready && protonGe.updateAvailable) ? "Update available. You can install it here, then restart Steam." : "Up to date."
            color: (protonGe && protonGe.ready && protonGe.updateAvailable) ? (theme ? theme.accent : "#5db2ff") : (theme ? theme.textMuted : "#aaa")
            font.pixelSize: 13
            wrapMode: Text.Wrap
            width: parent.width
            visible: protonGe && protonGe.ready
          }

          Text {
            text: (protonGe && protonGe.lastError && protonGe.lastError.length > 0) ? ("Updater error: " + protonGe.lastError) : ""
            color: "#ff7777"
            font.pixelSize: 12
            wrapMode: Text.Wrap
            width: parent.width
            visible: protonGe && !protonGe.ready && protonGe.lastError && protonGe.lastError.length > 0
          }
        }
      }

      Item { height: 24; width: 1 }
    }
  }
}
