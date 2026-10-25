# The game's sound bed, synthesized (numpy + scipy + soundfile, no samples except the Kenney
# footsteps it re-records for each floor):
#   pip install numpy scipy soundfile
#   python tools/synth_horror.py
# Writes assets/sfx/:
#   ambience.ogg      night office room tone: air conditioning, building rumble, faint mains hum (64 s loop)
#   drone.ogg         the dread under it: slow beating sub, a minor-second cluster that swells, breath (72 s loop)
#   chase_theme.ogg   being hunted: heartbeat pulse, low strings, endlessly rising Shepard tone, metal scrapes (24 s loop)
#   menu_theme.ogg    a worn music box playing a lullaby in a big empty room, over the dread (64 s loop)
#   light_hum.ogg     one fluorescent fitting's ballast buzz, for 3D players at the lights (4 s loop)
#   lights_off.ogg / lights_on.ogg   the power dying (relay clunk, hum winding down) / tubes striking
#   step_<carpet|tile|concrete>_<0-3>.ogg   footsteps for each floor (made from footstep00-03)
#   pickup.ogg, ui_click.ogg   picking something up (cloth and paper), a menu click (soft mechanical tick)
# Loops are built in the frequency domain (circular), so they loop without a seam.
import os
import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 44100
rng = np.random.default_rng(1983)


def save(name, x, rms=None, peak=0.89, loop=False):
    x = np.asarray(x, dtype=np.float64)
    if rms is not None:
        x = x * (rms / max(np.sqrt((x ** 2).mean()), 1e-9))
    if np.abs(x).max() > peak * 0.7:   # soft-limit whatever pokes out
        x = np.tanh(x / peak) * peak
    if not loop:   # no click at the start
        x[..., :64] *= np.linspace(0, 1, 64)
    data = np.ascontiguousarray((x.T if x.ndim > 1 else x).astype(np.float32))
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", SR, 2 if x.ndim > 1 else 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 16384):   # in blocks: one big write crashes libsndfile's encoder
            f.write(data[i:i + 16384])
    print("wrote", name, "%.1fs" % (x.shape[-1] / SR))


def t_(secs):
    return np.arange(int(round(secs * SR))) / SR


def fq(f, T):
    """Nearest frequency with a whole number of cycles in T seconds (seamless loops)."""
    return round(f * T) / T


def shaped(n, gain):
    """Loopable noise of length n with spectrum magnitude gain(freqs)."""
    f = np.fft.rfftfreq(n, 1 / SR)
    spec = (rng.standard_normal(len(f)) + 1j * rng.standard_normal(len(f))) * gain(np.maximum(f, 1e-3))
    spec[0] = 0
    x = np.fft.irfft(spec, n)
    return x / (x.std() + 1e-12)


def band(lo, hi, order=2):
    return lambda f: 1.0 / np.sqrt(1 + (lo / f) ** (2 * order)) / np.sqrt(1 + (f / hi) ** (2 * order))


def cfilter(x, gain):
    """Circular (loop-safe) filter by a frequency response."""
    f = np.fft.rfftfreq(x.shape[-1], 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) * gain(np.maximum(f, 1e-3)), x.shape[-1])


def ir(secs, damp=3000.0, pre=0.012):
    """Reverb impulse: exponentially decaying noise that darkens as it fades."""
    t = t_(secs)
    n = rng.standard_normal(len(t)) * np.exp(-6.9 * t / secs)
    # darken over time: blend a low-passed copy in as it decays
    b, a = signal.butter(2, damp / (SR / 2))
    low = signal.lfilter(b, a, n)
    w = np.clip(t / secs * 2, 0, 1)
    out = n * (1 - w) + low * w
    out = np.concatenate([np.zeros(int(pre * SR)), out])
    return out / np.sqrt((out ** 2).sum())


def creverb(x, secs, wet, damp=3000.0):
    """Circular convolution reverb (the tail wraps round: loop-safe)."""
    h = ir(secs, damp)
    n = x.shape[-1]
    H = np.fft.rfft(np.pad(h, (0, max(0, n - len(h))))[:n])
    y = np.fft.irfft(np.fft.rfft(x) * H, n)
    return x * (1 - wet) + y * wet * 3.0


