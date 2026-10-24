# UI sounds + the menu's music-box theme. Plain Python + numpy:
#   python tools/synth_ui.py
# Writes assets/sfx/: ui_hover, ui_click, type (typewriter key), stamp (rubber stamp thud),
# pen (scribble on the sticky note), menu_theme (out-of-tune music box over a low drone, loops).
import os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 22050
rng = np.random.default_rng(21)

def save(name, x):
    x = np.asarray(x, dtype=float)
    x = x / max(np.abs(x).max(), 1e-6) * 0.9
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())

def t_(secs):
    return np.arange(int(secs * SR)) / SR

def lowpass(x, hz):
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) / (1.0 + (f / hz) ** 4), len(x))

# hover: a soft, short tick
t = t_(0.05)
save("ui_hover", np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 90) * 0.5)
# click: a lower knock with a little click on top
t = t_(0.12)
save("ui_click", np.sin(2 * np.pi * 420 * t) * np.exp(-t * 40) + 0.4 * rng.standard_normal(len(t)) * np.exp(-t * 300))
# typewriter key: a dry clack (noise burst through a band) + a tiny metal ping
t = t_(0.07)
clack = lowpass(rng.standard_normal(len(t)), 3500) * np.exp(-t * 120)
save("type", clack + 0.25 * np.sin(2 * np.pi * 2600 * t) * np.exp(-t * 60))
# stamp: a heavy thud and the slap of rubber on paper
t = t_(0.35)
thud = np.sin(2 * np.pi * (90 * t + 40 * (1 - np.exp(-t * 30)) / 30)) * np.exp(-t * 14)
slap = lowpass(rng.standard_normal(len(t)), 2000) * np.exp(-t * 45)
save("stamp", thud * 1.4 + slap)
# pen: a quick scribble (filtered noise, wobbling)
t = t_(0.45)
save("pen", lowpass(rng.standard_normal(len(t)), 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)) * np.exp(-t * 4))

# menu theme: a music box playing a lullaby slightly out of tune and slowing down, over a
# low drone and a fluorescent hum. 32 s, loops (starts and ends on silence of the box).
LEN = 32.0
t = t_(LEN)
x = np.zeros_like(t)
melody = [  # (semitones from C5, beats)
    (0, 1), (4, 1), (7, 1), (12, 2), (11, 1), (7, 1), (9, 2), (5, 1), (4, 1), (2, 2), (-1, 1), (0, 3),
    (0, 1), (4, 1), (7, 1), (12, 2), (14, 1), (12, 1), (11, 2), (9, 1), (7, 1), (6, 2), (2, 1), (0, 4),
]
beat = 0.62
pos = 0.6
for i, (semi, beats) in enumerate(melody):
    hz = 523.25 * 2 ** (semi / 12.0) * (1.0 + rng.uniform(-0.012, 0.012))   # the comb is worn
    n0 = int(pos * SR)
    tt = t[: len(t) - n0]
    note = (np.sin(2 * np.pi * hz * tt) + 0.35 * np.sin(2 * np.pi * hz * 2.01 * tt) + 0.15 * np.sin(2 * np.pi * hz * 4.2 * tt)) * np.exp(-tt * 2.6)
    x[n0:] += note[: len(x) - n0] * 0.5
    pos += beats * beat * (1.0 + 0.012 * i)   # winding down
drone = (np.sin(2 * np.pi * 55 * t) + 0.7 * np.sin(2 * np.pi * 55.6 * t) + 0.3 * np.sin(2 * np.pi * 82.4 * t)) * 0.18
hum = (np.sin(2 * np.pi * 120 * t) * 0.03 + lowpass(rng.standard_normal(len(t)), 900) * 0.02)
mix = x + drone + hum
fade = int(1.5 * SR)
mix[:fade] *= np.linspace(0, 1, fade)
mix[-fade:] *= np.linspace(1, 0, fade)
save("menu_theme", np.tanh(mix * 1.2))

# chase theme: what plays while someone is after you. 8 s loop at 130 bpm: a heartbeat kick,
# a low ostinato grinding between two notes a semitone apart, and a scraping high tremolo.
LEN = 8.0 * 60 / 65   # 16 beats
t = t_(LEN)
x = np.zeros_like(t)
beat = 60 / 130
for b in range(16):
    n0 = int(b * beat * SR)
    tt = t[: len(t) - n0]
    kick = np.sin(2 * np.pi * (48 * tt + 70 * (1 - np.exp(-tt * 25)) / 25)) * np.exp(-tt * 9)
    x[n0:] += kick[: len(x) - n0] * (1.0 if b % 2 == 0 else 0.6)
    hz = 55 * 2 ** ((1 if (b // 2) % 2 else 0) / 12)   # grinding semitone
    saw = 2 * ((hz * tt) % 1.0) - 1
    x[n0:] += lowpass(saw * np.exp(-tt * 3.5), 700)[: len(x) - n0] * 0.5
scrape = lowpass(rng.standard_normal(len(t)), 4500) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * 0.12
whine = np.sin(2 * np.pi * (1250 + 30 * np.sin(2 * np.pi * 0.25 * t)) * t) * 0.04
save("chase_theme", np.tanh((x + scrape + whine) * 1.4))
print("ok")
