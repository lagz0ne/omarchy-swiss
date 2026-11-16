import QtQuick
import qs.Commons as Commons

// Open-panel mark restyle. The packaged bar draws a full-width pill in the
// theme accent (grey in swiss) beside the module whose card is open. This
// restyles every mark in this bar window as a short tick in the theme's
// [bar] panel-mark color, at panel-mark-alpha, panel-mark-length of the
// module's extent. Bar.qml is packaged, so the marks are found at runtime by
// walking up from this widget to its window and back down. Without a
// panel-mark key the stock look is kept.
QtObject {
  id: root

  property Item host: null
  property var marked: []

  readonly property var values: Commons.Color.shellValues || {}
  readonly property bool enabled: !!values["bar.panel-mark"]
  readonly property color markColor: {
    var c = Commons.Color.flatColor(values["bar.panel-mark"], Commons.Color.accent)
    var a = parseFloat(values["bar.panel-mark-alpha"])
    return Qt.alpha(c, isFinite(a) ? a : 1)
  }
  readonly property real markLength: {
    var n = parseFloat(values["bar.panel-mark-length"])
    return isFinite(n) && n > 0 ? n : 1
  }

  function slotOf(item) {
    for (var p = item.parent, i = 0; p && i < 4; p = p.parent, i++)
      if (("panelOpen" in p) && ("panelIndicatorExtent" in p)) return p
    return null
  }

  function patch(mark) {
    if (marked.indexOf(mark) >= 0) return
    marked.push(mark)
    var slot = slotOf(mark)
    var vertical = mark.width < mark.height
    mark.color = Qt.binding(function() { return root.enabled ? root.markColor : Commons.Color.accent })
    var len = Qt.binding(function() {
      return Math.round(slot.panelIndicatorExtent * (root.enabled ? root.markLength : 1))
    })
    if (vertical) mark.height = len
    else mark.width = len
  }

  function walk(obj, depth) {
    if (!obj || depth > 60) return
    if (("inset" in obj) && ("radius" in obj) && obj.z === 50 && slotOf(obj)) {
      patch(obj)
      return
    }
    var kids = obj.children
    if (kids) for (var i = 0; i < kids.length; i++) walk(kids[i], depth + 1)
  }

  function scan() {
    if (!host) return
    marked = marked.filter(function(m) { return m && m.parent })
    var top = host
    while (top.parent) top = top.parent
    walk(top, 0)
  }

  // Modules come and go (bar edits, screens, reloads), so rescan now and then.
  property Timer timer: Timer {
    interval: 3000
    repeat: true
    running: !!root.host
    triggeredOnStart: true
    onTriggered: root.scan()
  }
}
