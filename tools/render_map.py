#!/usr/bin/env python3
"""Draws docs/ward-map.png from src/shared/MapData.luau (needs Pillow).

Room labels are placed by search, not by formula: a label may only sit where
it is fully inside its room and touches no icon, door or other label. The
script fails if any text overlaps anything."""
import os, re, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FONTS = os.path.join(ROOT, "tools", "fonts")
src = open(os.path.join(ROOT, "src/shared/MapData.luau")).read()
rows = re.findall(r'^\t"([#.,:=A-Za-z0-9]+)",$', src, re.M)
regions = [(n, int(a), int(b), int(c), int(d)) for n, a, b, c, d in re.findall(r'Name = "([^"]+)", X1 = (\d+), Y1 = (\d+), X2 = (\d+), Y2 = (\d+)', src)]
COLS, ROWS = len(rows[0]), len(rows)
C = 30; PX, PY = 24, 78
GAP = 8  # minimum clear space between a room label and any icon, door or other label

def font(name, size):
    try: return ImageFont.truetype(os.path.join(FONTS, name), size)
    except OSError: return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", size)
F_TITLE, F_ROOM, F_ICON, F_TEXT = font("Creepster-Regular.ttf", 40), font("Creepster-Regular.ttf", 21), font("SpecialElite-Regular.ttf", 17), font("SpecialElite-Regular.ttf", 15)

FLOOR = {'.': (74, 76, 72), ',': (60, 62, 64), ':': (96, 104, 100), '=': (72, 62, 56)}
BOXES = {'H': (90, 130, 140), 'P': (255, 176, 64), 'R': (214, 60, 60), 'F': (200, 200, 190), '1': (120, 200, 255), '2': (120, 200, 255), '3': (120, 200, 255), '4': (120, 200, 255)}
LEGEND = [("E", (90, 255, 140), "Elevator: arrive here, leave here once the evidence is sent"), ("P", (255, 176, 64), "Tube station (2 canisters each)"),
          ("R", (214, 60, 60), "Recovery bed (where you wake after a grab)"), ("F", (200, 200, 190), "Filing cabinet (6 of 9 hold case files)"),
          ("H", (90, 130, 140), "Locker (hide)"), ("1-4", (120, 200, 255), "Dispensers: Sedative, Crash Cart, Code Blue, Scanner"),
          ("S", (200, 30, 30), "Where HUSH starts its rounds"), ("dot", (255, 120, 110), "Mimic decoy spot"), ("dot", (210, 190, 40), "Battery spawn")]

def cell(x, y): return (PX + x * C, PY + y * C, PX + (x + 1) * C, PY + (y + 1) * C)
def hit(a, b): return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]
def size(text, f):
    box = f.getbbox(text); return box[2] - box[0], box[3] - box[1]

W = COLS * C + PX * 2
legend_rows = (len(LEGEND) + 1) // 2
H = PY + ROWS * C + 28 + legend_rows * 28 + 16
img = Image.new("RGB", (W, H), (10, 12, 12)); d = ImageDraw.Draw(img)
occupied = []  # (rect, what) for everything that text must not touch
texts = []     # (rect, what) for every piece of text drawn

