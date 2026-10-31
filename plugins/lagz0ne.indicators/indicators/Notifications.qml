import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Unread notifications: anything that landed in the notification history since
// the last time it was opened from here. Accent-colored while there are some;
// click replays the history and marks it all read.
BarIndicator {
  id: root

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property string historyDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history"
  readonly property string seenPath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications-seen"
  property int unreadCount: 0

  active: unreadCount > 0
  activeText: "󰂞"
  inactiveText: "󰂚"
  activeTooltipText: unreadCount + (unreadCount === 1 ? " unread notification" : " unread notifications")
  inactiveTooltipText: "No unread notifications"
  useActiveColor: true
  // Swiss's orange pop (bright_red); the shell only exposes grey accent/urgent for this theme.
  activeColor: "#de6145"

  function refresh() {
    if (!countProc.running) countProc.running = true
  }

  // History files are named <timestamp ms>-<id>.json; a missing seen file means
  // a first run, so everything already there counts as read.
  Process {
    id: countProc
    command: ["bash", "-c",
      "[[ -f $2 ]] || date +%s%3N > \"$2\"\n" +
      "seen=$(<\"$2\")\n" +
      "n=0\n" +
      "for f in \"$1\"/*.json; do\n" +
      "  [[ -e $f ]] || continue\n" +
      "  ts=${f##*/}; ts=${ts%%-*}\n" +
      "  (( ts > seen )) && n=$((n + 1))\n" +
      "done\n" +
      "echo $n", "--", root.historyDir, root.seenPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.unreadCount = Number(text.trim()) || 0
    }
  }

  Process {
    id: markReadProc
    command: ["bash", "-c", "date +%s%3N > \"$1\"", "--", root.seenPath]
    onExited: root.refresh()
  }

  // Recount whenever the history directory changes (new, trimmed or cleared).
  Process {
    running: true
    command: ["bash", "-c", "mkdir -p \"$1\" && exec inotifywait -m -q -e create,moved_to,delete,moved_from \"$1\"", "--", root.historyDir]
    stdout: SplitParser {
      onRead: function() { debounce.restart() }
    }
  }

  Timer {
    id: debounce
    interval: 300
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  onPressed: function() {
    if (root.notificationService) root.notificationService.showRecentHistory()
    markReadProc.running = true
  }
}
