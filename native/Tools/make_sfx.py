"""Generates the game's small sound effects as 44.1kHz mono WAVs. Run: python3 Tools/make_sfx.py NoirMarket/Resources"""
import math, random, struct, sys, wave
R = 44100
out = sys.argv[1]

def write(name, samples):
    peak = max(1e-9, max(abs(x) for x in samples))
    with wave.open(f"{out}/{name}.wav", "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes(b"".join(struct.pack("<h", int(x / peak * 0.8 * 32767)) for x in samples))

def env(i, n, attack=0.005, decay=6.0):
    t = i / R
    a = min(1, t / attack) if attack else 1
    return a * math.exp(-decay * t)

# Cash register: a bell ding (two inharmonic partials) after a drawer clunk.
n = int(R * 0.9); s = []
for i in range(n):
    t = i / R
    clunk = (random.uniform(-1, 1) * math.exp(-60 * t)) * 0.6 if t < 0.08 else 0
    tb = t - 0.07
    bell = 0 if tb < 0 else (math.sin(2*math.pi*2093*tb) + 0.6*math.sin(2*math.pi*2637*tb) + 0.3*math.sin(2*math.pi*5274*tb)) * math.exp(-5*tb)
    s.append(clunk + bell * 0.7)
write("cash", s)

# Two-tone British siren, short.
n = int(R * 1.2); s = []; ph = 0
for i in range(n):
    t = i / R
    f = 650 if int(t / 0.3) % 2 == 0 else 870
    ph += 2*math.pi*f / R
    tone = math.sin(ph) + 0.3*math.sin(3*ph)
    s.append(tone * min(1, t / 0.05) * min(1, (1.2 - t) / 0.2) * 0.5)
write("siren", s)

# Paper rustle: band-limited noise bursts.
n = int(R * 0.45); s = []; prev = 0
for i in range(n):
    t = i / R
    x = random.uniform(-1, 1)
    prev = prev * 0.55 + x * 0.45
    burst = (math.sin(t * 38) ** 2)
    s.append((x - prev) * burst * math.exp(-3 * t))
write("page", s)

# Thud: low sine drop with noise.
n = int(R * 0.35); s = []; ph = 0
for i in range(n):
    t = i / R
    f = 120 * math.exp(-6 * t) + 40
    ph += 2*math.pi*f / R
    s.append((math.sin(ph) + random.uniform(-0.3, 0.3) * math.exp(-40*t)) * math.exp(-9 * t))
write("thud", s)

# Click: a sharp relay click (two quick transients).
n = int(R * 0.06); s = []
for i in range(n):
    t = i / R
    a = math.exp(-900 * t) * random.uniform(-1, 1)
    b = 0 if t < 0.012 else math.exp(-1400 * (t - 0.012)) * random.uniform(-1, 1) * 0.6
    tone = math.sin(2 * math.pi * 3200 * t) * math.exp(-500 * t) * 0.5
    s.append(a + b + tone)
write("click", s)

# Key: a tiny soft keystroke tick.
n = int(R * 0.025); s = []
for i in range(n):
    t = i / R
    s.append((random.uniform(-1, 1) * 0.6 + math.sin(2 * math.pi * 1800 * t) * 0.4) * math.exp(-700 * t))
write("key", s)

# Gunshot: sharp crack, then a low boom and a short room tail.
n = int(R * 0.7); s = []; lp = 0
for i in range(n):
    t = i / R
    crack = random.uniform(-1, 1) * math.exp(-90 * t)
    lp = lp * 0.92 + random.uniform(-1, 1) * 0.08
    boom = math.sin(2 * math.pi * (70 + 60 * math.exp(-30 * t)) * t) * math.exp(-9 * t)
    tail = lp * math.exp(-5 * t) * 3
    s.append(crack * 0.9 + boom * 0.8 + tail)
write("gunshot", s)

# Blade swipe: a fast filtered-noise whoosh.
n = int(R * 0.32); s = []; lp = 0
for i in range(n):
    t = i / R
    k = 0.15 + 0.8 * math.sin(math.pi * t / 0.32)
    lp = lp * (1 - k) + random.uniform(-1, 1) * k
    s.append(lp * math.sin(math.pi * t / 0.32) ** 2)
write("swipe", s)

# Explosion: long rumbling low noise.
n = int(R * 1.6); s = []; lp = 0
for i in range(n):
    t = i / R
    lp = lp * 0.97 + random.uniform(-1, 1) * 0.03
    s.append((lp * 6 + random.uniform(-1, 1) * math.exp(-20 * t)) * math.exp(-2.2 * t))
write("boom", s)

# Knuckles: a ripple of small cracks.
n = int(R * 0.7); s = [0.0] * n
for k in range(6):
    start = int(R * (0.05 + k * 0.09 + random.uniform(-0.02, 0.02)))
    for i in range(int(R * 0.03)):
        if start + i < n:
            t = i / R
            s[start + i] += random.uniform(-1, 1) * math.exp(-260 * t) * random.uniform(0.6, 1.0)
write("knuckles", s)

# Train: clickety-clack over the rails with a distant two-note horn.
n = int(R * 1.8); s = []
for i in range(n):
    t = i / R
    beat = t % 0.42
    clack = (random.uniform(-1, 1) * math.exp(-120 * beat)) + (random.uniform(-1, 1) * math.exp(-120 * max(0, beat - 0.12)) if beat > 0.12 else 0)
    horn = 0
    if 1.0 < t < 1.7:
        f = 311 if t < 1.35 else 262
        horn = (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.5 * t)) * 0.25 * min(1, (t - 1.0) / 0.05) * min(1, (1.7 - t) / 0.1)
    s.append(clack * 0.5 * min(1, (1.8 - t) / 0.4) + horn)