def lreverb(x, secs, wet, damp=3000.0):
    """Ordinary reverb for one-shots (adds the tail)."""
    h = ir(secs, damp)
    y = signal.fftconvolve(np.pad(x, (0, len(h))), h)[: len(x) + len(h)]
    return np.pad(x, (0, len(h))) * (1 - wet) + y * wet * 3.0


def lfo(T, cycles, phase=0.0, n=None):
    t = t_(T) if n is None else np.arange(n) / SR
    return np.sin(2 * np.pi * cycles / T * t + phase)


def swell(T, cycles, phase=0.0, sharp=2.0):
    """0..1 raised-cosine swells, `cycles` per loop; sharp > 1 = shorter peaks, longer rests."""
    return ((1 - np.cos(2 * np.pi * cycles / T * t_(T) + phase)) / 2) ** sharp


def saw(f, t, top=4000.0, phase=0.0):
    """Band-limited saw (additive)."""
    x = np.zeros_like(t)
    k = 1
    while k * f < min(top, SR / 2 - 100):
        x += np.sin(2 * np.pi * k * f * t + phase * k) / k
        k += 1
    return x


# ---------------------------------------------------------------- beds
def ambience():
    T = 64.0
    n = int(T * SR)
    ch = []
    for side in range(2):
        hvac = shaped(n, lambda f: band(55, 1100)(f) / np.sqrt(f / 100) * (1 + 1.2 * np.exp(-((f - 220) / 120) ** 2)))
        hvac *= 1 + 0.18 * lfo(T, 3, side * 1.3) + 0.08 * lfo(T, 7, side)
        air = shaped(n, band(1800, 6000)) * 0.06 * (1 + 0.5 * lfo(T, 5, 2.0 + side))   # the hiss of the vents
        ch.append(hvac + air)
    rumble = shaped(n, band(18, 48, 3)) * 0.9 * (1 + 0.3 * lfo(T, 2))
    t = t_(T)
    mains = sum(a * np.sin(2 * np.pi * fq(50 * h, T) * t + h) for h, a in ((2, 1.0), (4, 0.45), (6, 0.25), (3, 0.12), (8, 0.1)))
    mains *= 0.05 * (1 + 0.25 * lfo(T, 11))
    x = np.array([ch[0] + rumble + mains, ch[1] + rumble + mains])
    x = creverb(x, 1.2, 0.25, 2000)
    save("ambience", x, rms=0.06, loop=True)


def dread_bed(T, level=1.0):
    n = int(T * SR)
    t = t_(T)
    x = np.zeros((2, n))
    sub = np.sin(2 * np.pi * fq(36.71, T) * t) + 0.8 * np.sin(2 * np.pi * fq(37.29, T) * t + 1.0)   # D1 beating against itself
    x += 0.55 * sub * (0.7 + 0.3 * swell(T, 2, 0.5, 1))
    # a minor-second cluster, each voice swelling on its own clock
    for f, cyc, ph, pan in ((73.42, 3, 0.0, 0.3), (77.78, 4, 2.0, 0.7), (110.0, 5, 4.0, 0.45), (116.54, 2, 1.0, 0.55), (155.56, 7, 3.0, 0.2)):
        ff = fq(f, T)
        v = saw(ff, t, 1200) + saw(fq(f * 1.003, T), t, 1200, 1.7)
        v = cfilter(v, band(40, 500 + f * 2))
        v *= swell(T, cyc, ph, 2.5) * 0.32
        x[0] += v * (1 - pan)
        x[1] += v * pan
    # breath: something big breathing in the walls, now and then
    breath = shaped(n, band(250, 1100)) * np.maximum(swell(T, 5, 0.0, 6.0), 0.7 * swell(T, 7, 1.3, 6.0)) * 0.12   # irregular
    x += np.array([breath, np.roll(breath, int(0.03 * SR))])
    # glass: a high bowed tone and its minor second, once a loop
    g = (np.sin(2 * np.pi * fq(1318.5, T) * t + 0.002 * SR * lfo(T, 37) / 1318.5)
         + 0.7 * np.sin(2 * np.pi * fq(1396.9, T) * t))
    g *= swell(T, 1, np.pi * 0.6, 6.0) * 0.035
    x += np.array([g * 0.8, g])
    x = creverb(x, 4.5, 0.55, 1500)
    return x * level


