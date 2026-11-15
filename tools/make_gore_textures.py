#!/usr/bin/env python3
"""Blood and scratch marks for the night office (scripts/hd.gd HD.blood), all drawn here: no
downloaded images. Writes assets/textures/gore/*.png (RGBA, straight alpha).

    python3 tools/make_gore_textures.py        (needs numpy, scipy, Pillow)
"""
import os
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "gore")
rng = np.random.default_rng(214)


def noise(h, w, scale, octaves=4):
    """Smooth value noise in 0..1."""
    n = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n += amp * gaussian_filter(rng.standard_normal((h, w)), scale / (2 ** o), mode="wrap")  * (2 ** o)
        total += amp
        amp *= 0.5
    n -= n.min()
    return n / n.max()


def soft(x, lo, hi):
    return np.clip((x - lo) / (hi - lo), 0.0, 1.0)


def capsule(h, w, x0, y0, x1, y1, r):
    """Distance field of a line segment, 1 inside radius r, falling off over 2 px."""
    yy, xx = np.mgrid[0:h, 0:w]
    dx, dy = x1 - x0, y1 - y0
    t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
    d = np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy))
    return soft(r + 1.0 - d, 0.0, 2.0)


def save(name, alpha, dark=None):
    """alpha 0..1 -> blood-coloured RGBA: wetter and redder where thick, brown where thin."""
    h, w = alpha.shape
    thick = gaussian_filter(alpha, 3.0)
    grain = noise(h, w, 6.0)
    r = 0.11 + 0.21 * thick * (0.6 + 0.4 * grain)   # dark: a torch held close blows anything brighter out to pink
    g = 0.008 + 0.012 * thick
    b = 0.008 + 0.014 * thick
    if dark is not None:   # scratches: nearly black
        r, g, b = r * dark, g * dark, b * dark
    img = np.dstack([r, g, b, np.clip(alpha, 0, 1)])
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def hand(name, flip=False):
    h, w = 512, 256
    m = np.zeros((h, w))
    cx, cy = 128, 150
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.maximum(m, soft(1.0 - (((xx - cx) / 52.0) ** 2 + ((yy - cy) / 48.0) ** 2), 0.0, 0.15))   # palm
    for i, (ang, length, rad) in enumerate([(-0.42, 86, 11), (-0.14, 100, 12), (0.1, 96, 12), (0.36, 78, 10)]):
        bx, by = cx + (i - 1.5) * 26, cy - 34
        m = np.maximum(m, capsule(h, w, bx, by, bx + np.sin(ang) * length, by - np.cos(ang) * length, rad))
    m = np.maximum(m, capsule(h, w, cx - 50, cy + 6, cx - 92, cy - 38, 13))   # thumb
    # a hand never prints whole: gaps where the skin didn't touch, heavier at the heel and tips
    m *= soft(noise(h, w, 9.0), 0.28, 0.55)
    m *= 0.55 + 0.45 * soft(noise(h, w, 30.0), 0.3, 0.7)
    # dragged down the wall: the print smeared below itself, thinning out
    smear = np.zeros_like(m)
    for k in range(1, 300, 3):
        smear = np.maximum(smear, np.roll(m, k, axis=0) * (1.0 - k / 300.0) ** 1.6 * 0.75)
    smear[: cy - 40] = 0
    streaks = soft(gaussian_filter(rng.random((1, w)), (0, 2.5)).repeat(h, axis=0), 0.42, 0.6)
    m = np.maximum(m, smear * streaks)
    if flip:
        m = m[:, ::-1]
    save(name, np.clip(m * 1.6, 0, 1))


def smear(name):
    h, w = 256, 768
    yy, xx = np.mgrid[0:h, 0:w]
    path = 128 + 26 * np.sin(xx / 110.0) + 40 * (noise(1, w, 40.0)[0] - 0.5)
    band = soft(1.0 - np.abs(yy - path) / (46.0 * (1.0 - xx / w * 0.7)), 0.0, 0.5)
    streaks = soft(gaussian_filter(rng.random((h, 1)), (2.0, 0)).repeat(w, axis=1), 0.35, 0.6)
    m = band * (0.35 + 0.65 * streaks) * soft(noise(h, w, 12.0), 0.2, 0.6)
    m *= soft(xx, 0, 40) * soft(w - xx, 0, 200)
    save(name, m)