# --- cells -----------------------------------------------------------------
for y, row in enumerate(rows):
    for x, ch in enumerate(row):
        box = cell(x, y); x0, y0 = box[0], box[1]
        if ch == '#': d.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=(26, 28, 27)); continue
        fill = FLOOR.get(ch)
        if not fill:
            near = [FLOOR[rows[y + dy][x + dx]] for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)) if 0 <= y + dy < ROWS and 0 <= x + dx < COLS and rows[y + dy][x + dx] in FLOOR]
            fill = near[0] if near else FLOOR['.']
        d.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=fill)
        if ch in FLOOR: continue
        occupied.append((box, f"icon '{ch}' at {x + 1},{y + 1}"))
        if ch == 'D':
            horiz = rows[y][x - 1] != '#' and rows[y][x + 1] != '#'
            d.rectangle((x0 + C // 2 - 3, y0, x0 + C // 2 + 3, y0 + C - 1) if horiz else (x0, y0 + C // 2 - 3, x0 + C - 1, y0 + C // 2 + 3), fill=(150, 126, 96))
        elif ch in BOXES:
            d.rectangle((x0 + 3, y0 + 3, x0 + C - 4, y0 + C - 4), fill=(18, 18, 18), outline=BOXES[ch], width=2)
            d.text((x0 + C / 2, y0 + C / 2 + 1), ch, fill=BOXES[ch], font=F_ICON, anchor="mm")
        elif ch in 'ES':
            col = (90, 255, 140) if ch == 'E' else (200, 30, 30)
            d.rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=tuple(int(c * 0.4) for c in col)); d.text((x0 + C / 2, y0 + C / 2 + 1), ch, fill=col, font=F_ICON, anchor="mm")
        elif ch in 'bm':
            d.ellipse((x0 + 9, y0 + 9, x0 + C - 10, y0 + C - 10), fill=(210, 190, 40) if ch == 'b' else (255, 120, 110))

# --- room labels: search for a spot that touches nothing ----------------------
def place(name, x1, y1, x2, y2):
    room = (PX + (x1 - 1) * C + 3, PY + (y1 - 1) * C + 3, PX + x2 * C - 3, PY + y2 * C - 3)
    for f in (F_ROOM, font("Creepster-Regular.ttf", 18), font("Creepster-Regular.ttf", 15)):
        tw, th = size(name, f); bw, bh = tw + 12, th + 10
        cx0, cy0 = (room[0] + room[2]) / 2, (room[1] + room[3]) / 2
        ys = sorted({room[1] + bh / 2 + i * (C / 2) for i in range(int((room[3] - room[1] - bh) // (C / 2)) + 1)} | {cy0}, key=lambda v: abs(v - cy0))
        xs = sorted({room[0] + bw / 2 + i * (C / 2) for i in range(int((room[2] - room[0] - bw) // (C / 2)) + 1)} | {cx0}, key=lambda v: abs(v - cx0))
        for cy in ys:
            for cx in xs:
                rect = (cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2)
                inside = rect[0] >= room[0] and rect[1] >= room[1] and rect[2] <= room[2] and rect[3] <= room[3]
                roomy = (rect[0] - GAP, rect[1] - GAP, rect[2] + GAP, rect[3] + GAP)  # keep clear air around the label too
                if inside and not any(hit(roomy, o[0]) for o in occupied) and not any(hit(roomy, t[0]) for t in texts):
                    return rect, f
    sys.exit(f"no free spot for the label '{name}'")

for name, x1, y1, x2, y2 in regions:
    rect, f = place(name, x1, y1, x2, y2)
    d.rectangle(rect, fill=(0, 0, 0))
    d.text(((rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2 + 1), name, fill=(236, 230, 214), font=f, anchor="mm")
    texts.append((rect, f"label '{name}'"))

# --- title, legend -------------------------------------------------------------
def write(x, y, text, f, fill, what):
    tw, th = size(text, f); rect = (x, y, x + tw, y + th + 6)
    d.text((x, y), text, fill=fill, font=f); texts.append((rect, what)); return rect

title = write(PX, 16, "HOLLOW SIGNAL  -  MERIDIAN GENERAL, WARD C", F_TITLE, (236, 230, 214), "title")
note = "drawn from src/shared/MapData.luau   1 cell = 8 studs"
nw, _ = size(note, F_TEXT)
write(W - PX - nw, 34 if W - PX - nw > title[2] + 24 else 58, note, F_TEXT, (140, 140, 135), "note")
ly = PY + ROWS * C + 28
col_w = (W - PX * 2) // 2
for i, (sym, col, text) in enumerate(LEGEND):
    lx, yy = PX + (i % 2) * col_w, ly + (i // 2) * 28
    if sym == "dot": d.ellipse((lx + 6, yy + 3, lx + 18, yy + 15), fill=col); texts.append(((lx, yy, lx + 24, yy + 18), f"legend dot {i}"))
    else: write(lx, yy, sym, F_ICON, col, f"legend symbol {sym}")
    rect = write(lx + 50, yy, text, F_TEXT, (206, 204, 196), f"legend text {i}")
    assert rect[2] < lx + col_w - 10 or i % 2 == 1 and rect[2] < W - PX, f"legend text {i} is too wide"

# --- nothing may overlap anything ------------------------------------------------
problems = [f"{a[1]}  x  {b[1]}" for i, a in enumerate(texts) for b in texts[i + 1:] if hit(a[0], b[0])]
problems += [f"{t[1]}  x  {o[1]}" for t in texts for o in occupied if hit(t[0], o[0])]
problems += [f"{t[1]} is off the image" for t in texts if t[0][0] < 0 or t[0][1] < 0 or t[0][2] > W or t[0][3] > H]
if problems: sys.exit("OVERLAPS:\n  " + "\n  ".join(problems))
out = os.path.join(ROOT, "docs/ward-map.png"); os.makedirs(os.path.dirname(out), exist_ok=True); img.save(out, optimize=True)
print(f"{os.path.relpath(out, ROOT)} {img.size}: {len(texts)} text items, {len(occupied)} icons, 0 overlaps")