write("train", s)

# Bing-bong: the cabin chime.
n = int(R * 1.5); s = []
for i in range(n):
    t = i / R
    a = math.sin(2 * math.pi * 784 * t) * math.exp(-3 * t) if t < 1.5 else 0
    b = math.sin(2 * math.pi * 622 * (t - 0.45)) * math.exp(-3 * (t - 0.45)) if t > 0.45 else 0
    s.append((a + 0.6 * math.sin(2 * math.pi * 1568 * t) * math.exp(-6 * t)) * 0.5 + b * 0.6)
write("bingbong", s)

# Ring: a British double ring (400 + 450 Hz), 0.4 on, 0.2 off, 0.4 on.
n = int(R * 1.2); s = []
for i in range(n):
    t = i / R
    on = t < 0.4 or (0.6 <= t < 1.0)
    tone = (math.sin(2 * math.pi * 400 * t) + math.sin(2 * math.pi * 450 * t)) * 0.5 if on else 0
    s.append(tone * (0.6 + 0.4 * math.sin(2 * math.pi * 25 * t)))
write("ring", s)

# Win: a bright rising major arpeggio with a shimmer.
n = int(R * 0.9); s = []
notes = [(0.00, 659.3), (0.08, 830.6), (0.16, 987.8), (0.24, 1318.5)]
for i in range(n):
    t = i / R
    v = 0
    for st, f in notes:
        if t >= st:
            u = t - st
            v += (math.sin(2*math.pi*f*u) + 0.3*math.sin(4*math.pi*f*u)) * math.exp(-5*u) * 0.35
    s.append(v)
write("win", s)

# Lose: a falling minor pair with a low thud.
n = int(R * 0.9); s = []
for i in range(n):
    t = i / R
    a = math.sin(2*math.pi*392*t) * math.exp(-4*t) if t < 0.9 else 0
    b = math.sin(2*math.pi*311.1*(t-0.18)) * math.exp(-3.5*(t-0.18)) if t > 0.18 else 0
    low = math.sin(2*math.pi*(90*math.exp(-3*t)+40)*t) * math.exp(-8*t)
    s.append(a*0.35 + b*0.45 + low*0.5)
write("lose", s)
