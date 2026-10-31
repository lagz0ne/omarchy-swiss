#!/bin/bash
# omarchy-swiss installer. Safe to re-run: it overwrites its own files, keeps
# anything else you have, and backs up what it replaces.
#
#   ./install.sh            user part + boot part (asks for root once)
#   ./install.sh --user     themes, wallpapers, shell plugins, menu entry
#   ./install.sh --boot     Plymouth, SDDM, Limine (root via pkexec)
#   add --apply <Theme>     also switch to "Swiss", "Swiss Outline" or "Swiss Light"
set -euo pipefail
src=$(dirname "$(readlink -f "$0")")
cfg="$HOME/.config/omarchy"
backup="$HOME/.cache/omarchy-swiss/backup-$(date +%Y%m%d-%H%M%S)"

do_user=1 do_boot=1 apply=""
while (( $# )); do
  case "$1" in
    --user) do_boot=0 ;;
    --boot) do_user=0 ;;
    --apply) apply="${2:?--apply needs a theme name}"; shift ;;
    -h|--help) sed -n 2,9p "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

need() { command -v "$1" >/dev/null || { echo "missing: $1" >&2; exit 1; }; }

install_user() {
  need jq; need python3
  mkdir -p "$cfg/themes" "$cfg/plugins" "$cfg/extensions" "$backup"

  echo "themes:"
  for t in swiss swiss-outline swiss-light; do
    mkdir -p "$cfg/themes/$t"
    cp -r "$src/themes/$t/." "$cfg/themes/$t/"      # adds/overwrites, never deletes your own backgrounds
    echo "  $t"
  done

  echo "plugins:"
  for p in "$src"/plugins/*/; do
    id=$(basename "$p")
    if [[ -d $cfg/plugins/$id ]]; then
      mkdir -p "$backup/plugins"; cp -a "$cfg/plugins/$id" "$backup/plugins/"
      rm -rf "$cfg/plugins/$id"
    fi
    cp -a "$p" "$cfg/plugins/$id"
    echo "  $id"
  done

  # shell.json: run the Swiss services instead of the stock ones, and put the
  # Swiss bar widgets where the stock ones were
  json="$cfg/shell.json"
  [[ -f $json ]] || echo '{}' > "$json"
  cp "$json" "$backup/shell.json"
  jq '
    def add_plugin($id): .plugins = ((.plugins // []) | if any(.[]; .id == $id) then . else . + [{id: $id}] end);
    def disable($id): .disabledPlugins = ((.disabledPlugins // []) | if index($id) then . else . + [$id] end);
    def swap_widget($from; $to):
      if .bar.layout then .bar.layout |= with_entries(.value |= map(if .id == $from then .id = $to else . end)) else . end;
    add_plugin("lagz0ne.lock") | add_plugin("lagz0ne.idle") | add_plugin("lagz0ne.polkit") | add_plugin("lagz0ne.bar-tokens")
    | disable("omarchy.lock") | disable("omarchy.idle") | disable("omarchy.polkit")
    | swap_widget("omarchy.workspaces"; "lagz0ne.workspaces")
    | swap_widget("omarchy.indicators"; "lagz0ne.indicators")
  ' "$backup/shell.json" > "$json"
  echo "shell.json: Swiss lock, idle, polkit, bar tokens on; bar widgets swapped (backup in $backup)"

  # Omarchy menu: "Screensaver" opens the Swiss overlay
  menu="$cfg/extensions/omarchy-menu.jsonc"
  [[ -f $menu ]] || printf '{\n}\n' > "$menu"
  cp "$menu" "$backup/omarchy-menu.jsonc"
  python3 - "$menu" "$src/menu/screensaver.jsonc" <<'PY'
import sys
path, snippet = sys.argv[1], open(sys.argv[2]).read().rstrip() + "\n"
text = open(path).read()
if '"system.screensaver"' not in text:
    body = text.rstrip()
    assert body.endswith("}"), "omarchy-menu.jsonc should end with }"
    open(path, "w").write(body[:-1].rstrip() + "\n\n" + snippet + "}\n")
PY
  echo "menu: Screensaver -> Swiss overlay"

  [[ -n ${OMARCHY_SWISS_NO_RESTART:-} ]] || omarchy restart shell >/dev/null 2>&1 || echo "restart the shell to load the plugins: omarchy restart shell"
}

install_boot() {
  echo "boot screens (asks for root):"
  pkexec "$src/install-boot.sh"
}

(( do_user )) && install_user
(( do_boot )) && install_boot
if [[ -n $apply ]]; then
  omarchy-theme-set "$apply"
  echo "theme: $apply"
fi
echo "done. Themes: omarchy-theme-set \"Swiss\" | \"Swiss Outline\" | \"Swiss Light\""
