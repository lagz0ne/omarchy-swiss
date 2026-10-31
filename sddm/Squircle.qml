import QtQuick

// Superellipse (n=5), filled or outlined.
Canvas {
  id: root

  property color color: "#cacccc"
  property bool solid: true
  property real stroke: 1.5

  antialiasing: true
  onColorChanged: requestPaint()
  onSolidChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var r = Math.min(width, height) / 2 - (solid ? 0 : stroke), cx = width / 2, cy = height / 2, n = 5
    ctx.beginPath()
    for (var i = 0; i <= 120; i++) {
      var t = 2 * Math.PI * i / 120, ct = Math.cos(t), st = Math.sin(t)
      var x = cx + r * Math.sign(ct) * Math.pow(Math.abs(ct), 2 / n)
      var y = cy + r * Math.sign(st) * Math.pow(Math.abs(st), 2 / n)
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
    }
    ctx.closePath()
    if (solid) { ctx.fillStyle = color; ctx.fill() }
    else { ctx.lineWidth = stroke; ctx.strokeStyle = color; ctx.stroke() }
  }
}
