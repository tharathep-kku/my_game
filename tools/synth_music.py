# Synthesises the horror cue for the tutorial's mirror cutscene (tutorial.gd). Plain Python + numpy:
#   python tools/synth_music.py
# Writes assets/sfx/mirror_theme.wav:
#   0.0 - 6.5 s  a string cluster creeps in and climbs (they fade in behind Tong)
#   6.5 s        the hit (tutorial.gd cuts to black on it: keep HIT in sync with HIT_AT there)
#   6.5 - 9.5 s  low boom + ringing dying away over the black screen
import os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx", "mirror_theme.wav")
SR = 22050
HIT = 6.5
LEN = 9.5
rng = np.random.default_rng(13)
t = np.arange(int(LEN * SR)) / SR
build = np.clip(t / HIT, 0.0, 1.0)          # 0..1 up to the hit
before = (t < HIT).astype(float)
after = np.clip(t - HIT, 0.0, None)

def lowpass(x, hz):   # FFT roll-off: fine for an offline one-shot
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) / (1.0 + (f / hz) ** 4), len(x))

def string(hz, rise, vib_hz, phase):   # bowed-ish: a few saw harmonics, sliding up `rise` semitones
    f = hz * 2 ** (rise * build ** 2 / 12.0) * (1.0 + 0.006 * np.sin(2 * np.pi * vib_hz * t + phase))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return sum(np.sin(n * ph + phase * n) / n for n in range(1, 9))

# sub drone: two low Ds beating against each other
drone = (np.sin(2 * np.pi * 36.7 * t) + 0.8 * np.sin(2 * np.pi * 37.6 * t) + 0.4 * np.sin(2 * np.pi * 73.9 * t)) * (0.25 + 0.75 * build)

# cluster: D, Eb, Ab, A, then two higher voices that come in late. Nothing agrees with anything.
voices = [(146.8, 0.6, 4.7, 0.0, 0.0), (155.6, 1.0, 5.3, 1.1, 0.1), (207.7, 1.4, 5.9, 2.3, 0.25),
          (220.0, 0.8, 4.3, 0.7, 0.35), (466.2, 2.0, 6.4, 1.9, 0.5), (622.3, 2.6, 6.9, 0.3, 0.65)]
cluster = np.zeros_like(t)
for hz, rise, vib, ph, start in voices:
    cluster += string(hz, rise, vib, ph) * np.clip((build - start) / (1.0 - start), 0.0, 1.0) ** 1.5
tremolo = 1.0 - 0.45 * build * (0.5 + 0.5 * np.sin(2 * np.pi * (5.0 + 6.0 * build) * t))   # bows start to shake
cluster = lowpass(cluster, 2600.0) * tremolo * (0.15 + 0.85 * build ** 2)

# thin high whine, two tones grinding
whine = (np.sin(2 * np.pi * 2217.0 * t) + np.sin(2 * np.pi * 2349.0 * t)) * build ** 3 * 0.12

# breath of noise sucked up into the hit
swell = lowpass(rng.standard_normal(len(t)), 3500.0) * np.clip((t - (HIT - 2.2)) / 2.2, 0.0, 1.0) ** 3

rise = (drone * 0.9 + cluster * 0.55 + whine + swell * 1.3) * before

# the hit: pitch-dropping boom, a crack of noise, and what's left ringing in your ears
boom = np.sin(2 * np.pi * (38.0 * after + 30.0 * (1.0 - np.exp(-after * 9.0)) / 9.0)) * np.exp(-after * 1.6)
crack = lowpass(rng.standard_normal(len(t)), 5000.0) * np.exp(-after * 16.0)
ring = (np.sin(2 * np.pi * 3100.0 * t) + 0.6 * np.sin(2 * np.pi * 3144.0 * t)) * np.exp(-after * 1.1) * 0.08
stab = lowpass(sum(string(hz, 0.0, 6.0, ph) for hz, _r, _v, ph, _s in voices), 3000.0) * np.exp(-after * 5.0) * 0.25
hit = (boom * 1.6 + crack * 1.2 + ring + stab) * (t >= HIT)

x = np.tanh((rise / np.abs(rise).max() * 0.8 + hit / np.abs(hit).max()) * 1.4)   # a little grit
x[:int(0.3 * SR)] *= np.linspace(0.0, 1.0, int(0.3 * SR))
x[-int(0.8 * SR):] *= np.linspace(1.0, 0.0, int(0.8 * SR)) ** 2
x = x / np.abs(x).max() * 0.95
with wave.open(OUT, "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype("<i2").tobytes())
print(OUT, "%.2fs" % LEN)
