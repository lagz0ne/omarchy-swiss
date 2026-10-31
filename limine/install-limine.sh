#!/bin/bash
# Installs the Swiss Limine look. Run as root (pkexec). Keeps every boot entry
# and replaces only the global header (everything above the first "/" entry).
set -euo pipefail
src=$(dirname "$(readlink -f "$0")")
conf=/boot/limine.conf

install -m644 "$src/swiss-boot.png" /boot/swiss-boot.png
# The menu font is built here from kbd's Terminus (GPL), not shipped in the repo
python3 "$src/gen-font.py" /boot/swiss-font.bin >/dev/null
chmod 644 /boot/swiss-font.bin
# Keep the very first backup: it is the only copy of the stock header
[ -e "$conf.pre-swiss" ] || cp -a "$conf" "$conf.pre-swiss"
{ cat "$src/limine-header.conf"; awk 'f || /^\//{f=1; print}' "$conf"; } > "$conf.new"
grep -q '^/' "$conf.new"
mv "$conf.new" "$conf"
echo "installed; backup at $conf.pre-swiss"
