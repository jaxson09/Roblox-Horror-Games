#!/usr/bin/env python3
"""Measures every fixed line of HUD text with the real fonts (Creepster,
Special Elite) and checks it fits its box at the narrowest supported screen.
In the game these lines shrink to fit rather than spill, so this is a check
that they do not have to shrink much. Needs Pillow."""
import json, os, re, subprocess, sys
from PIL import ImageFont
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
font = lambda name, size: ImageFont.truetype(os.path.join(ROOT, "tools/fonts", name + "-Regular.ttf"), size)
data = json.loads(subprocess.run(["node", os.path.join(ROOT, "tools/typecheck/test-layout.mjs"), "--json"], capture_output=True, text=True, check=True).stdout)
lore = open(os.path.join(ROOT, "src/shared/Lore.luau"), encoding="utf-8").read()
section = lambda name: lore[lore.index(name):lore.index("\n}", lore.index(name))]
strings = lambda text: re.findall(r'"([^"\n]+)"', text)
NAME = "WWWWWWWWWWWWWWWWWWWW"  # the widest a 20-character display name can be
banners = section("Lore.Banners = {")
heads = [re.sub(r"%d", "5", h) for h in re.findall(r'=\s*\{\s*"([^"]+)"', banners)]
subs = [re.sub(r"%d", "5", s) for s in re.findall(r'=\s*\{\s*"[^"]+",\s*"([^"]*)"', banners) if s]
spoken = [s.replace("%s", NAME) for s in strings(section("Lore.Questions = {")) + strings(section("Lore.GrabLines = {"))] + [s.replace("%s", NAME.lower()) for s in strings(section("Lore.MimicLines = {"))]
objectives = [s for s in strings(section("Lore.Objectives = {")) if s.isupper() and "LOBBY" not in s and "CIRCLE" not in s] + ["LOCKDOWN IN 2:30"]
T = data["text"]
worst, failures = 1.0, []
def check(kind, texts, fontname, size, width, lines=1):
    global worst
    f = font(fontname, size)
    for text in texts:
        need = f.getlength(text) / lines
        ratio = min(1.0, width / need) if need else 1.0
        worst = min(worst, ratio)
        if ratio < 0.7: failures.append(f"{kind}: '{text}' needs {need:.0f}px, has {width:.0f}px (would shrink to {ratio:.0%})")
for screen in data["screens"]:
    r = screen["rects"]
    check(f"event line @ {screen['name']}", heads, "Creepster", T["BannerHead"], r["BannerHead"]["W"])
    check(f"event sub-line @ {screen['name']}", subs, "SpecialElite", T["BannerSub"], r["BannerSub"]["W"], lines=2)
    check(f"spoken line @ {screen['name']}", spoken, "Creepster", T["Subtitle"], r["Subtitle"]["W"])
    check(f"objective @ {screen['name']}", objectives, "SpecialElite", T["Objective"], r["Card"]["W"] - 24 - 72)
print(f"{len(data['screens'])} screen sizes; tightest line keeps {worst:.0%} of its design size; {len(failures)} line(s) below 70%")
for f in failures[:20]: print("  " + f)
sys.exit(1 if failures else 0)
