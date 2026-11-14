#!/usr/bin/env python3
"""Procedurally synthesizes every sound in HOLLOW SIGNAL (numpy only) and
encodes it to assets/audio/*.ogg with ffmpeg. Re-run to regenerate:

    python3 tools/audio/synth.py

Everything here is original, generated from code — no samples."""
import os, subprocess, sys, tempfile, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio")
rng = np.random.default_rng(1989)

def t(sec): return np.arange(int(sec * SR)) / SR
def noise(sec): return rng.uniform(-1, 1, int(sec * SR))
def norm(x, peak=0.89): return x * (peak / (np.max(np.abs(x)) + 1e-9))
def env(n, a, r):
    """attack/release envelope over n samples (seconds)."""
    e = np.ones(n); ai, ri = max(1, int(a * SR)), max(1, int(r * SR))
    e[:ai] = np.linspace(0, 1, min(ai, n))[:n]; e[-ri:] *= np.linspace(1, 0, min(ri, n))[-n:] if ri <= n else 1
    return e
def decay(sec, tau): return np.exp(-t(sec) / tau)
def filt(x, lo=None, hi=None, order=6):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR) + 1e-9
    m = np.ones_like(f)
    if hi: m *= 1 / np.sqrt(1 + (f / hi) ** (2 * order))
    if lo: m *= 1 - 1 / np.sqrt(1 + (f / lo) ** (2 * order))
    return np.fft.irfft(X * m, len(x))
def formant(x, peaks, floor=0.05):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.full_like(f, floor)
    for fc, bw, g in peaks: m += g * np.exp(-0.5 * ((f - fc) / bw) ** 2)
    return np.fft.irfft(X * m, len(x))
def conv(x, ir):
    n = len(x) + len(ir) - 1; size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]
def reverb(x, secs=2.0, mix=0.35, hi=4500, tail=True):
    ir = noise(secs) * decay(secs, secs / 6.9); ir = filt(ir, lo=120, hi=hi, order=2)
    wet = conv(x, ir); wet = wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(x))
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    y = dry * (1 - mix) + wet * mix
    return y if tail else y[:len(x)]
def phase(freq): return 2 * np.pi * np.cumsum(freq) / SR
def saw(freq, harm=24):
    p = phase(freq); y = np.zeros_like(p)
    for k in range(1, harm + 1): y += np.sin(k * p) / k * (np.asarray(freq) * k < SR / 2.2)
    return y * 0.6
def sine(freq): return np.sin(phase(freq)) if np.ndim(freq) else None
def tone(f, sec): return np.sin(2 * np.pi * f * t(sec))
def glide(points, sec):
    """piecewise-linear curve through (time_fraction, value) points."""
    xs = [p[0] * sec for p in points]; ys = [p[1] for p in points]
    return np.interp(t(sec), xs, ys)
def drive(x, g): return np.tanh(x * g) / np.tanh(g)
def loopable(x, fade=0.5):
    n = int(fade * SR); body = x[:-n].copy(); tailpart = x[-n:]
    ramp = np.linspace(0, 1, n); body[:n] = body[:n] * ramp + tailpart * (1 - ramp)
    return body
def mixin(dst, src, at, gain=1.0):
    i = int(at * SR); j = min(len(dst), i + len(src))
    if i < len(dst): dst[i:j] += src[:j - i] * gain
    return dst
def clank(sec, partials, tau=0.25):
    y = np.zeros(int(sec * SR))
    for i, f in enumerate(partials): y += tone(f, sec) * decay(sec, tau / (1 + i * 0.35)) / (1 + i * 0.5)
    return y
def thump(f0, sec, tau=0.09, drop=0.5):
    fr = f0 * (drop + (1 - drop) * np.exp(-t(sec) / 0.03)); return np.sin(phase(fr)) * decay(sec, tau)

