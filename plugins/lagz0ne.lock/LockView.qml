import QtQuick
import qs.Commons as Commons

// Swiss lock: bottom-left type block, one squircle per key, hairline progress
// along the bottom edge. Matches the Plymouth and SDDM themes.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  // The field is cleared on submit; keep the key count for the busy wave
  property int submittedLength: 0

  readonly property color fg: Commons.Color.foreground
  readonly property color label: Commons.Color.lock.placeholder
  readonly property color muted: Commons.Color.muted
  readonly property color err: Commons.Color.lock.textError
  // The one warm accent, from the theme ([lock] text-error): cursor and progress
  readonly property color accent: Commons.Color.lock.textError
  readonly property real k: height / 900
  readonly property real margin: 60 * k
  readonly property bool errorState: failureMessage.length > 0

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
    onPositionChanged: root.wakeRequested()
  }

  // Invisible input; the key row is the only feedback for what's typed.
  TextInput {
    id: passwordInput
    width: 1
    height: 1
    opacity: 0
    activeFocusOnPress: true
    enabled: root.inputEnabled && !root.authenticatingPassword
    readOnly: root.authenticatingPassword
    echoMode: TextInput.Password
    passwordMaskDelay: 0

    onTextChanged: {
      if (!root.syncingPasswordText) root.passwordTextEdited(text)
      if (text.length > 0) root.wakeRequested()
      if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
    }

    onAccepted: {
      var submitted = root.passwordText
      root.submittedLength = submitted.length
      root.passwordTextEdited("")
      if (submitted.length > 0) root.submitPassword(submitted)
    }

    Keys.onPressed: function(event) {
      root.wakeRequested()
      if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
        root.passwordTextEdited("")
        event.accepted = true
      }
    }
  }

  Column {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.margin
    anchors.bottomMargin: root.margin

    Text {
      textFormat: Text.PlainText
      text: Qt.formatDateTime(clock.now, "dddd d MMMM, HH:mm").toUpperCase()
      color: root.label
      font.family: "Nimbus Sans"
      font.pixelSize: Math.round(13 * root.k)
      font.letterSpacing: 2.5 * root.k
      bottomPadding: 6 * root.k
    }

    Text {
      textFormat: Text.PlainText
      text: "Locked"
      color: root.fg
      font.family: "Nimbus Sans"
      font.bold: true
      font.pixelSize: Math.round(115 * root.k)
      font.letterSpacing: -4.5 * root.k
      x: -8.5 * root.k  // cancels the "L" side bearing so the stem sits on the margin
      bottomPadding: 22 * root.k
    }

    Text {
      textFormat: Text.PlainText
      text: root.authenticatingPassword ? "Checking…"
        : root.errorState ? "Not quite. Try again."
        : root.fingerprintConfigured ? "Look at the camera, or type password and press return."
        : "Type password and press return."
      color: root.errorState ? root.err : root.fg
      font.family: "Nimbus Sans"
      font.pixelSize: Math.round(17 * root.k)
      bottomPadding: 18 * root.k
    }

    KeyRow {
      count: root.authenticatingPassword ? root.submittedLength : passwordInput.text.length
      busy: root.authenticatingPassword
      error: root.errorState
      color: root.fg
      errorColor: root.err
      accentColor: root.accent
      size: 22 * root.k
      gap: 7 * root.k
    }
  }

  Hairline {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    color: root.accent
    trackColor: root.muted
    running: root.authenticatingPassword
  }

  Timer {
    id: clock
    property date now: new Date()
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: now = new Date()
  }
}
