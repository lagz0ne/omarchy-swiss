#!/bin/bash
# Preview the boot splash from a text console (Ctrl+Alt+F3), not from Hyprland.
# Type anything at the prompt; it's thrown away. Wrong-passphrase state shows
# on the second prompt.
set -u
sudo plymouthd --mode=boot
sudo plymouth show-splash
for i in 1 2; do
  sudo plymouth ask-for-password --prompt="Passphrase" >/dev/null
  sleep 4
done
sleep 2
sudo plymouth quit
