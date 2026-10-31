#!/bin/bash
# Renders the Limine "swiss" wallpaper: the lock screen's bottom-left type
# block without the key row, plus the muted hairline track along the bottom.
set -euo pipefail
out=${1:?out png}
W=${2:-2880}; H=${3:-1800}

BG='#101315'; FG='#cacccc'; MUTED='#4b4e55'; LABEL='#8b8d8e'; ACCENT='#de6145'
BOLD=/usr/share/fonts/gsfonts/NimbusSans-Bold.otf
REG=/usr/share/fonts/gsfonts/NimbusSans-Regular.otf
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

px() { awk -v v="$1" -v h="$H" 'BEGIN { printf "%.0f", v * h / 1800 }'; }
M=$(px 120)

txt() { # name font size color text kerning
  magick -background none -fill "$4" -font "$2" -pointsize "$(px "$3")" -kerning "$(px "$6")" label:"$5" -trim +repage "$tmp/$1.png"
}
txt label   "$REG"  26  "$LABEL" "ZENBOOK DUO" 5
txt heading "$BOLD" 230 "$FG"    "Boot" -9
txt sub     "$REG"  34  "$FG"    "Arrow keys to choose, return to start." 0

# Same block position as Plymouth/lock: the sub line ends where the key row
# would start (key 44 + gap 40), heading 154 above that, label 99 above it.
h() { magick identify -format %h "$tmp/$1.png"; }
sub_bottom=$((H - M - $(px 84)))
sub_y=$((sub_bottom - $(h sub)))
heading_y=$((sub_bottom - $(px 154) - $(h heading)))
label_y=$((heading_y - $(px 99) - $(h label)))

magick -size "${W}x${H}" xc:"$BG" \
  "$tmp/label.png"   -geometry "+$M+$label_y" -composite \
  "$tmp/heading.png" -geometry "+$M+$heading_y" -composite \
  "$tmp/sub.png"     -geometry "+$M+$sub_y" -composite \
  -fill "$MUTED" -draw "rectangle 0,$((H - 2)) $W,$H" \
  -strip PNG24:"$out"