def drone():
    save("drone", dread_bed(72.0), rms=0.07, loop=True)


def chase_theme():
    T = 24.0            # 36 beats at 90 bpm
    beat = 60.0 / 90.0
    n = int(T * SR)
    t = t_(T)
    x = np.zeros((2, n))
    # heartbeat pulse: lub-dub on every beat
    def thump(at, amp, f0):
        i = int(at * SR) % n
        tt = t_(0.35)
        k = np.sin(2 * np.pi * (f0 * tt + 40 * (1 - np.exp(-tt * 25)) / 25)) * np.exp(-tt * 13) * amp
        k[:40] *= np.linspace(0, 1, 40)
        idx = (np.arange(len(k)) + i) % n
        x[:, idx] += k
    for b in range(36):
        thump(b * beat, 0.9, 48)
        thump(b * beat + 0.19, 0.5, 44)
    # low strings: staccato eighths, the note creeping by semitones (D, Eb, D, C#)
    notes = [73.42] * 12 + [77.78] * 12 + [73.42] * 8 + [69.30] * 4
    for b in range(36):
        f = notes[b]
        for e in range(2):
            at = b * beat + e * beat / 2
            tt = t_(beat / 2 * 0.95)
            v = saw(f, tt, 1600) + saw(f * 1.005, tt, 1600, 1.1) + 0.5 * saw(f * 2, tt, 1600, 0.4)
            env = np.minimum(tt / 0.012, 1) * (0.3 + 0.7 * np.exp(-tt * 9))
            v *= env * (1.0 if e == 0 and b % 2 == 0 else 0.65)
            i = int(at * SR)
            idx = (np.arange(len(v)) + i) % n
            x[0, idx] += v * 0.55
            x[1, idx] += v * 0.45
    x = np.array([cfilter(c, band(35, 1100)) for c in x])
    # high cluster, trembling (9 Hz tremolo), swelling twice a loop
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)
    hi = sum(np.sin(2 * np.pi * fq(f, T) * t + p) for f, p in ((440.0, 0), (466.16, 1), (659.26, 2), (698.46, 3)))
    hi *= trem * (0.3 + 0.7 * swell(T, 2, 0, 1.5)) * 0.07
    x += np.array([hi, np.roll(hi, 300)])
    # Shepard tone: always rising, never arriving (one octave per loop, phase-continuous)
    f0 = round(30.0 * T / np.log(2)) * np.log(2) / T
    she = np.zeros(n)
    for i in range(7):
        pos = (i + t / T)                      # octaves above f0
        ph = 2 * np.pi * f0 * T / np.log(2) * (2 ** pos)
        w = np.exp(-((pos - 3.5) / 1.6) ** 2)  # loud in the middle octaves, silent at both ends
        she += w * np.sin(ph)
    x += 0.16 * np.array([she, she])
    # metal scrapes every 6 s: noise through a sweeping resonator
    for k in range(4):
        start = k * 6.0 + 2.5
        tt = t_(1.6)
        nz = rng.standard_normal(len(tt))
        out = np.zeros_like(nz)
        y1 = y2 = 0.0
        for j in range(len(tt)):
            fr = 2200 + 900 * np.sin(np.pi * j / len(tt)) + 140 * np.sin(2 * np.pi * 7 * tt[j])
            r = 0.9985
            c = 2 * r * np.cos(2 * np.pi * fr / SR)
            y = nz[j] * 0.02 + c * y1 - r * r * y2
            y2, y1 = y1, y
            out[j] = y
        out *= np.sin(np.pi * tt / tt[-1]) ** 2 * 0.25 / (np.abs(out).max() + 1e-9)
        idx = (np.arange(len(out)) + int(start * SR)) % n
        x[k % 2, idx] += out
        x[(k + 1) % 2, idx] += out * 0.4
    x = creverb(x, 2.2, 0.3, 2500)
    save("chase_theme", np.tanh(x * 1.1), rms=0.12, loop=True)


