# HD remaster: seamless 512x512 surface textures (albedo + normal map) for the office, written to
# assets/textures/hd/. Pure numpy (periodic noise via FFT, so every texture tiles). Albedo values sit
# around 1.0 (light grey) because the game tints each surface with its own colour.
#   python tools/make_hd_textures.py
import os
import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "hd")
rng = np.random.default_rng(7)


def noise(scale, octaves=1, falloff=0.5):
    """Periodic band-limited noise in 0..1: `scale` = feature size in pixels."""
    out = np.zeros((N, N))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        s = scale / (2 ** o)
        f = np.fft.fftfreq(N)
        fx, fy = np.meshgrid(f, f)
        r = np.sqrt(fx ** 2 + fy ** 2)
        spec = np.exp(-(r * s) ** 2) * (rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N)))
        spec[0, 0] = 0
        n = np.real(np.fft.ifft2(spec))
        n = (n - n.mean()) / (n.std() + 1e-9)
        out += n * amp
        total += amp
        amp *= falloff
    out /= total
    return np.clip(out * 0.25 + 0.5, 0.0, 1.0)


def grid(cells, width):
    """1 on grid lines (cells x cells per texture), 0 elsewhere, soft edges."""
    x = np.arange(N) / N * cells
    d = np.abs(x - np.round(x)) * N / cells   # pixels to the nearest line
    line = np.clip(1.0 - d / width, 0.0, 1.0)
    gx, gy = np.meshgrid(line, line)
    return np.maximum(gx, gy)


def normal_map(height, strength):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    n = np.dstack([-dx, -dy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, albedo, height, strength):
    os.makedirs(OUT, exist_ok=True)
    a = np.clip(albedo, 0, 1)
    if a.ndim == 2:
        a = np.dstack([a, a, a])
    Image.fromarray((a * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    Image.fromarray(normal_map(height, strength)).save(os.path.join(OUT, name + "_n.png"))
    print("wrote", name)


def carpet():
    # 4x4 carpet tiles per texture (2 m at the game's scale = 50 cm tiles), loop pile, wear
    fine = noise(1.2)
    pile = noise(3.0)
    mottle = noise(60.0, 2)
    tiles = np.zeros((N, N))
    t = N // 4
    for i in range(4):
        for j in range(4):
            tiles[i * t:(i + 1) * t, j * t:(j + 1) * t] = rng.uniform(-0.04, 0.04)
    seams = grid(4, 1.5)
    alb = 0.86 + (fine - 0.5) * 0.22 + (pile - 0.5) * 0.12 + (mottle - 0.5) * 0.16 + tiles - seams * 0.12
    h = fine * 0.6 + pile * 0.4 - seams * 0.5
    save("carpet", alb, h, 3.0)


def wall():
    # painted plaster: orange peel, faint panel seams every metre, a little grime
    peel = noise(2.5)
    soft = noise(40.0, 3)
    seams = grid(2, 1.2)
    alb = 0.93 + (peel - 0.5) * 0.05 + (soft - 0.5) * 0.08 - seams * 0.06
    h = peel * 0.5 + soft * 0.2 - seams * 0.6
    save("wall", alb, h, 2.0)


def ceiling():
    # acoustic tiles in a metal T-bar grid, pin-hole pores
    pores = (noise(1.0) > 0.78).astype(float)
    fiss = noise(4.0)
    bars = grid(4, 3.0)
    alb = 0.9 + (fiss - 0.5) * 0.08 - pores * 0.25
    alb = alb * (1 - bars) + bars * 0.97
    h = 0.6 - pores * 0.4 + (fiss - 0.5) * 0.1 - bars * 0.0 + bars * 0.3
    save("ceiling", alb, h, 2.5)


def fabric():
    # woven partition fabric: a fine cross-hatch with some fuzz
    x = np.arange(N)
    xx, yy = np.meshgrid(x, x)
    weave = (np.sin(xx * 2 * np.pi / 6) * np.sin(yy * 2 * np.pi / 6)) * 0.5 + 0.5
    fuzz = noise(1.5)
    mottle = noise(30.0, 2)
    alb = 0.85 + (weave - 0.5) * 0.12 + (fuzz - 0.5) * 0.12 + (mottle - 0.5) * 0.1
    h = weave * 0.6 + fuzz * 0.4
    save("fabric", alb, h, 2.5)


def tile():
    # hospital vinyl tiles, 4x4 per texture: speckled, each a slightly different shade, dark seams
    speck = noise(1.0)
    cloud = noise(20.0, 2)
    tiles = np.zeros((N, N))
    t = N // 4
    for i in range(4):
        for j in range(4):
            tiles[i * t:(i + 1) * t, j * t:(j + 1) * t] = rng.uniform(-0.035, 0.035)
    seams = grid(4, 1.2)
    alb = 0.9 + (speck - 0.5) * 0.18 + (cloud - 0.5) * 0.08 + tiles - seams * 0.35
    h = 0.6 - seams * 0.8 + (speck - 0.5) * 0.05
    save("tile", alb, h, 3.0)


def concrete():
    pits = (noise(1.5) > 0.8).astype(float)
    big = noise(80.0, 4)
    grain = noise(2.0)
    alb = 0.82 + (big - 0.5) * 0.25 + (grain - 0.5) * 0.12 - pits * 0.12
    h = big * 0.4 + grain * 0.4 - pits * 0.4
    save("concrete", alb, h, 2.5)


def wood():
    # desk laminate: long grain along x, a few darker streaks
    x = np.arange(N)
    xx, yy = np.meshgrid(x, x)
    warp = noise(40.0, 2) * 30.0
    grain = np.sin((yy + warp) * 2 * np.pi / 9.0) * 0.5 + 0.5
    streak = noise(6.0)
    fine = noise(1.0)
    alb = 0.88 + (grain - 0.5) * 0.12 + (streak - 0.5) * 0.12 + (fine - 0.5) * 0.04
    h = grain * 0.3 + fine * 0.2
    save("wood", alb, h, 1.5)


def plastic():
    # moulded plastic / painted metal: a faint stipple
    st = noise(1.3)
    soft = noise(50.0, 2)
    alb = 0.95 + (st - 0.5) * 0.04 + (soft - 0.5) * 0.04
    h = st * 0.5
    save("plastic", alb, h, 1.0)


if __name__ == "__main__":
    for f in (carpet, wall, ceiling, fabric, tile, concrete, wood, plastic):
        f()
