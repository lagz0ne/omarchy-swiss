#!/bin/bash
# Renders the Plymouth "swiss" theme images at a 1800px-tall reference size.
set -euo pipefail
out=${1:?out dir}
mkdir -p "$out"
cd "$out"

FG='#cacccc'; MUTED='#4b4e55'; LABEL='#8b8d8e'; ERR='#de6145'
# The one warm accent (bell, selection): cursor and progress
ACCENT='#de6145'
BOLD=/usr/share/fonts/gsfonts/NimbusSans-Bold.otf
REG=/usr/share/fonts/gsfonts/NimbusSans-Regular.otf

# Superellipse (n=5) path, centred in a WxW box with inset p
squircle_path() {
  python3 - "$1" "$2" <<'PY'
import math, sys
w, p = float(sys.argv[1]), float(sys.argv[2])
r = w / 2 - p; c = w / 2; n = 5
pts = []
for i in range(360):
    t = 2 * math.pi * i / 360
    ct, st = math.cos(t), math.sin(t)
    x = c + r * math.copysign(abs(ct) ** (2 / n), ct)
    y = c + r * math.copysign(abs(st) ** (2 / n), st)
    pts.append(f"{x:.2f},{y:.2f}")
print("M" + " L".join(pts) + " Z")
PY
}

S=96          # squircle box
svg() { # name fill stroke strokewidth inset
  local d; d=$(squircle_path $S "$5")
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s"><path d="%s" fill="%s" stroke="%s" stroke-width="%s"/></svg>' \
    $S $S "$d" "$2" "$3" "$4" > "$1.svg"
  magick -background none -density 96 "$1.svg" "$1.png"; rm "$1.svg"
}
# Outline 7px at 96 lands at ~3px once Plymouth scales it to the 44px key, matching the QML stroke
svg squircle      none "$FG"  7 4
svg squircle-fill "$FG" none  0   4
svg squircle-err  none "$ERR" 7 4
svg squircle-accent none "$ACCENT" 7 4
svg squircle-fill-err "$ERR" none 0 4

txt() { # name font size color text [kerning]
  magick -background none -fill "$4" -font "$2" -pointsize "$3" -kerning "${6:-0}" label:"$5" -trim +repage "$1.png"
}
txt heading      "$BOLD" 230 "$FG"    "Unlock" -9
txt heading-off  "$BOLD" 230 "$FG"    "Power off" -9
txt heading-restart "$BOLD" 230 "$FG" "Restart" -9
txt label-system "$REG"  26  "$LABEL" "SYSTEM" 5
txt label        "$REG"  26  "$LABEL" "ENCRYPTED DISK" 5
txt sub-prompt   "$REG"  34  "$FG"    "Type passphrase and press return."
txt sub-booting  "$REG"  34  "$FG"    "Starting system…"
txt sub-resuming "$REG"  34  "$FG"    "Restoring session…"
txt sub-shutdown "$REG"  34  "$FG"    "Closing session…"
txt sub-retry    "$REG"  34  "$ERR"   "Not quite. Try again."

magick -size 1x1 xc:"$ACCENT" hair.png
magick -size 1x1 xc:"$MUTED" hair-track.png
