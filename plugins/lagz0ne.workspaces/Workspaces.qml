import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Per-screen workspace tiles. Each bar shows only the workspaces living on
// its own monitor (workspace 1 is pinned to eDP-1, 2 to eDP-2 in monitors.lua),
// drawn as numbered tiles: filled = focused, outlined = shown on this screen
// while the other screen has focus, dim = occupied in the background.
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property string screenName: {
    var w = root.QsWindow.window
    return w && w.screen ? String(w.screen.name || "") : ""
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var ids = []
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (ws.id <= 0 || ws.id > 10) continue
      if (root.screenName !== "" && (!ws.monitor || ws.monitor.name !== root.screenName)) continue
      if (ids.indexOf(ws.id) === -1) ids.push(ws.id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property color ink: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color paper: bar ? bar.background : Commons.Color.background
  // Theme [bar] keys: tile-style = "outline" draws the focused tile as an
  // outline in tile-focus (default: ink) instead of a solid block
  readonly property bool outlineTiles: String(Commons.Color.shellValues["bar.tile-style"] || "") === "outline"
  readonly property color focusInk: Commons.Color.shellValues["bar.tile-focus"]
    ? Commons.Color.flatColor(Commons.Color.shellValues["bar.tile-focus"], root.ink) : root.ink
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property real tileSize: Math.round(root.barSize * 0.62)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      Item {
        id: cell
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool shown: workspace !== null && workspace.monitor !== null && workspace.monitor.activeWorkspace === workspace
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        Layout.preferredWidth: root.vertical ? root.barSize : root.tileSize + Style.space(4)
        Layout.preferredHeight: root.vertical ? root.tileSize + Style.space(4) : root.barSize

        Rectangle {
          anchors.centerIn: parent
          width: root.tileSize
          height: root.tileSize
          radius: Math.min(Style.cornerRadius, width / 4)
          color: cell.focused && !root.outlineTiles ? root.ink : "transparent"
          border.width: cell.focused && !root.outlineTiles ? 0 : 1
          border.color: cell.focused ? root.focusInk : root.ink
          opacity: cell.focused || cell.shown ? 1 : (cell.occupied ? 0.55 : 0.3)

          Behavior on color { ColorAnimation { duration: 140 } }

          Text {
            anchors.centerIn: parent
            text: cell.modelData === 10 ? "0" : String(cell.modelData)
            color: cell.focused ? (root.outlineTiles ? root.focusInk : root.paper) : root.ink
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Math.round(root.tileSize * 0.62)
            font.weight: Font.Bold
          }
        }

        WidgetButton {
          anchors.fill: parent
          bar: root.bar
          text: " "
          labelVisible: false
          fixedWidth: cell.width
          fixedHeight: cell.height
          tooltipText: "Workspace " + cell.modelData
          onPressed: function() { root.focusWorkspace(cell.modelData) }
        }
      }
    }
  }
}
