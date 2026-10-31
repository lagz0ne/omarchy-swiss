import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PolkitModel.js" as PolkitModel

Item {
  id: root

  property string fontFamily: Style.font.menuFamily
  // Bound to the central [polkit] section in shell.toml via Commons.Color.qml.
  property color accent: Commons.Color.polkit.accent
  property color background: Commons.Color.polkit.background
  property color foreground: Commons.Color.polkit.text
  property color border: Commons.Color.polkit.border
  property color borderError: Commons.Color.polkit.borderError
  property var borderSpec: Border.surfaceSpec("polkit", errorFlash ? "border-error" : "border", errorFlash ? borderError : border, Math.max(1, Style.space(2)), "border-alpha")
  property color scrim: Commons.Color.polkit.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int fieldHeight: Math.max(Style.space(42), Style.spacing.controlHeight)

  property bool closing: false
  property bool submitted: false
  property string currentMessage: ""
  property string currentPrompt: ""
  property string currentSupplementary: ""
  property bool responseRequired: false
  property bool responseVisible: false
  property bool failed: false
  property bool errorFlash: false
  // pam_fprintd appears in the polkit PAM stack (a sensor is enrolled).
  property bool fingerprintConfigured: false
  // Lid shut right now — the reader is physically unreachable, so we fall back
  // to the password even when a sensor is enrolled. Refreshed per request.
  property bool laptopClosed: false
  property int shakeOffset: 0
  // The field is cleared on submit; keep the key count for the busy wave
  property int submittedLength: 0

  readonly property bool dialogVisible: polkitAgent.isActive || closing
  // We show one method at a time. Fingerprint owns the dialog while PAM is
  // waiting on the reader (lid open, sensor enrolled); the moment PAM asks for
  // a password — including immediately when the lid is shut and the clamshell
  // gate skips pam_fprintd — we switch to the password field instead.
  readonly property bool fingerprintMode: fingerprintConfigured && !laptopClosed && dialogVisible && !responseRequired && !submitted && !errorFlash
  readonly property int cardHeight: panel.height > 0 ? Math.min(fieldHeight + contentMargin * 2, panel.height - Style.gapsOut * 2) : fieldHeight + contentMargin * 2
  // Password mode is a wide field; fingerprint mode collapses to a square that
  // just frames the centered sensor icon.
  readonly property int cardWidth: fingerprintMode ? cardHeight : Math.min(Style.space(312), Math.max(Style.space(260), panel.width - Style.gapsOut * 2))

  function authorizationLabel(message) {
    return PolkitModel.authorizationLabel(message)
  }

  // "Authentication is needed to run `/x` as the super user" -> "Run /x." (the label says root)
  function requestSentence(message) {
    var text = String(message || "")
    var match = text.match(/^Authentication is (?:needed|required) to run [`']([^`']+)[`'] as /i)
    if (match) return "Run " + match[1] + "."
    return text.replace(/\s+$/, "")
  }

  function loadPamConfig(raw) {
    fingerprintConfigured = PolkitModel.fingerprintConfiguredFromPamConfig(raw)
  }

  function refreshLidState() {
    if (!laptopClosedProc.running) laptopClosedProc.running = true
  }

  function resetSnapshot() {
    currentMessage = ""
    currentPrompt = ""
    currentSupplementary = ""
    responseRequired = false
    responseVisible = false
    failed = false
    errorFlash = false
    submitted = false
    passwordInput.text = ""
  }

  function syncFromFlow() {
    var flow = polkitAgent.flow
    if (!flow) return

    currentMessage = String(flow.message || "Authentication is needed...")
    currentPrompt = String(flow.inputPrompt || "")
    currentSupplementary = String(flow.supplementaryMessage || "")
    responseRequired = !!flow.isResponseRequired
    responseVisible = !!flow.responseVisible
    failed = !!flow.failed

    if (responseRequired) submitted = false
  }

  function beginFlow() {
    closeTimer.stop()
    closing = false
    submitted = false
    passwordInput.text = ""
    refreshLidState()
    syncFromFlow()
    Qt.callLater(refocus)
  }

  function refocus() {
    if (!dialogVisible) return
    // In fingerprint mode there is no field to type into — park focus on the
    // key catcher so Escape still cancels; otherwise focus the password field.
    if (fingerprintMode) keyCatcher.forceActiveFocus()
    else passwordInput.forceActiveFocus()
  }

  function submitResponse() {
    var flow = polkitAgent.flow
    if (!flow || !flow.isResponseRequired) return
    submitted = true
    errorFlash = false
    submittedLength = passwordInput.text.length
    flow.submit(passwordInput.text)
    passwordInput.text = ""
    keyCatcher.forceActiveFocus()
  }

  function cancelRequest() {
    var flow = polkitAgent.flow
    passwordInput.text = ""
    submitted = false
    closing = true
    closeTimer.restart()
    if (flow) flow.cancelAuthenticationRequest()
  }

  function triggerFailureFeedback() {
    submitted = false
    errorFlash = true
    passwordInput.text = ""
    errorTimer.restart()
    shakeAnimation.restart()
    Qt.callLater(refocus)
  }

  Timer {
    id: closeTimer
    interval: 300
    repeat: false
    onTriggered: {
      closing = false
      resetSnapshot()
    }
  }

  Timer {
    id: errorTimer
    interval: 1200
    repeat: false
    onTriggered: root.errorFlash = false
  }

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 35; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: 50; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
  }
  FileView {
    path: "/etc/pam.d/polkit-1"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadPamConfig(text())
    onLoadFailed: root.fingerprintConfigured = false
    onFileChanged: reload()
  }

  Process {
    id: laptopClosedProc
    command: ["bash", "-c", "omarchy-hw-laptop-closed && echo closed || echo open"]
    stdout: StdioCollector { id: laptopClosedOut; waitForEnd: true }
    onExited: root.laptopClosed = String(laptopClosedOut.text || "").trim() === "closed"
  }

  PolkitAgent {
    id: polkitAgent
    path: "/org/omarchy/PolkitAgent"

    onAuthenticationRequestStarted: root.beginFlow()
    onIsActiveChanged: {
      if (isActive) root.syncFromFlow()
      else if (!root.closing) root.resetSnapshot()
    }
    onIsRegisteredChanged: {
      if (isRegistered) console.log("omarchy polkit agent registered")
      else console.warn("omarchy polkit agent is not registered; another agent may be running")
    }
  }

  Connections {
    target: polkitAgent.flow

    function onIsResponseRequiredChanged() {
      root.syncFromFlow()
      if (!polkitAgent.flow || !polkitAgent.flow.isResponseRequired) passwordInput.text = ""
      Qt.callLater(root.refocus)
    }

    function onInputPromptChanged() { root.syncFromFlow() }
    function onResponseVisibleChanged() { root.syncFromFlow() }
    function onSupplementaryMessageChanged() { root.syncFromFlow() }
    function onFailedChanged() { root.syncFromFlow() }

    function onAuthenticationFailed() {
      root.syncFromFlow()
      root.triggerFailureFeedback()
    }

    function onAuthenticationSucceeded() {
      root.closing = true
      closeTimer.restart()
    }

    function onAuthenticationRequestCancelled() {
      root.closing = true
      closeTimer.restart()
    }
  }

  // Swiss dialog: the lock screen's bottom-left type block on a solid
  // background, one squircle per key, hairline progress while PAM checks.
  PanelWindow {
    id: panel
    visible: root.dialogVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Item {
      id: view
      anchors.fill: parent

      readonly property color fg: Commons.Color.foreground
      readonly property color label: Commons.Color.lock.placeholder
      readonly property color muted: Commons.Color.muted
      readonly property color err: Commons.Color.lock.textError
      // The one warm accent, from the theme ([lock] text-error): cursor and progress
      readonly property color accent: Commons.Color.lock.textError
      readonly property real k: height / 900
      readonly property real margin: 60 * k
      readonly property bool errorState: root.errorFlash

      opacity: root.closing ? 0 : 1
      Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

      Rectangle { anchors.fill: parent; color: Commons.Color.background }

      MouseArea { anchors.fill: parent; onClicked: root.refocus() }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.cancelRequest()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.responseRequired) root.submitResponse()
            event.accepted = true
          }
        }
      }

      // Invisible input; the key row is the only feedback for what's typed.
      TextInput {
        id: passwordInput
        width: 1
        height: 1
        opacity: 0
        activeFocusOnPress: true
        echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
        passwordMaskDelay: 0
        readOnly: root.submitted || root.errorFlash
        enabled: root.dialogVisible
        onTextChanged: if (text.length > 0 && root.errorFlash) { errorTimer.stop(); root.errorFlash = false }
        onAccepted: root.submitResponse()
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.cancelRequest()
            event.accepted = true
          } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U) {
            text = ""
            event.accepted = true
          }
        }
      }

      Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: view.margin
        anchors.bottomMargin: view.margin
        width: parent.width - view.margin * 2

        Text {
          textFormat: Text.PlainText
          text: "ROOT ACCESS"
          color: view.label
          font.family: "Nimbus Sans"
          font.pixelSize: Math.round(13 * view.k)
          font.letterSpacing: 2.5 * view.k
          bottomPadding: 6 * view.k
        }

        Text {
          textFormat: Text.PlainText
          text: "Authorize"
          color: view.fg
          font.family: "Nimbus Sans"
          font.bold: true
          font.pixelSize: Math.round(115 * view.k)
          font.letterSpacing: -4.5 * view.k
          x: -3.5 * view.k  // "A" overshoots the margin slightly, like the other rounds/diagonals
          bottomPadding: 22 * view.k
        }

        // What is being authorized, then what to do. One line, like the lock.
        Row {
          width: parent.width
          bottomPadding: 18 * view.k
          spacing: 0.3 * 17 * view.k

          Text {
            id: requestText
            textFormat: Text.PlainText
            text: root.requestSentence(root.currentMessage)
            color: view.fg
            font.family: "Nimbus Sans"
            font.pixelSize: Math.round(17 * view.k)
            width: Math.min(implicitWidth, parent.width - stateText.implicitWidth - parent.spacing)
            elide: Text.ElideMiddle
          }

          Text {
            id: stateText
            textFormat: Text.PlainText
            text: view.errorState ? "Not quite. Try again."
              : root.submitted ? "Checking…"
              : root.responseRequired ? "Type password and press return. Esc cancels."
              : "Look at the camera. Esc cancels."
            color: view.errorState ? view.err : view.label
            font.family: "Nimbus Sans"
            font.pixelSize: Math.round(17 * view.k)
          }
        }

        KeyRow {
          count: root.submitted || root.errorFlash ? root.submittedLength : passwordInput.text.length
          busy: root.submitted
          error: view.errorState
          color: view.fg
          errorColor: view.err
          accentColor: view.accent
          size: 22 * view.k
          gap: 7 * view.k
          opacity: root.responseRequired || root.submitted || root.errorFlash ? 1 : 0.3
        }
      }

      Hairline {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: view.accent
        trackColor: view.muted
        running: root.submitted || (!root.responseRequired && root.dialogVisible && !root.closing)
      }
    }
  }
}
