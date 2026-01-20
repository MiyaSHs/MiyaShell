import QtQuick
import QtMultimedia

// Simple UI SFX helper.
// Uses QtMultimedia SoundEffect (low latency for short UI sounds).
QtObject {
  id: sfx

  // Inject Settings
  property var settings

  // Master enable/volume (0..1)
  readonly property bool enabled: settings ? settings.uiSfxEnabled : true
  readonly property real volume: settings ? settings.uiSfxVolume : 0.65

  // Internal helper to play a SoundEffect safely
  function _play(effect) {
    if (!enabled) return
    if (!effect) return
    effect.volume = Math.max(0.0, Math.min(1.0, volume))
    effect.play()
  }

  function focus() { _play(focusFx) }
  function select() { _play(selectFx) }
  function back() { _play(backFx) }
  function toggle() { _play(toggleFx) }
  function open() { _play(openFx) }
  function close() { _play(closeFx) }

  // Sources are resolved relative to this file
  SoundEffect { id: focusFx;  source: Qt.resolvedUrl("../../assets/sfx/ui_focus.wav") }
  SoundEffect { id: selectFx; source: Qt.resolvedUrl("../../assets/sfx/ui_select.wav") }
  SoundEffect { id: backFx;   source: Qt.resolvedUrl("../../assets/sfx/ui_back.wav") }
  SoundEffect { id: toggleFx; source: Qt.resolvedUrl("../../assets/sfx/ui_toggle.wav") }
  SoundEffect { id: openFx;   source: Qt.resolvedUrl("../../assets/sfx/ui_open.wav") }
  SoundEffect { id: closeFx;  source: Qt.resolvedUrl("../../assets/sfx/ui_close.wav") }
}