# --------------------------------------------------------------------------- monster
def howl(seed, dur=6.5, base=170, peak=470, shriek=1500):
    r = np.random.default_rng(seed); n = int(dur * SR); tt = t(dur)
    f = glide([(0, base), (0.16, peak * 0.86), (0.3, peak), (0.52, peak * r.uniform(0.94, 1.03)), (0.6, peak * 1.35), (0.68, shriek), (0.8, shriek * r.uniform(0.7, 0.9)), (0.9, peak * 0.8), (1, base * 0.7)], dur)
    vib = 1 + glide([(0, 0), (0.3, 0.012), (0.6, 0.035), (1, 0.06)], dur) * np.sin(2 * np.pi * r.uniform(5.2, 6.4) * tt)
    jitter = 1 + filt(r.uniform(-1, 1, n), hi=35, order=2) * glide([(0, 0.01), (0.55, 0.03), (0.7, 0.16), (1, 0.08)], dur) * 6
    f = f * vib * jitter
    voice = saw(f, 30) + 0.45 * saw(f * 0.5, 16) + 0.3 * saw(f * 1.498, 12)  # sub + a sour fifth
    voice = formant(voice, [(620, 160, 1.0), (1150, 220, 0.8), (2550, 380, 0.55), (3600, 500, 0.3)], 0.04)
    ring = voice * (1 + 0.6 * np.sin(2 * np.pi * 73 * tt) * glide([(0, 0), (0.5, 0.2), (0.7, 1), (1, 0.6)], dur))  # the machine in it
    breath = filt(r.uniform(-1, 1, n), lo=900, hi=5200, order=2) * glide([(0, 0.02), (0.55, 0.05), (0.68, 0.5), (0.85, 0.3), (1, 0.05)], dur)
    squeal = np.sin(phase(glide([(0, 2600), (0.6, 2900), (0.72, 4100), (1, 3300)], dur) * (1 + 0.02 * np.sin(2 * np.pi * 31 * tt)))) * glide([(0, 0), (0.6, 0), (0.7, 0.22), (0.9, 0.1), (1, 0)], dur)
    servo = saw(glide([(0, 38), (0.7, 52), (1, 30)], dur), 40) * glide([(0, 0.05), (0.8, 0.12), (1, 0.25)], dur)
    amp = glide([(0, 0), (0.05, 0.5), (0.3, 0.85), (0.62, 0.9), (0.7, 1), (0.88, 0.7), (1, 0)], dur)
    y = (norm(ring) * 0.9 + breath + squeal + servo) * amp
    y = drive(norm(y), 3.2)
    return norm(reverb(y, 3.2, 0.42))
def shriek():
    dur = 2.0; tt = t(dur)
    f = glide([(0, 520), (0.12, 1500), (0.3, 2100), (0.6, 1700), (1, 600)], dur) * (1 + 0.09 * np.sin(2 * np.pi * 41 * tt) + 0.05 * np.sin(2 * np.pi * 7.3 * tt))
    y = saw(f, 14) + 0.5 * saw(f * 0.51, 14) + filt(noise(dur), lo=1800, hi=7000, order=2) * 0.6
    y = formant(y, [(900, 250, 0.8), (1900, 400, 1), (3300, 600, 0.7)], 0.08) * glide([(0, 0), (0.02, 1), (0.6, 0.9), (1, 0)], dur)
    return norm(reverb(drive(norm(y), 5), 2.2, 0.35))
def step():
    sec = 0.7; y = thump(70, sec, 0.11) * 1.2 + clank(sec, [311, 517, 823, 1291, 2103], 0.12) * 0.35
    y += filt(noise(sec), lo=1500, hi=5000, order=2) * decay(sec, 0.02) * 0.5
    y = mixin(y, saw(glide([(0, 220), (1, 90)], 0.25), 10) * env(int(0.25 * SR), 0.02, 0.15) * 0.12, 0.12)
    return norm(reverb(y, 0.9, 0.25))
