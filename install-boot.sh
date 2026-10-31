#!/bin/bash
# System half of omarchy-swiss: Plymouth (boot / disk unlock / shutdown), SDDM
# (sign in) and the Limine boot menu, then rebuilds the boot image so Plymouth
# actually reaches the screen. Run as root: pkexec ./install-boot.sh
set -euo pipefail
src=$(dirname "$(readlink -f "$0")")
[[ $EUID -eq 0 ]] || { echo "run as root (pkexec $0)" >&2; exit 1; }

install -d /usr/share/plymouth/themes/swiss
install -m644 "$src"/plymouth/* /usr/share/plymouth/themes/swiss/
plymouth-set-default-theme swiss

install -d /usr/share/sddm/themes/swiss /etc/sddm.conf.d
install -m644 "$src"/sddm/* /usr/share/sddm/themes/swiss/
printf '[Theme]\nCurrent=swiss\n' > /etc/sddm.conf.d/zz-swiss.conf

bash "$src/limine/install-limine.sh"

if command -v limine-mkinitcpio >/dev/null; then
  limine-mkinitcpio 2>&1 | grep -E 'successful|ERROR' || true
else
  echo "limine-mkinitcpio not found: rebuild the initramfs yourself so Plymouth picks up the theme" >&2
fi

# Confirm the theme really is inside the boot image
uki=/boot/EFI/Linux/omarchy_linux-omarchy.efi
if [[ -f $uki ]]; then
  d=$(mktemp -d)
  objcopy -O binary --only-section=.initrd "$uki" "$d/initrd"
  mkdir "$d/x"; (cd "$d/x" && lsinitcpio -x "$d/initrd" >/dev/null 2>&1) || true
  if cmp -s "$d/x/usr/share/plymouth/themes/swiss/swiss.script" "$src/plymouth/swiss.script"; then
    echo "boot image: swiss Plymouth theme present"
  else
    echo "boot image: swiss Plymouth theme NOT found" >&2
  fi
  rm -rf "$d"
fi
echo "plymouth default: $(plymouth-set-default-theme)"
