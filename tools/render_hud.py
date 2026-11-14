#!/usr/bin/env python3
"""Draws docs/hud-layout.png: the HUD exactly where Layout.luau puts it, with
the real typefaces and sample text, at a laptop size and a phone size.
It is a layout diagram generated from the game's own layout table - not a
screenshot of the running game. Needs Pillow and node."""
import json, os, subprocess
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
data = json.loads(subprocess.run(["node", os.path.join(ROOT, "tools/typecheck/test-layout.mjs"), "--json"], capture_output=True, text=True, check=True).stdout)
OSD, RED, AMBER, GREEN, PAPER = (235, 235, 225), (214, 40, 40), (255, 176, 64), (120, 255, 170), (222, 213, 190)
def font(name, size): return ImageFont.truetype(os.path.join(ROOT, "tools/fonts", name + "-Regular.ttf"), max(4, int(round(size))))

def draw_screen(screen, real_w, real_h):
    s = screen["scale"]; R = screen["rects"]
    img = Image.new("RGB", (real_w, real_h), (12, 13, 14)); d = ImageDraw.Draw(img, "RGBA")
    # a soft pool of light where the flashlight would fall, so the HUD has something to sit on
    d.ellipse((real_w * 0.5 - real_h * 0.22, real_h * 0.5 - real_h * 0.22, real_w * 0.5 + real_h * 0.22, real_h * 0.5 + real_h * 0.22), fill=(70, 72, 70, 60))
    box = lambda n: (R[n]["X"] * s, R[n]["Y"] * s, (R[n]["X"] + R[n]["W"]) * s, (R[n]["Y"] + R[n]["H"]) * s)
    def panel(n): d.rectangle(box(n), fill=(6, 7, 7, 170), outline=(235, 235, 225, 50))
    def text(n, t, f, size, fill, align="l", dx=0, dy=0, h=None):
        b = box(n); fnt = font(f, size * s)
        while fnt.getlength(t) > (b[2] - b[0]) - dx * s and fnt.size > 5: fnt = font(f, fnt.size - 1)   # fitted, like the game
        x = b[0] + dx * s if align == "l" else (b[0] + b[2]) / 2 if align == "c" else b[2] - dx * s
        y = b[1] + dy * s + ((h or (b[3] - b[1]) / s - dy) * s) / 2
        d.text((x, y), t, font=fnt, fill=fill, anchor={"l": "lm", "c": "mm", "r": "rm"}[align])
    # chat column (Roblox's own window): reserved, drawn dashed
    c = box("Chat"); d.rectangle((c[0] + 6, 44 * min(1, s * 1.4), c[2], c[3] * 0.62), outline=(120, 120, 120, 90))
    d.text((c[0] + 14, 52 * min(1, s * 1.4)), "Roblox chat window (kept in this column)", font=font("SpecialElite", 11), fill=(130, 130, 130))
    # event line, sub-line, toast
    text("BannerHead", "IT HEARS YOU. BE QUIET.", "Creepster", 30, RED, "c")
    b = box("BannerHead"); d.line(((b[0] + b[2]) / 2 - 120 * s, b[3] + 4 * s, (b[0] + b[2]) / 2 + 120 * s, b[3] + 4 * s), fill=RED)
    text("BannerSub", "Stop moving. Crouch.", "SpecialElite", 13, OSD, "c", h=18)
    text("Toasts", "CASE FILE RECOVERED - BLADE", "SpecialElite", 15, GREEN, "c", h=20)
    # objectives, vitals, location
    panel("Card"); cb = box("Card")
    text("Card", "CASE OBJECTIVES", "PressStart2P", 7, AMBER, "r", dx=12, dy=8, h=12)
    for row, (label, lit, col) in enumerate((("PHOTOGRAPH THE SUBJECT", 3, GREEN), ("SEND THE EVIDENCE", 1, AMBER))):
        y = 26 + row * 26
        d.text((cb[0] + 12 * s, cb[1] + (y + 10) * s), label, font=font("SpecialElite", 15 * s), fill=OSD, anchor="lm")
        for i in range(5):
            x = cb[2] - (12 + (5 - i) * 12 - 4) * s
            d.rectangle((x, cb[1] + (y + 6) * s, x + 8 * s, cb[1] + (y + 14) * s), fill=col if i < lit else (235, 235, 225, 46))
    d.text((cb[0] + 12 * s, cb[1] + 88 * s), "Find a tube station. They are loud.", font=font("SpecialElite", 12 * s), fill=(235, 235, 225, 180), anchor="lm")
    panel("Vitals"); vb = box("Vitals")
    d.text((vb[0] + 12 * s, (vb[1] + vb[3]) / 2), "VITALS", font=font("PressStart2P", 8 * s), fill=OSD, anchor="lm")
    for i in range(5):
        x = vb[2] - (12 + (5 - i) * 18 - 4) * s
        d.ellipse((x, vb[1] + 8 * s, x + 14 * s, vb[1] + 22 * s), fill=RED if i < 3 else (235, 235, 225, 46))
    if "Location" in R: text("Location", "NURSE STATION", "SpecialElite", 13, AMBER, "r")
    # noise, stamina, fx
    panel("Noise"); nb = box("Noise")
    d.text((nb[0] + 12 * s, nb[1] + 14 * s), "NOISE METER", font=font("PressStart2P", 8 * s), fill=OSD, anchor="lm")
    for i in range(24):
        x = nb[0] + (12 + i * 7) * s
        d.rectangle((x, nb[1] + 26 * s, x + 4 * s, nb[1] + 42 * s), fill=(RED if i >= 16 else OSD) if i < 9 else (235, 235, 225, 38))
    for i, w in enumerate(("QUIET", "NORMAL", "LOUD")):
        d.text((nb[0] + (12 + i * 56) * s, nb[1] + 53 * s), w, font=font("PressStart2P", 6 * s), fill=RED if i == 2 else (235, 235, 225, 150), anchor="lm")
    sb = box("Stamina"); d.rectangle(sb, fill=(0, 0, 0, 120), outline=(235, 235, 225, 100)); d.rectangle((sb[0], sb[1], sb[0] + (sb[2] - sb[0]) * 0.7, sb[3]), fill=OSD)
    panel("Fx"); text("Fx", "FX: FULL", "SpecialElite", 12, OSD, "c")
    # hotbar, hints
    for n, name, key, on in (("Slot1", "CAMERA", "Q", True), ("Slot2", "LIGHT", "F", False), ("Slot3", "BATT", "", False)):
        b = box(n); d.rectangle(b, fill=(235, 235, 225, 110) if on else (6, 7, 7, 170), outline=(235, 235, 225, 50))
        d.text((b[0] + 6 * s, b[1] + 10 * s), key, font=font("PressStart2P", 7 * s), fill=AMBER, anchor="lm")
        d.text(((b[0] + b[2]) / 2, b[1] + 28 * s), name, font=font("PressStart2P", 8 * s), fill=OSD, anchor="mm")
    if "Hints" in R:
        hb = box("Hints")
        for i, t in enumerate(("Q / RMB   Raise camcorder", "CLICK   Photograph", "C   Crouch      SHIFT   Sprint", "F   Flashlight")):
            d.text((hb[2], hb[3] - (3 - i) * 16 * s - 8 * s), t, font=font("SpecialElite", 13 * s), fill=(235, 235, 225, 170), anchor="rm")
    # viewfinder
    v = box("Viewfinder"); L = 28 * s
    for cx, cy, sx, sy in ((v[0], v[1], 1, 1), (v[2], v[1], -1, 1), (v[0], v[3], 1, -1), (v[2], v[3], -1, -1)):
        d.line((cx, cy, cx + sx * L, cy), fill=OSD, width=max(1, int(2 * s))); d.line((cx, cy, cx, cy + sy * L), fill=OSD, width=max(1, int(2 * s)))
    d.ellipse(((v[0] + v[2]) / 2 - 2, (v[1] + v[3]) / 2 - 2, (v[0] + v[2]) / 2 + 2, (v[1] + v[3]) / 2 + 2), fill=OSD)
    d.ellipse((v[0] + 12 * s, v[1] + 12 * s, v[0] + 22 * s, v[1] + 22 * s), fill=(255, 45, 45))
    d.text((v[0] + 28 * s, v[1] + 17 * s), "REC", font=font("PressStart2P", 11 * s), fill=OSD, anchor="lm")
    d.text((v[2] - 12 * s, v[1] + 17 * s), "02:14:07", font=font("PressStart2P", 10 * s), fill=OSD, anchor="rm")
    # what it says + the trap
    text("Subtitle", "ARE YOU IN PAIN, BLADE?", "Creepster", 30, (236, 226, 226), "c")
    panel("Ask"); text("Ask", "[T]  ANSWER", "SpecialElite", 16, OSD, "c", dy=6, h=20)
    a = box("Ask"); d.rectangle((a[0] + 12 * s, a[1] + 31 * s, a[2] - 60 * s, a[1] + 34 * s), fill=OSD)
    # touch buttons (real pixels)
    if screen["touch"]:
        size = data["buttonSize"]
        for name, title in (("Run", "RUN"), ("Crouch", "DUCK"), ("Cam", "CAM"), ("Shot", "SHOT"), ("Light", "LITE"), ("Night", "NV")):
            b = data["buttons"][name]; x, y = real_w - b["OX"], real_h - b["OY"]
            d.ellipse((x, y, x + size, y + size), fill=(40, 42, 44, 200), outline=(235, 235, 225, 120))
            d.text((x + size / 2, y + size / 2), title, font=font("SpecialElite", 13), fill=OSD, anchor="mm")
    return img

laptop = next(sc for sc in data["screens"] if sc["name"] == "laptop 1366x768")
phone = next(sc for sc in data["screens"] if sc["name"] == "phone 844x390")
a, b = draw_screen(laptop, 1366, 768), draw_screen(phone, 844, 390)
PAD = 24
sheet = Image.new("RGB", (1366 + PAD * 2, 768 + 390 + PAD * 3 + 96), (4, 4, 5)); d = ImageDraw.Draw(sheet)
d.text((PAD, 14), "HOLLOW SIGNAL  -  HUD LAYOUT", font=font("Creepster", 34), fill=OSD)
d.text((PAD, 58), "Generated from src/client/UI/Layout.luau with the game's typefaces. A layout diagram, not a screenshot.  Top: laptop 1366x768.  Bottom: phone 844x390.", font=font("SpecialElite", 14), fill=(150, 150, 145))
sheet.paste(a, (PAD, 96)); sheet.paste(b, (PAD + (1366 - 844) // 2, 96 + 768 + PAD))
out = os.path.join(ROOT, "docs/hud-layout.png"); sheet.save(out, optimize=True); print(os.path.relpath(out, ROOT), sheet.size)