def idle_loop():
    dur = 9.0; tt = t(dur); n = len(tt)
    y = saw(47 * (1 + 0.01 * np.sin(2 * np.pi * 0.3 * tt)), 30) * 0.25
    y += filt(noise(dur), lo=500, hi=2400, order=2) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.33 * tt)) ** 3 * 0.35  # wheeze
    for _ in range(46):
        at = rng.uniform(0, dur - 0.1); mixin(y, filt(noise(0.012), lo=2500) * decay(0.012, 0.003), at, rng.uniform(0.3, 0.9))
    for at in rng.uniform(0, dur - 0.5, 5):
        mixin(y, saw(glide([(0, rng.uniform(300, 700)), (1, rng.uniform(150, 500))], 0.3), 12) * env(int(0.3 * SR), 0.03, 0.2), at, 0.12)
    return norm(loopable(reverb(y, 1.2, 0.25, tail=False), 0.8), 0.7)
def mimic(seed):
    r = np.random.default_rng(seed); dur = 3.2; n = int(dur * SR); tt = t(dur)
    vowels = {"a": [(730, 90, 1), (1090, 110, .7), (2440, 160, .4)], "e": [(530, 80, 1), (1840, 130, .7), (2480, 160, .4)], "o": [(570, 80, 1), (840, 100, .8), (2410, 160, .3)], "i": [(270, 60, 1), (2290, 150, .7), (3010, 200, .4)], "u": [(300, 60, 1), (870, 100, .7), (2240, 160, .3)]}
    y = np.zeros(n); pos = 0.15
    while pos < dur - 0.5:
        syl = r.uniform(0.14, 0.34); m = int(syl * SR)
        f0 = r.uniform(105, 190) * glide([(0, 1), (0.5, r.uniform(0.95, 1.15)), (1, r.uniform(0.8, 1.05))], syl)
        v = formant(saw(f0, 40), vowels[r.choice(list(vowels))], 0.02) * env(m, 0.03, 0.08)
        if r.random() < 0.5: v[: int(0.03 * SR)] += filt(r.uniform(-1, 1, int(0.03 * SR)), lo=2500) * 0.6  # consonant
        mixin(y, norm(v), pos, r.uniform(0.6, 1)); pos += syl + r.uniform(0.02, 0.22)
    warp = np.clip(np.arange(n) + 180 * np.sin(2 * np.pi * 0.7 * tt) + 40 * np.sin(2 * np.pi * 6.1 * tt), 0, n - 1)  # tape wow + flutter
    y = np.interp(warp, np.arange(n), y)
    y = filt(y, lo=320, hi=2900, order=3) + filt(noise(dur), lo=1000, hi=6000, order=2) * 0.05
    y = drive(norm(y), 2.5) * glide([(0, 0), (0.05, 1), (0.9, 1), (1, 0)], dur)
    return norm(reverb(y, 1.8, 0.3), 0.8)
def jumpscare():
    dur = 2.6; tt = t(dur); y = np.zeros(len(tt))
    for f in [98, 104, 147, 156, 233, 247, 415, 440]: y += saw(f * (1 + 0.004 * np.sin(2 * np.pi * rng.uniform(3, 9) * tt)), 30) * 0.3
    y += filt(noise(dur), lo=200, hi=9000, order=2) * decay(dur, 0.35) * 1.5 + thump(55, dur, 0.4) * 2
    y += shriek_cache[: len(tt)] * 1.4 if len(shriek_cache) >= len(tt) else np.pad(shriek_cache, (0, len(tt) - len(shriek_cache))) * 1.4
    y *= glide([(0, 1), (0.5, 0.8), (1, 0)], dur)
    return norm(reverb(drive(norm(y), 6), 1.8, 0.25), 0.95)
def sting():
    dur = 2.4; tt = t(dur); y = sum(saw(f, 20) for f in [55, 58.3, 82.4, 116.5]) * glide([(0, 0), (0.04, 1), (0.3, 0.6), (1, 0)], dur)
    return norm(reverb(filt(y, hi=1800, order=2) + thump(48, dur, 0.3), 2.4, 0.4))

# --------------------------------------------------------------------------- loops
def static_loop():
    dur = 5.0; y = filt(noise(dur), lo=400, hi=8000, order=2) * 0.5
    crackle = (rng.random(len(y)) > 0.9993) * rng.uniform(-1, 1, len(y)); y += conv(crackle, decay(0.01, 0.002))[: len(y)] * 2
    y *= 0.8 + 0.2 * filt(noise(dur), hi=6, order=2) * 8
    return norm(loopable(y, 0.5), 0.6)