def menu_theme():
    T = 64.0
    n = int(T * SR)
    x = dread_bed(T, 0.55)
    x *= 0.6 / np.sqrt((x ** 2).mean())
    # a worn music box: sine + inharmonic tine partials, wobbly pitch, a few notes out of tune
    D = {"D4": 293.66, "E4": 329.63, "F#4": 369.99, "A4": 440.0, "B4": 493.88, "D5": 587.33, "E5": 659.25, "A3": 220.0, "B3": 246.94}
    tune = ["A4", "B4", "D5", "B4", "A4", None, "F#4", "E4", "D4", None, "E4", "F#4", "A4", "F#4", "E4", None,
            "A4", "B4", "D5", "E5", "D5", "B4", "A4", None, "F#4", "E4", "D4", "B3", "A3", None, None, None]
    step = T / len(tune)
    box = np.zeros(n)
    for i, nm in enumerate(tune):
        if nm is None:
            continue
        f = D[nm] * 2 ** (rng.uniform(-18, 18) / 1200)
        at = i * step + rng.uniform(-0.06, 0.12)
        tt = t_(3.5)
        wob = 1 + 0.004 * np.sin(2 * np.pi * 0.35 * (tt + at))
        ph = 2 * np.pi * f * np.cumsum(wob) / SR
        v = (np.sin(ph) * np.exp(-tt * 1.4) + 0.35 * np.sin(2 * ph) * np.exp(-tt * 4)
             + 0.12 * np.sin(4.2 * ph) * np.exp(-tt * 9) + 0.05 * np.sin(6.8 * ph) * np.exp(-tt * 16))
        v[:30] *= np.linspace(0, 1, 30)
        idx = (np.arange(len(v)) + int(at * SR)) % n
        box[idx] += v * (0.5 if i % 4 else 0.62)
    box = cfilter(box, band(180, 5000))
    wet = creverb(np.array([box, np.roll(box, 500)]), 5.0, 0.7, 2200)
    x += wet * 0.5 / np.sqrt((wet ** 2).mean())
    save("menu_theme", x, rms=0.09, loop=True)


# ---------------------------------------------------------------- the lights
def light_hum():
    T = 4.0
    n = int(T * SR)
    t = t_(T)
    x = sum(np.sin(2 * np.pi * 100 * h * t + h * 0.7) / h ** 0.9 for h in range(1, 24))
    x = cfilter(x, band(90, 3500))
    jit = cfilter(rng.standard_normal(n), band(2, 25))
    x *= 1 + 0.25 * jit / jit.std()
    x += 0.15 * shaped(n, band(3000, 9000))
    save("light_hum", x, rms=0.1, loop=True)


def lights_off():
    t = t_(1.6)
    clunk = np.sin(2 * np.pi * (70 * t + 30 * (1 - np.exp(-t * 40)) / 40)) * np.exp(-t * 18)
    click = signal.lfilter(*signal.butter(2, [1500 / (SR / 2), 6000 / (SR / 2)], "band"), rng.standard_normal(len(t))) * np.exp(-t * 160)
    f = 100 * (1 - 0.25 * (1 - np.exp(-t * 2.5)))   # the hum winds down
    hum = sum(np.sin(2 * np.pi * h * np.cumsum(f) / SR) / h for h in range(1, 12)) * np.exp(-t * 4.5) * 0.25
    save("lights_off", lreverb(clunk + click * 1.5 + hum, 1.0, 0.2), peak=0.8)


def lights_on():
    out = np.zeros(int(1.4 * SR))
    for at, amp, dur in ((0.0, 1.0, 0.05), (0.18, 0.7, 0.07), (0.31, 0.9, 0.12), (0.62, 1.0, 0.6)):
        t = t_(dur)
        tick = signal.lfilter(*signal.butter(2, [2000 / (SR / 2), 7000 / (SR / 2)], "band"), rng.standard_normal(len(t))) * np.exp(-t * 300) * 1.2
        buzz = sum(np.sin(2 * np.pi * 100 * h * t) / h for h in range(1, 20)) * 0.25 * np.minimum(t / 0.004, 1)
        if dur < 0.5:
            buzz *= np.exp(-t * 30)
        else:
            buzz *= np.exp(-t * 3) * 0.6
        i = int(at * SR)
        seg = (tick + buzz) * amp
        out[i:i + len(seg)] += seg[: len(out) - i]
    save("lights_on", lreverb(out, 0.8, 0.15), peak=0.7)


