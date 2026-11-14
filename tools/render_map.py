#!/usr/bin/env python3
"""Draws docs/ward-map.png from src/shared/MapData.luau (needs Pillow)."""
import os, re
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = open(os.path.join(ROOT, "src/shared/MapData.luau")).read()
rows = re.findall(r'^\t"([#.,:=A-Za-z0-9]+)",$', src, re.M)
regions = re.findall(r'Name = "([^"]+)", X1 = (\d+), Y1 = (\d+), X2 = (\d+), Y2 = (\d+)', src)
COLS, ROWS = len(rows[0]), len(rows)
C = 27; PX, PY = 20, 60; W = COLS * C + PX * 2; H = ROWS * C + PY + 130
img = Image.new("RGB", (W, H), (10, 12, 12)); d = ImageDraw.Draw(img)
def font(size, bold=False):
    try: return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/DejaVuSansMono{'-Bold' if bold else ''}.ttf", size)
    except Exception: return ImageFont.load_default()
F, FB, FT = font(12), font(13, True), font(22, True)
floor = {'.': (74, 76, 72), ',': (60, 62, 64), ':': (96, 104, 100), '=': (72, 62, 56)}
def nb(x, y):
    for dx, dy in ((0,-1),(1,0),(0,1),(-1,0)):
        xx, yy = x + dx, y + dy
        if 0 <= xx < COLS and 0 <= yy < ROWS and rows[yy][xx] in floor: return floor[rows[yy][xx]]
    return floor['.']
boxes = {'H': ((90, 130, 140), 'H'), 'P': ((255, 176, 64), 'P'), 'R': ((214, 60, 60), 'R'), 'F': ((200, 200, 190), 'F'),
         '1': ((120, 200, 255), '1'), '2': ((120, 200, 255), '2'), '3': ((120, 200, 255), '3'), '4': ((120, 200, 255), '4')}
for y, row in enumerate(rows):
    for x, ch in enumerate(row):
        x0, y0 = PX + x * C, PY + y * C; box = (x0, y0, x0 + C - 1, y0 + C - 1)
        if ch == '#': d.rectangle(box, fill=(26, 28, 27)); continue
        d.rectangle(box, fill=floor.get(ch) or nb(x, y))
        if ch == 'D':
            horiz = rows[y][x - 1] != '#' and rows[y][x + 1] != '#'
            d.rectangle((x0 + C//2 - 3, y0, x0 + C//2 + 3, y0 + C - 1) if horiz else (x0, y0 + C//2 - 3, x0 + C - 1, y0 + C//2 + 3), fill=(150, 126, 96))
        elif ch in boxes:
            col, letter = boxes[ch]
            d.rectangle((x0 + 3, y0 + 3, x0 + C - 4, y0 + C - 4), fill=(18, 18, 18), outline=col, width=2)
            d.text((x0 + C / 2, y0 + C / 2), letter, fill=col, font=FB, anchor="mm")
        elif ch in 'ES':
            col = (90, 255, 140) if ch == 'E' else (200, 30, 30)
            d.rectangle(box, fill=tuple(int(c * 0.4) for c in col)); d.text((x0 + C / 2, y0 + C / 2), ch, fill=col, font=FB, anchor="mm")
        elif ch in 'bm':
            d.ellipse((x0 + 8, y0 + 8, x0 + C - 9, y0 + C - 9), fill=(210, 190, 40) if ch == 'b' else (255, 120, 110))
for name, x1, y1, x2, y2 in regions:
    x1, y1, x2, y2 = map(int, (x1, y1, x2, y2))
    cx, cy = PX + (x1 - 1 + x2) * C / 2, PY + (y1 - 1 + y2) * C / 2
    tw = d.textlength(name, font=FB)
    d.rectangle((cx - tw / 2 - 4, cy - 9, cx + tw / 2 + 4, cy + 9), fill=(0, 0, 0)); d.text((cx, cy), name, fill=(235, 235, 225), font=FB, anchor="mm")
d.text((PX, 14), "HOLLOW SIGNAL  —  MERIDIAN GENERAL, WARD C", fill=(235, 235, 225), font=FT)
d.text((W - PX, 22), "rendered from src/shared/MapData.luau  ·  1 cell = 8 studs", fill=(140, 140, 135), font=F, anchor="ra")
legend = [("E", (90, 255, 140), "elevator: arrive, and leave once the evidence is sent"), ("P", (255, 176, 64), "tube station (2 canisters each)"),
          ("R", (214, 60, 60), "recovery bed (where you wake after a grab)"), ("F", (200, 200, 190), "filing cabinet (6 of 9 hold case files)"),
          ("H", (90, 130, 140), "locker (hide)"), ("1-4", (120, 200, 255), "dispensers: Sedative, Crash Cart, Code Blue, Scanner"),
          ("S", (200, 30, 30), "where HUSH starts its rounds"), ("●", (255, 120, 110), "mimic decoy spot"), ("●", (210, 190, 40), "battery spawn")]
ly = PY + ROWS * C + 16
for i, (sym, col, text) in enumerate(legend):
    lx = PX + (i % 2) * 610; yy = ly + (i // 2) * 22
    d.text((lx, yy), sym, fill=col, font=FB); d.text((lx + 44, yy), text, fill=(200, 200, 195), font=F)
out = os.path.join(ROOT, "docs/ward-map.png"); img.save(out, optimize=True); print(out, img.size)
