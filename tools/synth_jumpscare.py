# Builds the death-jumpscare sounds from CC0 recordings in tools/jumpscare_src/ (+ a little synthesis).
# Needs Blender's Python (for the ogg decoder `aud` + numpy). Run from the project folder:
#   "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe" --background --factory-startup --python tools/synth_jumpscare.py
# Writes assets/sfx/:
#   scare_grab.wav   heavy thud the instant a coworker grabs you (everything else goes silent)
#   scare_riser.wav  0.3 s sucking-in swell that leads into the slam
#   scare_slam.wav   sub-bass impact + monster scream doubled an octave-ish down, overdriven
#   scare_ring.wav   ears ringing over the black screen afterwards
import os, wave
import numpy as np
import aud

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "jumpscare_src")
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 44100
rng = np.random.default_rng(7)

def load(name):
    s = aud.Sound(os.path.join(SRC, name)).resample(SR, False)
    x = s.data()
    return (x.mean(axis=1) if x.ndim > 1 else x).astype(np.float64)

def save(name, x, peak=0.95):
    x = x / (np.abs(x).max() or 1.0) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(name, "%.2fs" % (len(x) / SR))

def seg(x, start, dur):   # cut [start, start+dur) seconds
    return x[int(start * SR): int((start + dur) * SR)].copy()

def fade(x, fin=0.003, fout=0.3):
    n_in, n_out = int(fin * SR), int(fout * SR)
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out) ** 2
    return x

def repitch(x, ratio):    # tape-style: slower + lower (ratio < 1)
    idx = np.arange(0, len(x) - 1, ratio)
    return np.interp(idx, np.arange(len(x)), x)

def lowpass(x, hz):       # one-pole, enough to take the fizz off noise
    a = np.exp(-2 * np.pi * hz / SR)
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y

def norm(x):
    return x / (np.abs(x).max() or 1.0)

def place(into, x, at, gain=1.0):
    o = int(at * SR)
    end = o + len(x)
    if end > len(into):
        into = np.concatenate([into, np.zeros(end - len(into))])
    into[o:end] += x * gain
    return into

impact = norm(load("impact_1b.ogg"))
thud = norm(load("cinematic_impact.ogg"))
scream = norm(load("monster_scream.ogg"))
start = np.argmax(np.abs(scream) > 0.2) / SR - 0.01   # skip the breath in: scream from frame one

# grab: just the body of the cinematic hit, short and heavy
save("scare_grab", fade(seg(thud, 0.0, 0.7), fout=0.25))

# riser: noise swell + a falling-to-rising whoosh, sharply cut (the slam lands on the cut)
n = int(0.3 * SR)
t = np.arange(n) / SR
swell = lowpass(rng.uniform(-1, 1, n), 2500) * (t / t[-1]) ** 3
tone = np.sin(2 * np.pi * np.cumsum(180 + 900 * (t / t[-1]) ** 2) / SR) * (t / t[-1]) ** 4 * 0.5
save("scare_riser", swell + tone, peak=0.8)

# slam: impact underneath, the scream on top, the same scream slowed to 0.62x underneath it
# (monstrous), all driven into soft clipping so it's loud without being thin
body = seg(scream, start, 2.0)
slam = np.zeros(1)
slam = place(slam, fade(seg(impact, 0, 2.6), fout=0.8), 0.0, 1.6)   # the hit to the chest
slam = place(slam, fade(body, fout=0.5), 0.0, 0.75)
slam = place(slam, fade(repitch(body, 0.62)[: int(2.4 * SR)], fout=0.6), 0.0, 0.7)
slam = np.tanh(2.0 * norm(slam)) / np.tanh(2.0)
save("scare_slam", fade(slam, fout=0.6))

# ring: tinnitus whine (two close tones beating) + low rumble, fading out over the black screen
n = int(2.8 * SR)
t = np.arange(n) / SR
env = np.minimum(t / 0.05, 1) * np.exp(-t * 1.1)
ring = (np.sin(2 * np.pi * 3950 * t) + 0.6 * np.sin(2 * np.pi * 3987 * t)) * env * 0.25
rumble = lowpass(rng.uniform(-1, 1, n), 120) * np.exp(-t * 0.9) * 2.5
save("scare_ring", ring + rumble, peak=0.6)
