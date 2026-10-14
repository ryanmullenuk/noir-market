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
