#!/usr/bin/env python3
# Builds the Limine menu font: Terminus 8x16 (from kbd's Lat2-Terminus16)
# re-ordered into code page 437, the layout Limine expects. Box-drawing and
# arrow glyphs the Latin-2 set lacks are drawn here as 1px hairlines, which
# suits the Swiss screens better than VGA's double-weight lines anyway.
import gzip, struct, sys

out = sys.argv[1]
d = gzip.open("/usr/share/kbd/consolefonts/Lat2-Terminus16.psfu.gz").read()
magic, ver, hs, flags, n, bpg, h, w = struct.unpack("<8I", d[:32])
assert (w, h, bpg) == (8, 16, 16)
glyphs = [d[hs + i * bpg: hs + (i + 1) * bpg] for i in range(n)]

# Unicode table: per glyph, UTF-8 sequences separated by 0xFE (sequences) / 0xFF (end)
umap = {}
p = hs + n * bpg
for i in range(n):
    end = d.index(b"\xff", p)
    for seq in d[p:end].split(b"\xfe")[0:1]:
        for ch in seq.decode("utf-8", "ignore"):
            umap.setdefault(ch, i)
    p = end + 1

cp437 = bytes(range(256)).decode("cp437")
# cp437 decode maps 0x00-0x1f to control chars; use the graphical forms
low = "\u0000☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼"
chars = low + cp437[32:]


def blank():
    return bytearray(16)


def hline(g, y, x0=0, x1=8):
    for x in range(x0, x1):
        g[y] |= 0x80 >> x


def vline(g, x, y0=0, y1=16):
    for y in range(y0, y1):
        g[y] |= 0x80 >> x


CX, CY = 3, 8  # hairline centre
drawn = {}
def box(ch, up=False, down=False, left=False, right=False):
    g = blank()
    if left: hline(g, CY, 0, CX + 1)
    if right: hline(g, CY, CX, 8)
    if up: vline(g, CX, 0, CY + 1)
    if down: vline(g, CX, CY, 16)
    drawn[ch] = bytes(g)

box("─", left=True, right=True); box("│", up=True, down=True)
box("┌", down=True, right=True); box("┐", down=True, left=True)
box("└", up=True, right=True); box("┘", up=True, left=True)
box("├", up=True, down=True, right=True); box("┤", up=True, down=True, left=True)
box("┬", down=True, left=True, right=True); box("┴", up=True, left=True, right=True)
box("┼", up=True, down=True, left=True, right=True)
for a, b in (("═", "─"), ("║", "│"), ("╔", "┌"), ("╗", "┐"), ("╚", "└"), ("╝", "┘"),
             ("╠", "├"), ("╣", "┤"), ("╦", "┬"), ("╩", "┴"), ("╬", "┼")):
    drawn[a] = drawn[b]
g = blank(); hline(g, CY, 0, 7); g[CY - 2] |= 0x08; g[CY - 1] |= 0x04; g[CY + 1] |= 0x04; g[CY + 2] |= 0x08; g[CY] |= 0x02
drawn["→"] = bytes(g)
g = blank(); hline(g, CY, 1, 8); g[CY - 2] |= 0x20; g[CY - 1] |= 0x40; g[CY + 1] |= 0x40; g[CY + 2] |= 0x20; g[CY] |= 0x80
drawn["←"] = bytes(g)
# Limine marks the selected entry with ► (CP437 0x10): a small solid wedge
g = blank()
for i, row in enumerate((0x40, 0x60, 0x70, 0x78, 0x70, 0x60, 0x40)):
    g[CY - 3 + i] = row
drawn["►"] = bytes(g)
for ch in "░▒▓█▄▀▌▐■":
    g = bytearray(b"\xff" * 16) if ch in "█■" else blank()
    drawn[ch] = bytes(g)

font, missing = bytearray(), []
for ch in chars:
    if ch in drawn: font += drawn[ch]
    elif ch in umap: font += glyphs[umap[ch]]
    else:
        font += bytes(16)
        missing.append(ch)
open(out, "wb").write(font)
print("wrote", out, len(font), "bytes; blank:", "".join(missing[:60]))
