# UI sounds. Plain Python + numpy:
#   python tools/synth_ui.py
# Writes assets/sfx/: ui_hover, type (typewriter key), stamp (rubber stamp thud),
# pen (scribble on the sticky note).
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
# (ui_click now comes from tools/synth_horror.py)
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

# (the menu and chase music now come from tools/synth_horror.py)
print("ok")