def drip(name):
    h, w = 768, 512
    blob = soft(noise(h, w, 34.0) * np.exp(-(((np.mgrid[0:h, 0:w][1] - 256) / 150.0) ** 2 + ((np.mgrid[0:h, 0:w][0] - 170) / 110.0) ** 2)), 0.33, 0.42)
    m = blob.copy()
    for _ in range(14):   # runs down from the splat, each ending in a bead
        x = int(rng.uniform(120, 392))
        col = np.nonzero(blob[:, x] > 0.5)[0]
        if len(col) == 0:
            continue
        y0, length, rad = col.max() - 4, rng.uniform(60, 440), rng.uniform(2.0, 5.5)
        m = np.maximum(m, capsule(h, w, x, y0, x + rng.uniform(-4, 4), min(y0 + length, h - 12), rad))
        m = np.maximum(m, capsule(h, w, x, min(y0 + length, h - 12), x, min(y0 + length, h - 12) + 1, rad * 1.7))
    for _ in range(60):   # spatter round it
        x, y, rad = rng.uniform(40, 472), rng.uniform(30, 330), rng.uniform(1.0, 5.0)
        m = np.maximum(m, capsule(h, w, x, y, x + 1, y + 1, rad))
    save(name, m)


def pool(name):
    h = w = 512
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot(xx - 256, yy - 256) / 256.0
    m = soft(noise(h, w, 40.0) * 0.6 + (1.0 - d) * 0.75, 0.52, 0.6)
    m = np.maximum(m, soft(noise(h, w, 10.0) * (1.0 - d), 0.47, 0.5) * 0.9)   # droplets thrown off it
    save(name, m)


def trail(name):
    h, w = 256, 1024
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.zeros((h, w))
    for k in range(7):   # heels and fingers dragged along the floor: parallel wavering lines
        y = 50 + k * 26 + 14 * np.sin(xx / 150.0 + k) + 18 * (noise(1, w, 60.0)[0] - 0.5)
        m = np.maximum(m, soft(1.0 - np.abs(yy - y) / rng.uniform(6, 15), 0.0, 0.6) * rng.uniform(0.6, 1.0))
    wide = soft(1.0 - np.abs(yy - 128 - 20 * np.sin(xx / 200.0)) / 90.0, 0.0, 0.6) * 0.5   # the body's own smear under them
    m = np.maximum(m, wide * soft(noise(h, w, 14.0), 0.3, 0.6))
    m *= soft(noise(h, w, 8.0), 0.15, 0.5)
    m *= soft(xx, 0, 60) * soft(w - xx, 0, 320)   # starts wet, runs dry
    save(name, m)


def scratch(name):
    h = w = 512
    m = np.zeros((h, w))
    for k in range(4):   # four nails, top-left to bottom-right, digging deeper in the middle
        x0, y0 = 70 + k * 46 + rng.uniform(-8, 8), 60 + rng.uniform(-20, 20)
        x1, y1 = x0 + 190 + rng.uniform(-20, 20), y0 + 360 + rng.uniform(-30, 30)
        for t in np.linspace(0, 1, 220):
            x = x0 + (x1 - x0) * t + 10 * np.sin(t * 5 + k)
            y = y0 + (y1 - y0) * t
            m = np.maximum(m, capsule(h, w, x, y, x + 1, y + 1, 0.8 + 3.2 * np.sin(np.pi * t)))
    save(name, m * 0.92, dark=0.45)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    hand("hand_1")
    hand("hand_2", flip=True)
    smear("smear_1")
    drip("drip_1")
    pool("pool_1")
    trail("trail_1")
    scratch("scratch_1")