def heartbeat_loop():
    dur = 2.0; y = np.zeros(int(dur * SR))
    for b in (0.0, 1.0):
        mixin(y, thump(62, 0.3, 0.07), b, 1.0); mixin(y, thump(52, 0.3, 0.06), b + 0.28, 0.75)
    return norm(filt(y, hi=180, order=3), 0.9)
def bunker_drone():
    dur = 26.0; tt = t(dur)
    y = sum(saw(f * (1 + 0.003 * np.sin(2 * np.pi * r * tt)), 16) for f, r in [(41.2, 0.07), (41.6, 0.11), (61.7, 0.05), (82.9, 0.09)])
    y = filt(y, hi=260, order=2) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.045 * tt))
    for at in rng.uniform(1, dur - 6, 5):  # distant metal groans
        g = 4.0; fr = rng.uniform(90, 240)
        mixin(y, formant(noise(g), [(fr, 12, 1), (fr * 2.31, 25, 0.5)], 0) * env(int(g * SR), 1.5, 2) * 14, at)
    for at in rng.uniform(0, dur - 1, 9): mixin(y, tone(rng.uniform(1400, 2600), 0.05) * decay(0.05, 0.008), at, 0.25)  # drips
    y = reverb(y, 3.5, 0.45, tail=False) + filt(noise(dur), hi=500, order=2) * 0.05
    return norm(loopable(y, 3.0), 0.75)
def forest_night():
    dur = 22.0; tt = t(dur)
    wind = filt(noise(dur), lo=80, hi=700, order=2) * (0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.06 * tt + 1)) ** 2)
    wind += filt(noise(dur), lo=1500, hi=5000, order=2) * 0.06 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.09 * tt))
    chirp = np.sin(2 * np.pi * 4300 * tt) * (np.sin(2 * np.pi * 34 * tt) > 0.2) * ((tt * 1.9) % 1 < 0.42) * 0.05
    chirp2 = np.sin(2 * np.pi * 3650 * tt) * (np.sin(2 * np.pi * 27 * tt) > 0.3) * (((tt + 0.3) * 1.3) % 1 < 0.3) * 0.03
    y = wind + chirp + chirp2
    for at in (5.5, 15.2):
        for k, d in enumerate((0, 0.55, 0.95)):
            hoot = np.sin(phase(glide([(0, 410), (1, 360)], 0.34))) * env(int(0.34 * SR), 0.05, 0.15)
            mixin(y, hoot, at + d, 0.1 if k else 0.14)
    return norm(loopable(reverb(y, 2.5, 0.3, tail=False), 2.5), 0.6)
NOTE = lambda n: 440 * 2 ** ((n - 69) / 12)
def pad(notes, sec):
    tt = t(sec); y = np.zeros(len(tt))
    for n in notes:
        for det in (-0.07, 0.06, 0.0):
            y += saw(NOTE(n + det) * (1 + 0.004 * np.sin(2 * np.pi * 0.5 * tt + n)), 14)
    return filt(y, hi=900, order=2) * env(len(tt), sec * 0.3, sec * 0.35)
def piano(n, sec=4.0):
    f = NOTE(n); tt = t(sec)
    return sum(np.sin(2 * np.pi * f * k * tt * (1 + 0.0004 * k * k)) * np.exp(-tt * (0.9 + k * 0.7)) / k ** 1.3 for k in range(1, 7)) * env(len(tt), 0.004, 0.3)
