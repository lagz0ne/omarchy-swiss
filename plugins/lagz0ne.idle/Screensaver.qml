import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons

// Swiss screensaver: squircle art on pure black. Its job is to keep the OLED
// panels from burning in, so nothing holds still, few pixels are lit, and the
// scene ticks at 10 fps instead of animating at the refresh rate. Four
// oversize scenes take turns, a minute each, crossfading: a dot-matrix clock,
// a sliding field, a rising tide and an orbit. One squircle per scene carries
// the theme's accent. Each session opens on the clock, then plays the other
// scenes in a fresh random order with a fresh layout seed.
// Any key, click or pointer move (after a short grace) dismisses it.
Scope {
  id: root

  property bool active: false
  property date idleSince: new Date()
  // Start a few seconds into this scene (0 clock, 1 field, 2 tide, 3 orbit); -1 = normal
  property int startScene: -1

  readonly property var sceneNames: ["clock", "field", "tide", "orbit"]
  // Per-session order and layout seed, drawn each time it shows
  property var order: sceneNames
  property real seed: 0

  // The theme's warm accent: Omarchy's shell only exposes accent/urgent, which
  // are grey in some themes, so read bright_red (else red) from colors.toml.
  property color accent: "#de6145"

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var found = {}
      var lines = text().split("\n")
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
        if (m) found[m[1]] = m[2]
      }
      root.accent = found.bright_red || found.color9 || found.red || found.color1 || "#de6145"
    }
  }

  function shuffled(list) {
    var a = list.slice()
    for (var i = a.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1))
      var tmp = a[i]; a[i] = a[j]; a[j] = tmp
    }
    return a
  }

  signal dismissed()

  onActiveChanged: {
    if (active) {
      idleSince = new Date()
      if (startScene >= 0) {
        // Previews keep the fixed order and layout so scenes can be compared
        order = sceneNames
        seed = 0
      } else {
        order = ["clock"].concat(shuffled(sceneNames.slice(1)))
        seed = Math.random() * 1000
      }
      console.log("omarchy screensaver order=" + order.join(",") + " seed=" + Math.round(seed) + " accent=" + accent)
      grace.restart()
    }
  }

  function dismiss() {
    if (!active || grace.running) return
    dismissed()
  }

  // Mapping the layer can produce stray pointer events
  Timer { id: grace; interval: 1000 }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      visible: root.active
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-screensaver"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      onVisibleChanged: if (visible) Qt.callLater(function() { keys.forceActiveFocus() })

      Item {
        id: view
        anchors.fill: parent

        readonly property color fg: Commons.Color.foreground
        readonly property color accent: root.accent
        // Screens differ a little even within one session
        readonly property real salt: root.seed + (win.modelData && win.modelData.name ? win.modelData.name.length * 3.7 : 0)
        readonly property int poolSize: 96
        readonly property real sceneSeconds: 60
        readonly property real fadeSeconds: 1.5
        readonly property var scenes: root.order

        property real started: 0
        property real t: 0

        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        // Pure black: lit pixels are the only ones an OLED pays for
        Rectangle { anchors.fill: parent; color: "black" }

        Item {
          id: keys
          anchors.fill: parent
          focus: true
          Keys.onPressed: function(event) { event.accepted = true; root.dismiss() }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.BlankCursor
          onClicked: root.dismiss()
          onPositionChanged: root.dismiss()
          onWheel: root.dismiss()
        }

        Repeater {
          id: pool
          model: view.poolSize

          Squircle {
            width: 1
            height: 1
            opacity: 0
            color: view.fg
          }
        }

        Timer {
          interval: 100
          repeat: true
          running: root.active && win.visible
          triggeredOnStart: true
          onRunningChanged: if (running) {
            view.started = Date.now() / 1000
            if (root.startScene >= 0) view.started -= root.startScene * view.sceneSeconds + 3
          }
          onTriggered: {
            view.t = Date.now() / 1000 - view.started
            view.paint()
          }
        }

        // Stable pseudo-random value in [0, 1) per index and channel
        function rnd(i, k) {
          var v = Math.sin(i * 12.9898 + k * 78.233 + salt) * 43758.5453
          return v - Math.floor(v)
        }

        // Slow wander over the whole screen; periods of several minutes
        function wander(t, fx, fy, phase, padX, padY) {
          return {
            x: width / 2 + Math.max(0, width / 2 - padX) * Math.sin(t * fx + phase + salt),
            y: height / 2 + Math.max(0, height / 2 - padY) * Math.sin(t * fy + phase * 1.7 + salt * 1.3)
          }
        }

        // 5x7 digits, 35 cells per digit, row by row
        readonly property var glyphs: [
          "01110100011001110101110011000101110", "00100011000010000100001000010001110",
          "01110100010000100010001000100011111", "11111000100010000010000011000101110",
          "00010001100101010010111110001000010", "11111100001111000001000011000101110",
          "00110010001000011110100011000101110", "11111000010001000100010000100001000",
          "01110100011000101110100011000101110", "01110100011000101111000010001001100"
        ]

        // Every scene is oversize: a few big squircles, mostly thin outlines and
        // dim fills, so the panel still lights few pixels. Each dot carries its
        // drawn size; the canvas repaints only when that changes (a scene
        // switch), and per-frame motion is position, a gentle scale and opacity.

        function clockDots(t) {
          var now = new Date()
          var text = Qt.formatDateTime(now, "HHmm")
          // 4 digits of 5 columns, a column between digits, 3 for the colon
          var d = width * 0.72 / 26
          var size = Math.round(d * 0.86)
          var blockW = 26 * d, blockH = 7 * d
          var c = wander(t, 0.021, 0.029, 0.5, blockW / 2 + d, blockH / 2 + d)
          var x0 = c.x - blockW / 2 + d / 2, y0 = c.y - blockH / 2 + d / 2
          var dots = []
          for (var g = 0; g < 4; g++) {
            var bits = glyphs[parseInt(text.charAt(g))]
            var gx = x0 + (g * 6 + (g >= 2 ? 3 : 0)) * d
            for (var cell = 0; cell < 35; cell++) {
              if (bits.charAt(cell) !== "1") continue
              var cx = gx + (cell % 5) * d, cy = y0 + Math.floor(cell / 5) * d
              // A slow wave keeps the digits alive between minutes
              var w = 0.5 + 0.5 * Math.sin(t * 0.9 - (cx + cy) / (d * 6))
              dots.push({ x: cx, y: cy, size: size, s: 0.9 + 0.1 * w, o: 0.38 + 0.22 * w, solid: true, accent: false })
            }
          }
          var blink = now.getMilliseconds() < 500 ? 0.9 : 0.15
          var colonX = x0 + 12.5 * d
          dots.push({ x: colonX, y: y0 + 2 * d, size: size, s: 1, o: blink, solid: true, accent: true })
          dots.push({ x: colonX, y: y0 + 4 * d, size: size, s: 1, o: 0.3, solid: true, accent: false })
          return dots
        }

        function fieldDots(t) {
          // Screen-filling grid sliding diagonally; it wraps by one cell so the
          // tiling never sits still
          var cell = height / 3.1
          var cols = Math.ceil(width / cell) + 2, rows = Math.ceil(height / cell) + 2
          var ox = (t * cell * 0.012) % cell, oy = (t * cell * 0.008) % cell
          var size = Math.round(cell * 0.84)
          var count = cols * rows
          var hot = Math.floor(t / 4) % count
          var dots = []
          for (var i = 0; i < count; i++) {
            var r = Math.floor(i / cols), col = i % cols
            var w = 0.5 + 0.5 * Math.sin(t * 0.7 - (r + col) * 0.8)
            var solid = (r + col) % 3 === 0
            dots.push({
              x: (col - 1) * cell + ox + cell / 2,
              y: (r - 1) * cell + oy + cell / 2,
              size: size,
              s: 0.88 + 0.12 * w,
              o: i === hot ? 0.8 : (solid ? 0.05 + 0.12 * w : 0.1 + 0.45 * w * w),
              solid: solid && i !== hot,
              accent: i === hot
            })
          }
          return dots
        }

        function tideDots(t) {
          var dots = [], n = 7, span = height * 1.9
          for (var i = 0; i < n; i++) {
            var size = Math.round(height * (0.22 + 0.4 * rnd(i, 5)))
            var speed = height * (0.012 + 0.02 * rnd(i, 2))
            var travelled = rnd(i, 3) * span + t * speed
            // Rises from below the screen to above it, then comes round again
            var y = height + size / 2 - travelled % span
            var pass = Math.floor(travelled / span)
            var x = width * (0.08 + 0.84 * rnd(i * 7 + pass, 1)) + Math.sin(t * 0.2 + i) * height * 0.05
            var solid = i === 3
            dots.push({
              x: x, y: y, size: size,
              s: 1 + 0.04 * Math.sin(t * 0.5 + i),
              o: solid ? 0.08 : 0.18 + 0.35 * rnd(i, 4),
              solid: solid,
              accent: i === 0
            })
          }
          return dots
        }

        function orbitDots(t) {
          var dots = [], n = 7
          var c = wander(t, 0.017, 0.026, 2.1, width * 0.3, height * 0.3)
          for (var i = 0; i < n; i++) {
            var size = Math.round(height * (i === 0 ? 0.09 : 0.12 + 0.05 * i))
            var radius = height * (i === 0 ? 0 : 0.12 + i * 0.1)
            var a = t * (0.35 / (1 + i * 0.4)) * (i % 2 ? -1 : 1) + rnd(i, 1) * 6.283
            dots.push({
              x: c.x + radius * Math.cos(a),
              y: c.y + radius * Math.sin(a) * 0.9,
              size: size,
              s: 1 + 0.06 * Math.sin(t * 0.6 + i),
              o: i === 0 ? 0.85 : 0.15 + 0.4 * (1 - i / n),
              solid: i === 0,
              accent: i === 0
            })
          }
          return dots
        }

        function paint() {
          var sceneIndex = Math.floor(t / sceneSeconds) % scenes.length
          var local = t % sceneSeconds
          var fade = Math.min(1, local / fadeSeconds, (sceneSeconds - local) / fadeSeconds)
          var name = scenes[sceneIndex]
          var dots = name === "clock" ? clockDots(t)
            : name === "field" ? fieldDots(t)
            : name === "tide" ? tideDots(t)
            : orbitDots(t)

          for (var i = 0; i < poolSize; i++) {
            var item = pool.itemAt(i)
            if (!item) continue
            var d = dots[i]
            if (!d) {
              if (item.opacity !== 0) item.opacity = 0
              continue
            }
            if (item.width !== d.size) {
              item.width = d.size
              item.height = d.size
            }
            item.x = d.x - d.size / 2
            item.y = d.y - d.size / 2
            item.scale = d.s
            item.opacity = d.o * fade
            if (item.solid !== d.solid) item.solid = d.solid
            var color = d.accent ? accent : fg
            if (!Qt.colorEqual(item.color, color)) item.color = color
          }
        }
      }
    }
  }
}
