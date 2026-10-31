import QtQuick
import qs.Commons as Commons

// Style.applyShellValues only keeps size-horizontal/size-vertical from [bar].
// Merge the icon sizing keys from the theme's shell.toml back in, every time
// Style resets its overrides (theme switch, shell.toml edit).
Item {
  id: root

  // Injected by omarchy-shell (the first-party service loader).
  property var shell: null

  readonly property var keys: ["icon-slot", "icon-canvas", "icon-font", "status-slot"]

  function apply() {
    var values = Commons.Color.shellValues || {}
    var current = Commons.Style.barOverrides || {}
    var next = Object.assign({}, current)
    var changed = false
    for (var i = 0; i < keys.length; i++) {
      var n = parseFloat(values["bar." + keys[i]])
      if (isFinite(n) && n > 0 && current[keys[i]] !== n) {
        next[keys[i]] = n
        changed = true
      }
    }
    if (changed) Commons.Style.barOverrides = next
  }

  Connections {
    target: Commons.Style
    function onBarOverridesChanged() { Qt.callLater(root.apply) }
  }

  Component.onCompleted: apply()
}