def lobby_theme():
    bar = 8.0; chords = [[45, 52, 57, 60], [41, 48, 53, 57], [38, 50, 53, 57], [40, 47, 52, 56], [45, 52, 57, 64], [41, 48, 53, 60], [43, 50, 55, 58], [40, 47, 52, 56]]
    dur = bar * len(chords) + 4; y = np.zeros(int(dur * SR))
    for i, ch in enumerate(chords): mixin(y, pad(ch, bar + 3.5), i * bar, 0.16)
    melody = [(1.0, 76), (3.0, 72), (5.5, 69), (9.0, 77), (11.5, 72), (14.0, 69), (17.5, 74), (20.0, 69), (22.5, 65), (25.0, 68), (28.5, 64), (33.0, 76), (35.0, 79), (37.5, 72), (41.5, 77), (44.0, 72), (49.0, 70), (51.5, 67), (54.0, 62), (57.0, 68), (60.0, 64)]
    for at, n in melody: mixin(y, piano(n), at + rng.uniform(-0.04, 0.04), 0.5); mixin(y, piano(n - 12, 5), at + 0.02, 0.18)
    n = len(y); tt = np.arange(n) / SR
    warp = np.clip(np.arange(n) + 60 * np.sin(2 * np.pi * 0.31 * tt) + 9 * np.sin(2 * np.pi * 5.3 * tt), 0, n - 1)  # worn tape
    y = np.interp(warp, np.arange(n), y)
    y = reverb(y, 3.0, 0.4, tail=False) + filt(rng.uniform(-1, 1, n), lo=2000, hi=7000, order=2) * 0.012
    tones = (np.sin(2 * np.pi * 853 * tt) + np.sin(2 * np.pi * 960 * tt)) * ((tt % 32) > 30.5) * ((tt % 32) < 31.3) * 0.02  # a far-off emergency tone
    return norm(loopable(filt(y + tones, lo=45, hi=7500, order=2), 4.0), 0.8)
def chase_theme():
    bpm = 148; beat = 60 / bpm; bars = 16; dur = bars * 4 * beat + 1; y = np.zeros(int(dur * SR)); tt = t(dur)
    for b in range(bars * 4):
        at = b * beat
        mixin(y, thump(95, 0.3, 0.1, 0.35), at, 1.1)
        if b % 2 == 1: mixin(y, filt(noise(0.14), lo=1500, hi=8000, order=2) * decay(0.14, 0.035), at, 0.5)
        for s in range(4):  # sixteenth-note bass ostinato with a sour note every other bar
            n = 28 if (b // 8) % 2 == 0 or s != 3 else 29
            if b % 16 >= 12: n += 6 if s % 2 else 0
            mixin(y, drive(saw(np.full(int(beat / 4 * SR), NOTE(n)), 30) * decay(beat / 4, 0.06), 4), at + s * beat / 4, 0.42 if s else 0.6)
    for bar in range(0, bars, 2):
        st = sum(saw(np.full(int(1.2 * SR), NOTE(n)), 16) for n in (64, 65, 70, 71)) * decay(1.2, 0.35)
        mixin(y, filt(st, lo=300, hi=4000, order=2), bar * 4 * beat, 0.16)
    riser = filt(noise(dur), lo=800, hi=6000, order=2) * ((tt % (16 * beat)) / (16 * beat)) ** 3 * 0.25
    y = drive(norm(y + riser), 1.8)
    return norm(loopable(reverb(y, 0.9, 0.15, tail=False), 1.0), 0.85)
def broadcast_tone():
    dur = 6.0; tt = t(dur)
    y = (np.sin(2 * np.pi * 853 * tt) + np.sin(2 * np.pi * 960 * tt)) * ((tt % 2) < 1.1) * 0.4
    y += np.sin(phase(1200 + 600 * np.sign(np.sin(2 * np.pi * 37 * tt)))) * ((tt % 2) >= 1.2) * ((tt % 2) < 1.8) * 0.25  # data burst
    return norm(loopable(filt(y, lo=300, hi=3400, order=3) + filt(noise(dur), lo=500, hi=4000, order=2) * 0.04, 0.3), 0.6)
def alarm_loop():
    dur = 2.4; tt = t(dur); f = 430 + 190 * ((tt % 1.2) / 1.2)
    return norm(loopable(reverb(drive(saw(f, 20) * ((tt % 1.2) < 0.95), 2), 1.5, 0.3, tail=False), 0.2), 0.7)
def effigy_whisper():
    dur = 7.0; y = np.zeros(int(dur * SR))
    for k in range(4):
        w = formant(noise(dur), [(rng.uniform(1500, 2500), 300, 1), (rng.uniform(3500, 5000), 500, 0.6)], 0)
        gate = np.clip(filt(rng.uniform(-1, 1, len(w)), hi=rng.uniform(4, 7), order=2) * 14, 0, 1)
        y += w * gate
    for at in rng.uniform(0, dur - 0.3, 7): mixin(y, clank(0.2, [1900, 2740, 3310], 0.03), at, 0.5)
    return norm(loopable(reverb(y, 2.2, 0.4, tail=False), 1.0), 0.55)

# --------------------------------------------------------------------------- world one-shots
def scrape(sec, f1, f2, g=1.0):
    y = formant(noise(sec), [(f1, 60, 1), (f1 * 2.7, 120, 0.6), (f2, 200, 0.4)], 0.01) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t(sec)))
    return norm(y) * env(int(sec * SR), 0.04, sec * 0.3) * g
