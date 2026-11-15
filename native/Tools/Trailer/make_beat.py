"""A dark 128 BPM trap/house bed for the TikTok trailer, with a tense intro, two drops and an outro.
Run from native/: python3 Tools/Trailer/make_beat.py AppStore/video/beat.wav
Structure (beats): 0-4 intro tension + riser (the Redhead logo), 4 DROP (the title), 4-34 groove, 34-36 break + riser,
36 DROP, 36-42 groove, 42 final hit, 42-50 outro pad."""
import math, random, struct, sys, wave

R = 44100
BPM = 128
B = 60 / BPM
BEATS = 50
N = int(R * (BEATS * B + 2.0))
out = [0.0] * N
random.seed(1947)


def add(start, samples, vol=1.0):
    i0 = int(start * R)
    for j, x in enumerate(samples):
        k = i0 + j
        if 0 <= k < N:
            out[k] += x * vol


def kick():
    n = int(R * 0.32); s = []; ph = 0.0
    for i in range(n):
        t = i / R
        f = 48 + 110 * math.exp(-28 * t)
        ph += 2 * math.pi * f / R
        click = math.exp(-400 * t) * 0.5
        s.append((math.sin(ph) * math.exp(-7 * t) + click) * 1.0)
    return s


def clap():
    n = int(R * 0.22); s = []; lp = 0.0; prev = 0.0
    for i in range(n):
        t = i / R
        x = random.uniform(-1, 1)
        hp = x - prev; prev = x
        bursts = sum(math.exp(-180 * max(0, t - d)) * (t >= d) for d in (0, 0.009, 0.018))
        s.append(hp * (bursts * 0.6 + math.exp(-14 * t) * 0.5))
    return s


def hat(open_=False):
    n = int(R * (0.12 if open_ else 0.04)); s = []; prev = 0.0
    for i in range(n):
        t = i / R
        x = random.uniform(-1, 1)
        hp = x - prev; prev = x
        s.append(hp * math.exp(-(18 if open_ else 90) * t))
    return s


def bass(freq, length):
    n = int(R * length); s = []; ph = 0.0
    for i in range(n):
        t = i / R
        ph += 2 * math.pi * freq / R
        # Square-ish growl: odd harmonics, softened.
        v = math.sin(ph) + 0.35 * math.sin(3 * ph) + 0.18 * math.sin(5 * ph)
        env = min(1, t / 0.005) * math.exp(-5 * t)
        s.append(math.tanh(v * 1.4) * env)
    return s


def sub(freq, length):
    n = int(R * length); s = []; ph = 0.0
    for i in range(n):
        t = i / R
        ph += 2 * math.pi * freq / R
        s.append(math.sin(ph) * min(1, t / 0.01) * min(1, (length - t) / 0.03))
    return s


def riser(length):
    n = int(R * length); s = []; y = 0.0
    for i in range(n):
        t = i / R
        a = 0.02 + 0.5 * (t / length) ** 2           # filter opens up
        y += (random.uniform(-1, 1) - y) * a
        s.append(y * (t / length) ** 1.6)
    return s


def impact():
    n = int(R * 1.6); s = []; ph = 0.0; lp = 0.0
    for i in range(n):
        t = i / R
        ph += 2 * math.pi * (32 + 80 * math.exp(-6 * t)) / R
        lp += (random.uniform(-1, 1) - lp) * 0.05
        s.append(math.sin(ph) * math.exp(-2.2 * t) + lp * math.exp(-4 * t) * 2.5)
    return s


def pad(freqs, length):
    n = int(R * length); s = []; phs = [0.0] * len(freqs)
    for i in range(n):
        t = i / R
        v = 0.0
        for k, f in enumerate(freqs):
            phs[k] += 2 * math.pi * f * (1 + 0.002 * math.sin(2 * math.pi * 0.3 * t + k)) / R
            v += math.sin(phs[k]) + 0.3 * math.sin(2 * phs[k])
        s.append(v / len(freqs) * min(1, t / 0.6) * min(1, (length - t) / 1.2))
    return s


K, CL, HC, HO = kick(), clap(), hat(), hat(True)
# A minor: Am, F, C, G (root notes for bass, one bar each).
roots = [55.0, 43.65, 65.41, 49.0]

# Intro (beats 0-4): drone, ticking clock hats, riser into the drop.
add(0, pad([110, 164.8, 220], 4 * B + 0.4), 0.18)
for k in range(16):
    add(k * B / 4, HC, 0.18 if k % 4 else 0.3)
add(1.5 * B, riser(2.5 * B), 0.55)

def groove(b0, b1):
    for b in range(b0, b1):
        t = b * B
        add(t, K, 1.0)
        if b % 2 == 1:
            add(t, CL, 0.55)
        add(t + B / 2, HO if b % 4 == 3 else HC, 0.22)
        add(t + B / 4, HC, 0.10); add(t + 3 * B / 4, HC, 0.10)
        root = roots[(b // 4) % 4]
        add(t + B / 2, bass(root * 2, B / 2), 0.32)        # off-beat stab
        add(t, sub(root, B * 0.9), 0.45)                  # sub under the kick
    # Snare roll into the next section.
    for k in range(8):
        add((b1 - 1) * B + k * B / 8, CL, 0.12 + 0.05 * k)

add(4 * B, impact(), 0.9)
groove(4, 34)
# Break (34-36): kick drops out, riser, ticking.
add(34 * B, riser(2 * B), 0.7)
for k in range(16):
    add(34 * B + k * B / 8, HC, 0.15 + 0.02 * k)
add(36 * B, impact(), 1.0)
groove(36, 42)
# Final hit and outro (42-50).
add(42 * B, impact(), 1.0)
add(42 * B, K, 1.0)
add(42 * B, pad([110, 130.8, 164.8, 220], 8 * B + 1.5), 0.25)
for b in (44, 46, 48):
    add(b * B, K, 0.55)

peak = max(1e-9, max(abs(x) for x in out))
with wave.open(sys.argv[1], "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
    w.writeframes(b"".join(struct.pack("<h", int(math.tanh(x / peak * 1.3) / math.tanh(1.3) * 0.9 * 32767)) for x in out))
print("wrote", sys.argv[1], round(N / R, 2), "s")
