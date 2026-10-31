#!/usr/bin/env python3
# Derives the "Swiss Outline" Omarchy theme from Swiss: identical palette, every
# control/menu fill drawn as a 1px outline instead, the focused workspace tile as
# an accent outline, and outline-only wallpapers. Re-run after changing Swiss.
#   tools/make-outline.py [src-theme-dir] [dst-theme-dir]  (defaults: themes/ in this repo)
import os, re, shutil, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else f"{REPO}/themes/swiss"
dst = sys.argv[2] if len(sys.argv) > 2 else f"{REPO}/themes/swiss-outline"


def section(text, name):
    m = re.search(r"^\[%s\]\n" % re.escape(name), text, re.M)
    end = text.find("\n[", m.start() + 1)
    return m.start(), len(text) if end < 0 else end


def set_keys(text, name, pairs):
    i, j = section(text, name)
    sec = text[i:j]
    for key, value in pairs:
        pat = re.compile(r"^(%s\s*=\s*).*$" % re.escape(key), re.M)
        if pat.search(sec):
            sec = pat.sub(lambda m: m.group(1) + value, sec, count=1)
        else:
            sec = sec.rstrip("\n") + "\n%-25s = %s\n" % (key, value)
    return text[:i] + sec + text[j:]


if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.copytree(src, dst, ignore=shutil.ignore_patterns("0-squircle-*.png", "*.jpg", "*.jpeg"))

shell = open(f"{dst}/shell.toml").read()
shell = "# Swiss Outline: the Swiss theme with every fill drawn as a 1px outline (tools/make-outline.py).\n" + shell
accent = dict(re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6})"', open(f"{dst}/colors.toml").read(), re.M)).get("bright_red", "#de6145")
shell = set_keys(shell, "bar", [("tile-style", '"outline"'), ("tile-focus", '"%s"' % accent)])
shell = set_keys(shell, "controls", [
    ("normal-fill-alpha", "0.0"), ("hover-cursor-fill-alpha", "0.0"), ("hover-cursor-border-alpha", "0.6"),
    ("focus-fill-alpha", "0.0"), ("focus-border-alpha", "0.6"), ("selected-fill-alpha", "0.0"),
    ("selected-border-width", "1"), ("selected-border-alpha", "1.0"), ("pressed-fill-alpha", "0.0"),
])
for name in ("launcher", "menu"):
    shell = set_keys(shell, name, [
        ("selected-background-alpha", "0.0"), ("selected-border-alpha", "1.0"),
        ("selected-border-width", "1"), ("selected-text", '"#cacccc"'),
    ])
open(f"{dst}/shell.toml", "w").write(shell)

subprocess.run([sys.executable, f"{REPO}/wallpaper/gen-wallpapers.py", f"{dst}/backgrounds", "outline", f"{dst}/colors.toml"], check=True)
subprocess.run([sys.executable, f"{REPO}/wallpaper/gen-keyboard.py", f"{dst}/backgrounds/0-squircle-0-keyboard.png", "outline", f"{dst}/colors.toml"], check=True)
subprocess.run(["magick", f"{dst}/backgrounds/0-squircle-0-keyboard.png", "-resize", "1440x900", "-strip", f"PNG24:{dst}/preview.png"], check=True)
print("done:", dst)