# ---------------------------------------------------------------- footsteps per floor
def footsteps():
    for k in range(4):
        x, sr = sf.read(os.path.join(OUT, "footstep0%d.ogg" % k))
        if x.ndim > 1:
            x = x.mean(axis=1)
        x = signal.resample_poly(x, SR, sr) if sr != SR else x
        on = int(np.argmax(np.abs(x) > 0.1 * np.abs(x).max()))
        x = np.concatenate([x[max(0, on - 40):], np.zeros(int(0.25 * SR))])
        n = len(x)
        t = np.arange(n) / SR
        # carpet: a soft, muffled thud and the scuff of a sole on the pile
        b, a = signal.butter(2, 480 / (SR / 2))
        thud = signal.lfilter(b, a, signal.lfilter(b, a, x)) * 1.6
        scuff = signal.lfilter(*signal.butter(2, [900 / (SR / 2), 3200 / (SR / 2)], "band"), rng.standard_normal(n))
        scuff *= np.exp(-((t - 0.07) / 0.035) ** 2) * 0.03
        save("step_carpet_%d" % k, thud + scuff, peak=0.85)
        # tile (hospital vinyl): hard heel click, bright, a short slap back off the walls
        hi = x + signal.lfilter(*signal.butter(2, 2500 / (SR / 2), "high"), x) * 0.8
        click = signal.lfilter(*signal.butter(2, [3000 / (SR / 2), 8000 / (SR / 2)], "band"), rng.standard_normal(n)) * np.exp(-t * 500) * 0.35
        y = hi + click
        y = y + 0.32 * np.roll(y, int(0.013 * SR)) + 0.2 * np.roll(y, int(0.029 * SR))
        save("step_tile_%d" % k, y, peak=0.85)
        # concrete stairwell: grit under the sole, a long hard echo
        grit = signal.lfilter(*signal.butter(2, [1400 / (SR / 2), 6000 / (SR / 2)], "band"), rng.standard_normal(n))
        grit *= (rng.random(n) < 0.08) * np.exp(-t * 18) * 0.35
        y = signal.lfilter(*signal.butter(2, 5000 / (SR / 2)), x) + grit
        y = y + 0.35 * np.roll(y, int(0.041 * SR)) + 0.22 * np.roll(y, int(0.087 * SR)) + 0.12 * np.roll(y, int(0.15 * SR))
        save("step_concrete_%d" % k, y, peak=0.85)


# ---------------------------------------------------------------- small things
def pickup():
    t = t_(0.32)
    rustle = np.zeros(len(t))
    for at in (0.0, 0.05, 0.11, 0.16):
        rustle += np.exp(-((t - at - 0.02) / 0.018) ** 2) * rng.uniform(0.5, 1.0)
    nz = signal.lfilter(*signal.butter(2, [1200 / (SR / 2), 7000 / (SR / 2)], "band"), rng.standard_normal(len(t)))
    tap = np.sin(2 * np.pi * 180 * t) * np.exp(-t * 60) * 0.5
    save("pickup", nz * rustle * 0.6 + tap, peak=0.6)


def ui_click():
    t = t_(0.06)
    body = np.sin(2 * np.pi * 260 * t) * np.exp(-t * 90) * 0.6
    tick = signal.lfilter(*signal.butter(2, [2500 / (SR / 2), 6000 / (SR / 2)], "band"), rng.standard_normal(len(t))) * np.exp(-t * 700)
    save("ui_click", body + tick, peak=0.6)


if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for f in (ambience, drone, chase_theme, menu_theme, light_hum, lights_off, lights_on, footsteps, pickup, ui_click):
        if not only or f.__name__ in only:
            f()
