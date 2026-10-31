#!/bin/bash
# Mirrors each theme in themes/ into its own repo, the way Omarchy themes are
# normally shipped, so it installs with:
#   omarchy-theme-install https://github.com/lagz0ne/omarchy-<theme>-theme
# The bundle (this repo) stays the source of truth; run this after changing a theme.
#   tools/publish-themes.sh [--create]   --create makes the GitHub repos first
set -euo pipefail
src=$(dirname "$(dirname "$(readlink -f "$0")")")
owner=${OWNER:-lagz0ne}
work=${WORK:-$HOME/.cache/omarchy-swiss/theme-repos}
create=0; [[ ${1:-} == --create ]] && create=1
# Let gh supply the GitHub credentials, without touching global git config
g() { git -c credential.helper= -c credential.helper='!gh auth git-credential' "$@"; }

declare -A title=([swiss]="Swiss" [swiss-outline]="Swiss Outline" [swiss-light]="Swiss Light")
declare -A blurb=(
  [swiss]="Dark and quiet: hairline borders, squircle corners, greyscale with one warm orange."
  [swiss-outline]="Swiss with every fill drawn as a 1px outline; the focused workspace becomes an orange outline."
  [swiss-light]="Swiss in ink on warm paper, with a deeper orange accent."
)

for t in swiss swiss-outline swiss-light; do
  repo="omarchy-$t-theme"
  dir="$work/$repo"
  if [[ ! -d $dir/.git ]]; then
    if (( create )) && ! gh repo view "$owner/$repo" >/dev/null 2>&1; then
      gh repo create "$owner/$repo" --public --description "${title[$t]} theme for Omarchy. ${blurb[$t]}" >/dev/null
    fi
    rm -rf "$dir"; mkdir -p "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" remote add origin "https://github.com/$owner/$repo.git"
    g -C "$dir" fetch -q origin 2>/dev/null && git -C "$dir" reset -q --hard origin/main 2>/dev/null || true
  fi
  # Theme files at the repo root, like every Omarchy theme
  find "$dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -r "$src/themes/$t/." "$dir/"
  cp "$src/LICENSE" "$dir/LICENSE"
  cat > "$dir/README.md" <<MD
# ${title[$t]} for Omarchy

${blurb[$t]}

[![Preview](https://raw.githubusercontent.com/$owner/omarchy-swiss/main/docs/$t.webp)](https://github.com/$owner/omarchy-swiss/releases/download/v1.0/omarchy-$t.mp4)

<sub>Click the preview for the full-quality video.</sub>

## Install

\`\`\`sh
omarchy-theme-install https://github.com/$owner/$repo
\`\`\`

Then pick **${title[$t]}** in Style → Theme, or run \`omarchy-theme-set "${title[$t]}"\`.

Wallpapers are oversize squircles, including a keyboard with S‑W‑I‑S‑S typed across it, the latest key in the accent.

## The full look

This theme is one part of [omarchy-swiss](https://github.com/$owner/omarchy-swiss). The bundle adds matching Limine, Plymouth and SDDM screens, a Swiss lock screen and polkit prompt, and a squircle screensaver, all on one type grid. Some touches need the bundle's plugins: \`[bar] tile-style\` (outline workspace tiles) only takes effect with its workspaces plugin.

Generated from the bundle by \`tools/publish-themes.sh\`; please send changes there.

MIT. Started from Omarchy's Solitude theme (MIT, © David Heinemeier Hansson).
MD
  git -C "$dir" add -A
  if ! git -C "$dir" diff --cached --quiet; then
    git -C "$dir" -c user.name="$(git -C "$src" config user.name)" -c user.email="$(git -C "$src" config user.email)" \
      commit -q -m "Sync from omarchy-swiss $(git -C "$src" rev-parse --short HEAD)"
    g -C "$dir" push -q -u origin main
    echo "$repo: pushed"
  else
    echo "$repo: up to date"
  fi
done
