import QtQuick

// One filled squircle per typed key, then a breathing outline where the next
// key lands. New keys pop in with a ripple; `busy` runs a wave across them.
Item {
  id: root

  property int count: 0
  property bool busy: false
  property bool error: false
  property color color: "#cacccc"
  property color errorColor: "#de6145"
  // The live cursor carries the theme's one accent
  property color accentColor: "#de6145"
  property real size: 28
  property real gap: 8
  property int maxKeys: 32
  readonly property color tint: error ? errorColor : color
  readonly property int shown: Math.min(count, maxKeys)

  implicitWidth: (shown + 1) * (size + gap)
  implicitHeight: size

  Repeater {
    model: root.shown

    Item {
      id: key
      required property int index
      x: index * (root.size + root.gap)
      width: root.size
      height: root.size

      Squircle {
        id: body
        anchors.centerIn: parent
        width: root.size
        height: root.size
        color: root.tint
        scale: 0.4
        Component.onCompleted: pop.start()

        NumberAnimation on scale { id: pop; running: false; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }

        SequentialAnimation on opacity {
          running: root.busy
          loops: Animation.Infinite
          alwaysRunToEnd: true
          PauseAnimation { duration: key.index * 70 }
          NumberAnimation { to: 0.25; duration: 360; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 360; easing.type: Easing.InOutSine }
          PauseAnimation { duration: Math.max(0, (root.shown - key.index) * 70) }
        }
      }

      Squircle {
        id: echo
        anchors.centerIn: parent
        width: root.size
        height: root.size
        solid: false
        color: root.tint
        opacity: 0
        Component.onCompleted: ripple.start()

        ParallelAnimation {
          id: ripple
          NumberAnimation { target: echo; property: "scale"; from: 1; to: 1.8; duration: 520; easing.type: Easing.OutQuad }
          NumberAnimation { target: echo; property: "opacity"; from: 0.7; to: 0; duration: 520; easing.type: Easing.OutQuad }
        }
      }
    }
  }

  // Cursor: where the next key lands
  Squircle {
    x: root.shown * (root.size + root.gap)
    width: root.size
    height: root.size
    solid: false
    color: root.error ? root.errorColor : root.accentColor
    visible: !root.busy
    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    SequentialAnimation on opacity {
      loops: Animation.Infinite
      NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.3; duration: 1100; easing.type: Easing.InOutSine }
    }
  }
}
