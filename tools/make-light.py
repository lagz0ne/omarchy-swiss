#!/usr/bin/env python3
# Derives the "Swiss Light" Omarchy theme from Swiss: same structure and
# tokens, paper and ink swapped, greys re-tuned to read on paper, and the
# orange deepened a little so it holds contrast. Re-run after changing Swiss.
#   tools/make-light.py [src-theme-dir] [dst-theme-dir]  (defaults: themes/ in this repo)
import os, re, shutil, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

home = os.path.expanduser("~")
src = sys.argv[1] if len(sys.argv) > 1 else f"{REPO}/themes/swiss"
dst = sys.argv[2] if len(sys.argv) > 2 else f"{REPO}/themes/swiss-light"

COLORS = '''mode = "light"

accent = "#6c7176"
selection = "#d9d8d2"
muted = "#b9bab7"

background = "#f1f0ec"
dark_background = "#e8e7e2"
darker_background = "#dfded8"
lighter_background = "#f7f6f3"

foreground = "#16191b"
dark_foreground = "#b9bab7"
light_foreground = "#3a3d40"
bright_foreground = "#5d6367"

hyprland_active_border = "rgba(16191bff)"
hyprland_inactive_border = "rgba(16191b38)"
active_border_color = "#16191b"
active_tab_background = "#6c7176"

red = "#5d6367"
yellow = "#2a2d30"
green = "#4f5458"
cyan = "#6e6e6e"
blue = "#43484c"
magenta = "#55585a"

bright_red = "#cc4b2c"
bright_yellow = "#7a7365"
bright_green = "#d9d8d2"
bright_cyan = "#6e6e6e"
bright_blue = "#8a8f93"
bright_magenta = "#6a6a6a"
'''

# Dark Swiss value -> light counterpart, for shell.toml, btop and hyprland
SWAP = {
    "#101315": "#f1f0ec", "#cacccc": "#16191b", "#798186": "#6c7176", "#565d60": "#8a8f93",
    "#8b8d8e": "#74777a", "#4b4e55": "#b9bab7", "#de6145": "#cc4b2c", "#d9dbdc": "#2a2d30",
    "#9fa5a9": "#4f5458", "#343d41": "#d9d8d2", "#a5aeb4": "#5d6367", "#a3a6a7": "#6a6d70",
    "#cbc2be": "#3a3d40", "#0c0e10": "#e8e7e2", "#080a0b": "#dfded8",
    "rgba(caccccff)": "rgba(16191bff)", "rgba(4b4e5580)": "rgba(16191b38)",
}


def swap(text):
    pat = re.compile("|".join(re.escape(k) for k in sorted(SWAP, key=len, reverse=True)), re.I)
    return pat.sub(lambda m: SWAP[m.group(0).lower()], text)


if os.path.exists(dst):
    shutil.rmtree(dst)
os.makedirs(f"{dst}/backgrounds")
open(f"{dst}/colors.toml", "w").write(COLORS)
for name in ("shell.toml", "btop.theme", "hyprland.lua"):
    text = swap(open(f"{src}/{name}").read())
    if name == "shell.toml":
        text = "# Swiss Light: generated from Swiss by tools/make-light.py in omarchy-swiss\n" + text
    open(f"{dst}/{name}", "w").write(text)
open(f"{dst}/icons.theme", "w").write("Yaru-sage\n")
open(f"{dst}/neovim.lua", "w").write('''return {
  { "kepano/flexoki-neovim", priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "flexoki-light",
    },
  },
}
''')
open(f"{dst}/vscode.json", "w").write('{\n  "name": "flexoki-light",\n  "extension": "shadesOfBuntu.flexoki-light"\n}\n')
# Wallpapers: the oversize squircles, drawn in ink on paper
subprocess.run([sys.executable, f"{REPO}/wallpaper/gen-wallpapers.py",
                f"{dst}/backgrounds", "filled", f"{dst}/colors.toml"], check=True)
subprocess.run([sys.executable, f"{REPO}/wallpaper/gen-keyboard.py",
                f"{dst}/backgrounds/0-squircle-0-keyboard.png", "filled", f"{dst}/colors.toml"], check=True)
leftover = sorted(set(re.findall(r"#[0-9a-fA-F]{6}", open(f"{dst}/shell.toml").read() + open(f"{dst}/btop.theme").read())) - set(SWAP.values()))
subprocess.run(["magick", f"{dst}/backgrounds/0-squircle-0-keyboard.png", "-resize", "1440x900", "-strip", f"PNG24:{dst}/preview.png"], check=True)
print("done:", dst, "| unmapped colors:", leftover or "none")