def door_open(): return norm(reverb(scrape(1.1, 310, 1900) + saw(glide([(0, 70), (1, 110)], 1.1), 20) * 0.15 * env(int(1.1 * SR), 0.1, 0.3), 1.2, 0.3))
def door_close():
    y = np.zeros(int(1.0 * SR)); mixin(y, scrape(0.6, 260, 1500), 0); mixin(y, thump(80, 0.4, 0.07) + clank(0.4, [240, 410, 660], 0.08) * 0.4, 0.55)
    return norm(reverb(y, 1.2, 0.3))
def door_slam(): return norm(reverb(thump(65, 0.8, 0.14) * 1.4 + clank(0.8, [190, 337, 548, 910, 1470], 0.22) * 0.6 + filt(noise(0.8), lo=300, hi=6000, order=2) * decay(0.8, 0.03), 2.0, 0.35), 0.95)
def blast_door():
    dur = 5.2; tt = t(dur); y = saw(glide([(0, 28), (0.2, 44), (0.9, 40), (1, 24)], dur), 40) * 0.5 + scrape(dur, 140, 900, 0.8) + filt(noise(dur), hi=160, order=2) * 1.2
    y *= env(len(tt), 0.3, 0.2); mixin(y, thump(50, 0.7, 0.2) * 2 + clank(0.7, [120, 207, 331, 590], 0.3), dur - 0.75)
    return norm(reverb(y, 3.0, 0.4), 0.95)
def locker(): return norm(reverb(thump(110, 0.5, 0.05) + clank(0.5, [420, 713, 1130, 1840, 2600], 0.09) * 0.7 + filt(noise(0.5), lo=2000, order=2) * decay(0.5, 0.015) * 0.5, 0.7, 0.25))
def pickup():
    y = np.zeros(int(0.35 * SR)); mixin(y, filt(noise(0.02), lo=2000) * decay(0.02, 0.004), 0); mixin(y, clank(0.3, [1250, 1880, 2700], 0.05), 0.02, 0.6)
    return norm(y, 0.7)
def fuse_insert():
    y = np.zeros(int(0.9 * SR)); mixin(y, clank(0.25, [900, 1410, 2230], 0.03) + thump(140, 0.25, 0.03), 0)
    zap = filt(noise(0.5), lo=1500, hi=9000, order=2) * (np.sin(2 * np.pi * 100 * t(0.5)) > 0.6) * decay(0.5, 0.15); mixin(y, zap, 0.15, 0.9)
    return norm(y)
def power_up():
    dur = 4.5; tt = t(dur); f = glide([(0, 22), (0.55, 98), (1, 120)], dur)
    y = saw(f, 30) * glide([(0, 0), (0.1, 0.5), (0.6, 1), (1, 0.5)], dur) + saw(f * 2.01, 10) * 0.3
    for at in (0.05, 1.3, 2.1, 2.6, 2.9): mixin(y, thump(120, 0.2, 0.03) * 2 + clank(0.2, [800, 1300], 0.03), at)
    buzz = saw(np.full(len(tt), 120.0), 40) * (rng.random(len(tt)) > 0.2) * glide([(0, 0), (0.6, 0), (0.7, 0.25), (1, 0.12)], dur)
    return norm(reverb(filt(y, hi=3000, order=2) + filt(buzz, lo=800, order=2), 2.5, 0.35), 0.95)
