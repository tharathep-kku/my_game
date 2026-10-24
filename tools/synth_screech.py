# Psycho-style shrieking violin stab (scare figures lunging at you). Run: python tools/synth_screech.py
#   stab.wav    - one sharp high down-bow, the instant a coworker grabs you
#   (the death-jumpscare sounds are built by tools/synth_jumpscare.py)
import math, random, struct, wave, os

SR = 44100   # strings need the top end: 22 kHz would cut the bow harmonics
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
random.seed(13)

def save(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.95 * 32767)) for s in samples))

# One bowed string: band-limited saw (bright, nasal), wide fast vibrato, rosin scratch noise.
# glide = pitch ratio reached by the end; env(t, d) -> 0..1
def bow(f0, dur, glide, env, vib=0.018, scratch=0.25):
    n = int(dur * SR); ph = 0.0; out = []; y = 0.0; vph = random.uniform(0, 6.28)
    for i in range(n):
        t = i / SR
        f = f0 * glide ** (t / dur) * (1 + vib * math.sin(2 * math.pi * 6.5 * t + vph))
        ph += 2 * math.pi * f / SR
        s = 0.0
        k = 1
        while k * f < SR / 2.2 and k <= 14:
            s += math.sin(k * ph) / k * (1.4 if 2500 < k * f < 4500 else 1.0)   # harsh "ee" formant
            k += 1
        y = 0.5 * y + 0.5 * random.uniform(-1, 1)   # scratchy bow noise
        out.append(env(t, dur) * (s + scratch * (random.uniform(-1, 1) - y)))
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]

def place(track, at, into):
    o = int(at * SR)
    if len(into) < o + len(track):
        into += [0.0] * (o + len(track) - len(into))
    for i, s in enumerate(track):
        into[o + i] += s

def grit(x):   # overdriven: rounder than clipping, still hurts
    return [math.tanh(2.2 * s) for s in x]

stab_env = lambda t, d: min(1, t / 0.004) * math.exp(-t * 9) * min(1, (d - t) / 0.02)
hold_env = lambda t, d: min(1, t / 0.01) * min(1, (d - t) / 0.35) * (0.85 + 0.15 * math.sin(2 * math.pi * 11 * t))

# cluster of minor seconds / tritone way up the E string
CLUSTER = [2093, 2217, 2960, 3136]

stab = grit(mix(*[bow(f * random.uniform(0.995, 1.005), 0.35, 0.97, stab_env) for f in CLUSTER[:3]]))
save("stab", stab)

print("ok")
