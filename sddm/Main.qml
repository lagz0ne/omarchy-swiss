import QtQuick
import SddmComponents 2.0

Rectangle {
  id: root
  width: 1440
  height: 900
  color: "#101315"

  readonly property color fg: "#cacccc"
  readonly property color muted: "#4b4e55"
  readonly property color label: "#8b8d8e"
  readonly property color err: "#de6145"
  // The one warm accent: cursor and progress
  readonly property color accent: "#de6145"
  readonly property real k: height / 900
  readonly property real margin: 60 * k

  property string currentUser: userModel.lastUser
  property bool loginFailed: false
  property bool busy: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.busy = false
      root.loginFailed = true
      password.text = ""
      password.forceActiveFocus()
    }
    function onLoginSucceeded() {
      root.loginFailed = false
      hairline.finish()
    }
  }

  TextInput {
    id: password
    width: 1; height: 1
    opacity: 0
    echoMode: TextInput.Password
    focus: true
    enabled: !root.busy
    onTextChanged: {
      if (text.length > 0) root.loginFailed = false
    }
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) { text = ""; event.accepted = true }
    }
    onAccepted: {
      if (text.length === 0) return
      root.busy = true
      sddm.login(root.currentUser, text, root.sessionIndex)
    }
  }

  MouseArea { anchors.fill: parent; onClicked: password.forceActiveFocus() }

  Column {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.margin
    anchors.bottomMargin: root.margin

    Text {
      textFormat: Text.PlainText
      text: "SESSION" + (root.currentUser ? " · " + root.currentUser.toUpperCase() : "")
      color: root.label
      font.family: "Nimbus Sans"
      font.pixelSize: Math.round(13 * root.k)
      font.letterSpacing: 2.5 * root.k
      bottomPadding: 6 * root.k
    }

    Text {
      text: "Sign in"
      color: root.fg
      font.family: "Nimbus Sans"
      font.bold: true
      font.pixelSize: Math.round(115 * root.k)
      font.letterSpacing: -4.5 * root.k
      x: -4 * root.k  // round "S" overshoots the margin slightly, as rounds should
      bottomPadding: 22 * root.k
    }

    Text {
      text: root.busy ? "Signing in…"
        : root.loginFailed ? "Not quite. Try again."
        : "Type password and press return."
      color: root.loginFailed ? root.err : root.fg
      font.family: "Nimbus Sans"
      font.pixelSize: Math.round(17 * root.k)
      bottomPadding: 18 * root.k
    }

    KeyRow {
      count: password.text.length
      busy: root.busy
      error: root.loginFailed
      color: root.fg
      errorColor: root.err
      accentColor: root.accent
      size: 22 * root.k
      gap: 7 * root.k
    }
  }

  Hairline {
    id: hairline
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    color: root.accent
    trackColor: root.muted
    running: root.busy
  }

  Component.onCompleted: password.forceActiveFocus()
}
