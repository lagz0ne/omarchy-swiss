import QtQuick

// Full-width hairline progress pinned to the bottom edge. While `running` it
// eases toward 90%; `finish()` completes it, `reset()` drops it.
Item {
  id: root

  property color color: "#cacccc"
  property color trackColor: "#4b4e55"
  property bool running: false
  property real progress: 0

  height: 2
  visible: running || progress > 0

  function finish() { creep.stop(); done.start() }
  function reset() { creep.stop(); done.stop(); progress = 0 }

  onRunningChanged: {
    if (running) { done.stop(); progress = 0; creep.start() }
    else if (progress < 1) reset()
  }

  Rectangle { anchors.fill: parent; color: root.trackColor }
  Rectangle {
    height: parent.height
    width: parent.width * root.progress
    color: root.color
  }

  NumberAnimation { id: creep; target: root; property: "progress"; to: 0.9; duration: 4000; easing.type: Easing.OutCubic }
  NumberAnimation { id: done; target: root; property: "progress"; to: 1; duration: 180; easing.type: Easing.OutQuad }
}
