#!/usr/bin/env python3
# Oversize keyboard wallpaper: a QWERTY of superellipse keycaps running off
# every edge, with "SWISS" typed across it. Each typed key lights up in the
# order it was pressed, the oldest faintest; the last key is solid accent.
#   gen-keyboard.py <out.png> <filled|outline> [colors.toml] [word]
import math, os, re, subprocess, sys

out, mode = sys.argv[1], sys.argv[2]
colors_path = sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser("~/.config/omarchy/themes/swiss/colors.toml")
word = (sys.argv[4] if len(sys.argv) > 4 else "SWISS").upper()
outline = mode == "outline"
W, H = 2880, 1800
STROKE = 2

pal = dict(re.findall(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6})"', open(colors_path).read(), re.M))
BG, FG = pal.get("background", "#101315"), pal.get("foreground", "#cacccc")
ACCENT = pal.get("bright_red") or pal.get("red", "#de6145")

U = H / 5.6          # key pitch: still oversize, but the typed word fits
GAP = U * 0.14       # space between caps
R = 5                # superellipse exponent, as everywhere else

# Rows as (legend, width in U); x starts at 0 for every row
ROWS = [
    [("`", 1)] + [(c, 1) for c in "1234567890-="] + [("⌫", 2)],
    [("tab", 1.5)] + [(c, 1) for c in "QWERTYUIOP[]"] + [("\\", 1.5)],
    [("caps", 1.75)] + [(c, 1) for c in "ASDFGHJKL;'"] + [("return", 2.25)],
    [("shift", 2.25)] + [(c, 1) for c in "ZXCVBNM,./"] + [("shift", 2.75)],
    [("fn", 1.25), ("ctrl", 1.25), ("alt", 1.25), ("", 6.25), ("alt", 1.25), ("ctrl", 1.25)],
]

# Place the board so the middle of the typed word sits in the middle of the screen
keys = {}
for r, row in enumerate(ROWS):
    x = 0
    for legend, w in row:
        keys.setdefault(legend, (r, x, w))
        x += w
cols = [keys[c][1] + 0.5 for c in word if c in keys]
rws = [keys[c][0] + 0.5 for c in word if c in keys]
ox = W / 2 - (min(cols) + max(cols)) / 2 * U
oy = H * 0.52 - (min(rws) + max(rws)) / 2 * U


def cap(x, y, w, h, n=R, steps=240):
    cx, cy, rx, ry = x + w / 2, y + h / 2, w / 2, h / 2
    # Stretch only the flat run of wide keys so the corners keep the key's curve
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        px = math.copysign(abs(c) ** (2 / n), c)
        py = math.copysign(abs(s) ** (2 / n), s)
        ex = (rx - ry) * (1 if px > 0 else -1) if rx > ry and abs(px) > 0 else 0
        pts.append("%.1f,%.1f" % (cx + ry * px + ex * min(1, abs(px) * 50), cy + ry * py))
    return "M" + " L".join(pts) + " Z"


# Typing order: the last press of each key decides its brightness
order = {}
for i, c in enumerate(word):
    order[c] = i
last = word[-1]
n = len(word)

shapes = []
for r, row in enumerate(ROWS):
    x = 0
    for legend, w in row:
        kx, ky = ox + x * U + GAP / 2, oy + r * U + GAP / 2
        kw, kh = w * U - GAP, U - GAP
        x += w
        if kx > W or ky > H or kx + kw < 0 or ky + kh < 0:
            continue
        d = cap(kx, ky, kw, kh)
        typed = legend in order
        age = (order[legend] + 1) / n if typed else 0     # 0..1, newest = 1
        lx, ly = kx + kh * 0.16, ky + kh * 0.16
        fs = kh * (0.17 if len(legend) == 1 else 0.11)
        if typed and legend == last:
            if outline:
                shapes.append('<path d="%s" fill="none" stroke="%s" stroke-width="%d"/>' % (d, ACCENT, STROKE * 2))
                ink = ACCENT
            else:
                shapes.append('<path d="%s" fill="%s"/>' % (d, ACCENT))
                ink = BG
            shapes.append('<text x="%.1f" y="%.1f" font-family="Nimbus Sans" font-weight="bold" font-size="%.1f" fill="%s" dominant-baseline="hanging">%s</text>'
                          % (lx, ly, fs * 1.6, ink, legend))
        elif typed:
            fill_a = 0.03 + 0.16 * age * age
            line_a = 0.14 + 0.62 * age * age
            if not outline:
                shapes.append('<path d="%s" fill="%s" fill-opacity="%.3f"/>' % (d, FG, fill_a))
            shapes.append('<path d="%s" fill="none" stroke="%s" stroke-opacity="%.3f" stroke-width="%d"/>' % (d, FG, line_a, STROKE))
            shapes.append('<text x="%.1f" y="%.1f" font-family="Nimbus Sans" font-weight="bold" font-size="%.1f" fill="%s" fill-opacity="%.3f" dominant-baseline="hanging">%s</text>'
                          % (lx, ly, fs * 1.6, FG, 0.2 + 0.7 * age * age, legend))
        else:
            shapes.append('<path d="%s" fill="none" stroke="%s" stroke-opacity="0.09" stroke-width="%d"/>' % (d, FG, STROKE))
            if legend:
                shapes.append('<text x="%.1f" y="%.1f" font-family="Nimbus Sans" font-size="%.1f" fill="%s" fill-opacity="0.13" dominant-baseline="hanging">%s</text>'
                              % (lx, ly, fs, FG, legend.replace("&", "&amp;").replace("<", "&lt;")))

svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="%s"/>%s</svg>'
       % (W, H, BG, "".join(shapes)))
subprocess.run(["magick", "-density", "96", "svg:-", "-depth", "8", "PNG24:" + out], input=svg.encode(), check=True)
print(out)