def elevator():
    dur = 8.0; tt = t(dur); y = filt(noise(dur), hi=120, order=2) * 2.5 + saw(glide([(0, 30), (0.1, 46), (0.85, 44), (1, 20)], dur), 30) * 0.5
    for at in np.arange(0.4, 6.8, 0.62): mixin(y, clank(0.3, [330, 560, 910, 1500], 0.06) * 0.5 + thump(90, 0.3, 0.04), at + rng.uniform(-0.05, 0.05), rng.uniform(0.3, 0.6))
    y *= env(len(tt), 0.6, 0.4); mixin(y, thump(55, 0.9, 0.2) * 3 + clank(0.9, [150, 262, 431, 700], 0.3), 7.0)
    return norm(reverb(y, 2.2, 0.35), 0.95)
def cage_rattle():
    y = np.zeros(int(1.1 * SR))
    for at in (0, 0.13, 0.31, 0.42, 0.66, 0.8): mixin(y, clank(0.3, [520, 877, 1390, 2250, 3100], 0.07), at, rng.uniform(0.5, 1))
    return norm(reverb(y, 1.0, 0.3))
def cage_open(): return norm(reverb(np.concatenate([scrape(0.9, 700, 2600), clank(0.5, [300, 520, 870, 1400], 0.12)]), 1.3, 0.3))
def light_flicker():
    dur = 1.4; tt = t(dur); gate = (filt(noise(dur), hi=18, order=2) > 0.03)
    return norm(filt(saw(np.full(len(tt), 100.0), 60), lo=600, order=2) * gate + filt(noise(dur), lo=3000, order=2) * gate * 0.3, 0.6)
def flashlight_click(): return norm(np.concatenate([filt(noise(0.012), lo=1800) * decay(0.012, 0.003), np.zeros(int(0.04 * SR)), clank(0.08, [2100, 3300], 0.012) * 0.7]), 0.7)
def ui_blip(): return norm(np.sign(tone(1320, 0.09)) * decay(0.09, 0.03) * 0.5 + tone(660, 0.09) * decay(0.09, 0.03), 0.5)
def ui_type(): return norm(filt(noise(0.03), lo=1200, hi=5000, order=2) * decay(0.03, 0.006) + thump(300, 0.03, 0.006) * 0.5, 0.5)
def tape_start():
    dur = 1.8; y = np.zeros(int(dur * SR)); mixin(y, thump(130, 0.2, 0.03) * 1.5 + clank(0.2, [700, 1150], 0.03), 0)
    mixin(y, saw(glide([(0, 20), (0.4, 180), (1, 190)], 1.5), 20) * 0.2 * env(int(1.5 * SR), 0.1, 0.4) + filt(noise(1.5), lo=3000, hi=9000, order=2) * 0.12 * env(int(1.5 * SR), 0.3, 0.4), 0.2)
    return norm(y, 0.8)
def breath_gasp():
    dur = 1.3; y = formant(noise(dur), [(900, 300, 1), (2400, 600, 0.7)], 0.02) * glide([(0, 0), (0.25, 1), (0.45, 0.2), (0.6, 0.7), (1, 0)], dur)
    return norm(y, 0.7)

def camera_shutter():
    y = np.zeros(int(1.6 * SR)); mixin(y, filt(noise(0.02), lo=2500) * decay(0.02, 0.004), 0); mixin(y, clank(0.12, [1700, 2900, 4100], 0.02) * 0.8, 0.03)
    whine = np.sin(phase(glide([(0, 2200), (1, 9000)], 1.3))) * glide([(0, 0), (0.1, 0.12), (0.9, 0.04), (1, 0)], 1.3)  # the flash recharging
    mixin(y, whine, 0.2); mixin(y, filt(noise(0.08), lo=800, hi=6000, order=2) * decay(0.08, 0.02) * 1.2, 0.01)
    return norm(y, 0.8)
