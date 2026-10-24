# Generates the SFX the CC0 packs lack. Run: python tools/synth_sfx.py
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
random.seed(7)

def save(name, samples):
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))

def env(i, n, a=0.01, r=0.05):
    t = i / SR; d = n / SR
    return min(1, t / a) * min(1, (d - t) / r)

def tone(freqs, dur, vol=0.4, shape=math.sin):
    n = int(dur * SR)
    return [vol * env(i, n) * sum(shape(2 * math.pi * f * i / SR) for f in freqs) / len(freqs) for i in range(n)]

def silence(d): return [0.0] * int(d * SR)

# old desk phone: two-tone ring bursts
ring = []
for _ in range(2):
    n = int(0.9 * SR)
    ring += [0.35 * env(i, n) * (math.sin(2*math.pi*440*i/SR) + math.sin(2*math.pi*480*i/SR)) * (1 if (i // 550) % 2 else 0.3) for i in range(n)]
    ring += silence(0.4)
save("phone_ring", ring)

# duck-like leather shoe squeak (pitch sweep with wobble)
def squeak(f0, f1, d):
    n = int(d * SR); ph = 0; out = []
    for i in range(n):
        f = f0 + (f1 - f0) * i / n + 40 * math.sin(i / 90)
        ph += 2 * math.pi * f / SR
        out.append(0.4 * env(i, n, 0.005, 0.03) * (math.sin(ph) + 0.5 * math.sin(2 * ph) + 0.3 * math.sin(3 * ph)) / 1.8)
    return out
pass  # replaced by freesound: save("squeak", squeak(900, 1400, 0.18))

# off-key humming (ป้าพร): detuned melody, soft saw-ish voice
melody = [262, 294, 311, 262, 349, 330, 277, 262, 247, 262]
hum = []
for f in melody:
    f *= random.uniform(0.95, 1.06)
    n = int(0.35 * SR)
    hum += [0.3 * env(i, n, 0.05, 0.08) * (math.sin(2*math.pi*f*i/SR) + 0.3*math.sin(4*math.pi*f*i/SR) + 0.15*math.sin(6*math.pi*f*i/SR)) * (1 + 0.1*math.sin(i/300)) for i in range(n)]
pass  # replaced by freesound: save("hum", hum)

# muttering (หัวหน้า / เต้): random formant-ish syllables
def babble(base, syll, speed):
    out = []
    for _ in range(syll):
        f = base * random.uniform(0.8, 1.3); n = int(random.uniform(0.6, 1.2) * speed * SR)
        fm = random.choice([500, 700, 1100])
        out += [0.35 * env(i, n, 0.01, 0.03) * (math.sin(2*math.pi*f*i/SR) * (0.6 + 0.4*math.sin(2*math.pi*fm*i/SR))) for i in range(n)]
        out += silence(random.uniform(0.01, 0.06))
    return out
pass  # replaced by freesound: save("mutter", babble(110, 14, 0.14))
pass  # replaced by freesound: save("techspeak", babble(190, 26, 0.06))
pass  # replaced by freesound: save("guard_talk", babble(95, 10, 0.2))

# water splash / holy water: filtered noise burst
n = int(0.4 * SR); y = 0; sp = []
for i in range(n):
    y = 0.7 * y + 0.3 * random.uniform(-1, 1)
    sp.append(0.6 * y * (1 - i / n) ** 2)
save("splash", sp)

# fluorescent ambience: 120Hz buzz + faint hiss, loopable (whole cycles)
n = SR * 2; amb = []
for i in range(n):
    amb.append(0.08 * math.sin(2*math.pi*120*i/SR) + 0.04 * math.sin(2*math.pi*240*i/SR) + 0.01 * random.uniform(-1, 1))
save("ambience", amb)

# scare sting: dissonant stab
pass  # replaced by freesound: save("sting", tone([233, 247, 370, 523], 1.2, 0.5, lambda x: (x / math.pi % 2) - 1))

# pickup blip / coffee pour
save("pickup", tone([880], 0.08, 0.3) + tone([1320], 0.12, 0.3))
n = int(1.0 * SR); y = 0; pour = []
for i in range(n):
    y = 0.95 * y + 0.05 * random.uniform(-1, 1)
    pour.append(2.5 * y * env(i, n, 0.1, 0.2))
save("pour", pour)
# heart-monitor beep (dream clue), one beep per second, loopable
save("beep", tone([988], 0.12, 0.35) + silence(0.88))
# gasp (out of breath while hiding)
n = int(0.5 * SR); y = 0; gasp = []
for i in range(n):
    y = 0.6 * y + 0.4 * random.uniform(-1, 1)
    gasp.append(0.7 * y * env(i, n, 0.02, 0.3) * (0.5 + 0.5 * math.sin(math.pi * i / n)))
pass  # replaced by freesound: save("gasp", gasp)
# phone vibrate: two buzz bursts
vib = []
for _ in range(2):
    n = int(0.25 * SR)
    vib += [0.4 * env(i, n, 0.01, 0.02) * math.sin(2*math.pi*170*i/SR) * (0.6 + 0.4*math.sin(2*math.pi*25*i/SR)) for i in range(n)]
    vib += silence(0.12)
save("vibrate", vib)

# police siren (ending A): two-tone wail, loopable
n = SR * 2; ph = 0; siren = []
for i in range(n):
    f = 700 + 260 * (0.5 + 0.5 * math.sin(2 * math.pi * i / n))
    ph += 2 * math.pi * f / SR
    siren.append(0.3 * (math.sin(ph) + 0.4 * math.sin(2 * ph)) / 1.4)
save("siren", siren)
# PA chime (ฝ่ายบุคคล calls a name): ding-dong-ding with a soft decay
pa = []
for f, d in ((784, 0.5), (622, 0.5), (523, 0.9)):
    n = int(d * SR)
    pa += [0.35 * math.exp(-3.0 * i / n) * (math.sin(2*math.pi*f*i/SR) + 0.3*math.sin(4*math.pi*f*i/SR)) for i in range(n)]
save("pa_chime", pa)
# TV / radio static (stairwell anomalies), loopable
save("static", [0.25 * random.uniform(-1, 1) * (0.7 + 0.3 * math.sin(i / 700)) for i in range(SR)])
# flatline (hospital): one long monitor tone
save("flatline", tone([988], 2.5, 0.3))
print("ok")
