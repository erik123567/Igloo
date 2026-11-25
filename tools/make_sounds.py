"""Generates Igloo's original sound effects into sfx/. Run: python3 tools/make_sounds.py
All sounds made by this script are synthesized from scratch and released under CC0 (see ASSETS.md)."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack=0.005, decay=0.1):
    tt = np.arange(n) / SR
    e = np.minimum(tt / max(attack, 1e-4), 1.0) * np.exp(-tt / decay)
    return e


def noise(sec):
    return rng.uniform(-1, 1, int(sec * SR))


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def tone(freqs, sec, shape="sine"):
    tt = t(sec)
    f = np.interp(tt, np.linspace(0, sec, len(freqs)), freqs)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


# footsteps in snow: short crunchy filtered noise
for i in range(3):
    n = noise(0.09)
    x = highpass(lowpass(n, 2500 + i * 500), 400) * env(len(n), 0.004, 0.025)
    x += 0.4 * lowpass(noise(0.09), 300) * env(len(n), 0.002, 0.02)
    save(f"step_{i}", x, 0.5)

# pickup: two-note blip
x = np.concatenate([tone([880], 0.06, "tri"), tone([1320], 0.09, "tri")])
save("pickup", x * env(len(x), 0.003, 0.08), 0.45)

# gather: dull chip / scoop
n = noise(0.16)
x = lowpass(n, 1200) * env(len(n), 0.002, 0.04) + 0.6 * tone([180, 90], 0.16) * env(len(n), 0.002, 0.05)
save("gather", x, 0.6)

# place snow block: soft heavy thump
n = noise(0.25)
x = lowpass(n, 700) * env(len(n), 0.003, 0.06) + tone([110, 60], 0.25) * env(len(n), 0.003, 0.08)
save("place_block", x, 0.75)

# hit: punchy whack
n = noise(0.18)
x = highpass(n, 800) * env(len(n), 0.001, 0.03) + tone([220, 80], 0.18) * env(len(n), 0.001, 0.06)
save("hit", x, 0.75)

# swing: whoosh
n = noise(0.2)
cut = np.linspace(600, 3000, len(n))
x = np.zeros_like(n)
acc = 0.0
for i, v in enumerate(n):
    a = np.exp(-2 * np.pi * cut[i] / SR)
    acc = (1 - a) * v + a * acc
    x[i] = acc
x *= np.sin(np.linspace(0, np.pi, len(n)))
save("swing", x, 0.35)

# player hurt
x = tone([300, 170], 0.25, "tri") * env(int(0.25 * SR), 0.005, 0.12) + 0.4 * lowpass(noise(0.25), 1500) * env(int(0.25 * SR), 0.002, 0.05)
save("hurt", x, 0.7)

# wolf bite: snarl
tt = t(0.35)
n = lowpass(noise(0.35), 1800)
x = n * (0.6 + 0.4 * np.sin(2 * np.pi * 38 * tt)) * env(len(tt), 0.01, 0.15) + 0.5 * tone([160, 120], 0.35, "tri") * env(len(tt), 0.01, 0.15)
save("bite", x, 0.75)

# wolf howl: gliding voice with vibrato plus a simple echo
sec = 2.8
tt = t(sec)
f = np.interp(tt, [0, 0.5, 1.6, 2.8], [380, 640, 600, 430]) * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * tt))
ph = 2 * np.pi * np.cumsum(f) / SR
voice = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
shape = np.minimum(tt / 0.4, 1) * np.minimum((sec - tt) / 0.9, 1)
x = voice * shape + 0.05 * lowpass(noise(sec), 900) * shape
out = np.zeros(len(x) + int(0.9 * SR))
out[: len(x)] += x
for d, g in ((0.25, 0.35), (0.55, 0.2), (0.85, 0.1)):
    s = int(d * SR)
    out[s : s + len(x)] += g * x
save("howl", out, 0.55)

# hare squeak
x = tone([1500, 2300, 1800], 0.12, "tri") * env(int(0.12 * SR), 0.003, 0.05)
save("squeak", x, 0.35)

# eat: three crunches
parts = []
for i in range(3):
    n = noise(0.07)
    parts.append(highpass(lowpass(n, 3000), 600) * env(len(n), 0.002, 0.02))
    parts.append(np.zeros(int(0.06 * SR)))
save("eat", np.concatenate(parts), 0.5)

# ignite: rising whoosh then crackle
n = noise(0.7)
x = lowpass(n, 1500) * np.linspace(0, 1, len(n)) ** 2 * np.exp(-np.maximum(t(0.7) - 0.45, 0) * 12)
save("ignite", x, 0.6)

# fire crackle loop (3 s)
sec = 3.0
n = int(sec * SR)
x = 0.25 * lowpass(noise(sec), 250)
for _ in range(70):
    p = rng.integers(0, n - 600)
    L = rng.integers(80, 500)
    x[p : p + L] += rng.uniform(0.3, 1.0) * highpass(rng.uniform(-1, 1, L), 1500) * env(L, 0.0005, L / SR / 4)
fade = int(0.05 * SR)
x[:fade] *= np.linspace(0, 1, fade)
x[-fade:] *= np.linspace(1, 0, fade)
save("fire_loop", x, 0.5)

# wind loop (6 s), seamless by crossfading the ends
sec = 6.0
n = int(sec * SR)
tt = np.arange(n) / SR
w = lowpass(noise(sec + 1), 500)
w = w - lowpass(w, 80)
w1 = w[:n]
tail = w[n : n + int(SR)]
xf = int(SR)
w1[:xf] = w1[:xf] * np.linspace(0, 1, xf) + tail[:xf] * np.linspace(1, 0, xf)
gust = 0.55 + 0.45 * np.sin(2 * np.pi * tt / sec) ** 2 + 0.15 * np.sin(2 * np.pi * 3 * tt / sec)
save("wind_loop", w1 * gust, 0.55)

# igloo complete / morning chime
x = np.concatenate([tone([f], 0.16) * env(int(0.16 * SR), 0.005, 0.2) for f in (523, 659, 784)] + [tone([1046], 0.6) * env(int(0.6 * SR), 0.005, 0.3)])
save("chime", x, 0.4)

print("sounds written to", os.path.abspath(OUT))