def tube_send():
    dur = 3.0; y = np.zeros(int(dur * SR))
    mixin(y, thump(120, 0.3, 0.05) * 1.5 + clank(0.3, [600, 990, 1640], 0.05), 0)  # hatch
    whoosh = filt(noise(1.6), lo=300, hi=3500, order=2) * glide([(0, 0), (0.15, 1), (1, 0)], 1.6) * (1 + 0.5 * np.sin(phase(glide([(0, 30), (1, 90)], 1.6))))
    mixin(y, whoosh, 0.25, 0.9); mixin(y, thump(70, 0.6, 0.12) * 2 + clank(0.6, [210, 350, 580, 940], 0.2), 1.5)  # the canister hits a bend
    for at in (1.9, 2.15, 2.35): mixin(y, clank(0.25, [260, 440, 720], 0.08), at, 0.35)
    return norm(reverb(y, 2.6, 0.4), 0.95)
def power_down():
    dur = 3.6; tt = t(dur); f = glide([(0, 120), (0.7, 34), (1, 18)], dur)
    y = saw(f, 30) * glide([(0, 0.9), (0.6, 0.6), (1, 0)], dur) + filt(saw(np.full(len(tt), 120.0), 40), lo=800, order=2) * (tt < 0.5) * 0.3
    mixin(y, thump(90, 0.4, 0.08) * 2.5 + clank(0.4, [300, 520, 880], 0.1), 0.02)
    return norm(reverb(filt(y, hi=2600, order=2), 3.0, 0.4), 0.95)
def grab_sting():
    dur = 3.2; tt = t(dur); y = sum(saw(f * (1 + 0.006 * np.sin(2 * np.pi * 5 * tt)), 20) for f in [73.4, 77.8, 110, 116.5, 220, 233]) * glide([(0, 0), (0.03, 1), (0.5, 0.7), (1, 0)], dur)
    y = filt(y, hi=2400, order=2) + filt(noise(dur), lo=2000, hi=7000, order=2) * decay(dur, 0.2) + thump(46, dur, 0.5) * 1.5
    return norm(reverb(drive(norm(y), 3), 2.5, 0.35), 0.95)

shriek_cache = shriek()
SOUNDS = {
    "fawn_howl_1": lambda: howl(11), "fawn_howl_2": lambda: howl(23, 5.6, 150, 420, 1320), "fawn_howl_3": lambda: howl(37, 7.4, 190, 520, 1750),
    "fawn_shriek": lambda: shriek_cache, "fawn_step": step, "fawn_idle_loop": idle_loop, "fawn_mimic_1": lambda: mimic(5), "fawn_mimic_2": lambda: mimic(9),
    "jumpscare": jumpscare, "sting_low": sting, "static_loop": static_loop, "heartbeat_loop": heartbeat_loop, "bunker_drone": bunker_drone,
    "forest_night": forest_night, "lobby_theme": lobby_theme, "chase_theme": chase_theme, "broadcast_tone": broadcast_tone, "alarm_loop": alarm_loop,
    "effigy_whisper": effigy_whisper, "door_open": door_open, "door_close": door_close, "door_slam": door_slam, "blast_door": blast_door, "locker": locker,
    "pickup": pickup, "fuse_insert": fuse_insert, "power_up": power_up, "elevator": elevator, "cage_rattle": cage_rattle, "cage_open": cage_open,
    "camera_shutter": camera_shutter, "tube_send": tube_send, "power_down": power_down, "grab": grab_sting,
    "light_flicker": light_flicker, "flashlight_click": flashlight_click, "ui_blip": ui_blip, "ui_type": ui_type, "tape_start": tape_start, "breath_gasp": breath_gasp,
}

def write(name, x):
    x = np.clip(np.nan_to_num(x), -1, 1); pcm = (x * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp: path = tmp.name
    with wave.open(path, "wb") as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.unlink(path)
    rms = float(np.sqrt(np.mean(x ** 2)))
    print(f"{name:18s} {len(x) / SR:6.2f}s  peak {np.max(np.abs(x)):.2f}  rms {rms:.3f}  {os.path.getsize(out) // 1024:5d} KB")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    for name, make in SOUNDS.items():
        if not only or name in only: write(name, make())
