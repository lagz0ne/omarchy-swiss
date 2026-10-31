#!/usr/bin/env python3
# Renders the oversize squircle wallpapers for the Swiss themes.
#   gen-wallpapers.py <out-dir> <filled|outline> [colors.toml]
# Four compositions at 2880x1800: field, tide, ripple, corner. Shapes are
# superellipses (n=5) like every other Swiss surface; strokes are 2px (1px at
# the 2.25 desktop scale). Kept very quiet so windows always win; one shape
# per wallpaper takes the theme's warm accent (bright_red).
import math, os, re, subprocess, sys

out, mode = sys.argv[1], sys.argv[2]
colors_path = sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser("~/.config/omarchy/themes/swiss/colors.toml")
outline = mode == "outline"
W, H, M = 2880, 1800, 120
STROKE = 2

pal = dict(re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6})"', open(colors_path).read(), re.M))
BG, FG = pal.get("background", "#101315"), pal.get("foreground", "#cacccc")
ACCENT = pal.get("bright_red") or pal.get("red", "#de6145")


def squircle(cx, cy, size, n=5, steps=240):
    r = size / 2
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        pts.append("%.1f,%.1f" % (cx + r * math.copysign(abs(c) ** (2 / n), c),
                                  cy + r * math.copysign(abs(s) ** (2 / n), s)))
    return "M" + " L".join(pts) + " Z"


class Canvas:
    def __init__(self):
        self.shapes = []

    def line(self, cx, cy, size, alpha, color=None):
        self.shapes.append('<path d="%s" fill="none" stroke="%s" stroke-opacity="%.3f" stroke-width="%d"/>'
                           % (squircle(cx, cy, size - STROKE), color or FG, alpha, STROKE))

    def fill(self, cx, cy, size, alpha, color=None):
        # Outline-only themes draw every fill as its outline instead
        if outline:
            self.line(cx, cy, size, min(1, alpha * 3), color)
        else:
            self.shapes.append('<path d="%s" fill="%s" fill-opacity="%.3f"/>'
                               % (squircle(cx, cy, size), color or FG, alpha))

    def save(self, name):
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">'
               '<rect width="100%%" height="100%%" fill="%s"/>%s</svg>' % (W, H, BG, "".join(self.shapes)))
        path = os.path.join(out, name)
        subprocess.run(["magick", "-density", "96", "svg:-", "-depth", "8", "PNG24:" + path],
                       input=svg.encode(), check=True)
        print(path)


def field():
    c = Canvas()
    cell = H / 3.1
    size = cell * 0.84
    ox, oy = -cell * 0.35, -cell * 0.22
    cols, rows = int(W / cell) + 2, int(H / cell) + 2
    for r in range(rows):
        for col in range(cols):
            x, y = ox + col * cell + cell / 2, oy + r * cell + cell / 2
            w = 0.5 + 0.5 * math.sin(-(r + col) * 0.8 + 1.2)
            if (col, r) == (3, 1):
                c.line(x, y, size, 0.75, ACCENT)
            elif (r + col) % 3 == 0:
                c.fill(x, y, size, 0.025 + 0.02 * w)
            else:
                c.line(x, y, size, 0.05 + 0.16 * w * w)
    c.save("0-squircle-1-field.png")


def tide():
    c = Canvas()
    shapes = [  # x, y, size (fractions of H), alpha
        (1.02, 0.55, 0.78, 0.16), (1.30, 0.30, 0.52, 0.12), (0.80, 0.86, 0.46, 0.20),
        (1.18, 0.98, 0.62, 0.10), (0.95, 0.18, 0.30, 0.22), (1.42, 0.78, 0.36, 0.14),
    ]
    for i, (x, y, s, a) in enumerate(shapes):
        if i == 3:
            c.fill(x * H, y * H, s * H, 0.03)
        else:
            c.line(x * H, y * H, s * H, a)
    c.line(0.80 * H, 0.86 * H, 0.18 * H, 0.8, ACCENT)
    c.save("0-squircle-2-tide.png")


def ripple():
    c = Canvas()
    cx, cy = W * 0.70, H * 0.64
    for i in range(1, 9):
        size = H * 0.14 * i ** 1.25
        c.line(cx, cy, size, max(0.03, 0.24 - i * 0.025))
    c.fill(cx, cy, H * 0.07, 0.9, ACCENT)
    c.save("0-squircle-3-ripple.png")


def corner():
    c = Canvas()
    c.line(W - H * 0.12, H * 0.92, H * 1.5, 0.18)
    c.line(W - H * 0.12, H * 0.92, H * 1.1, 0.07)
    c.fill(W - H * 0.12, H * 0.92, H * 0.7, 0.03)
    # The accent sits on the margin grid the lock and boot screens use
    key = 44
    c.fill(M + key / 2, H - M - key / 2, key, 0.9, ACCENT)
    c.save("0-squircle-4-corner.png")


os.makedirs(out, exist_ok=True)
field(); tide(); ripple(); corner()
