"""Bathroom sounds, synthesised from scratch.

The bathroom is the one place in the bunker where a small gag is allowed, so it
needs three sounds: a cistern flush, a giggle behind the partition and the
inevitable fart. Everything is generated with the standard library — no
recordings, no samples — and lands in ``assets/audio`` next to the rest of the
CC0 project audio.

Run with ``python3 tools/generate_sfx.py``.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = random.Random(1180)


def save(name, samples, peak=0.8):
    top = max(1e-6, max(abs(x) for x in samples))
    scale = peak / top
    values = [max(-0.98, min(0.98, x * scale)) for x in samples]
    with wave.open(str(OUT / name), "wb") as handle:
        handle.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        handle.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in values))


def flush():
    """Noise through a resonant low-pass that opens then closes, plus gurgle."""
    samples = []
    low = 0.0
    resonant = 0.0
    for index in range(int(RATE * 2.4)):
        t = index / RATE
        white = RNG.uniform(-1, 1)
        # The jet of water: brightness follows a fast attack and a long decay.
        cutoff = 0.02 + 0.22 * math.exp(-t * 1.6)
        low += (white - low) * cutoff
        resonant += (low - resonant) * 0.35
        body = resonant * 0.9 + low * 0.5
        # Bubbles: short pitched blips that fade as the cistern empties.
        gurgle = 0.0
        if t > 0.5:
            phase = (t * 7.3) % 1.0
            gurgle = math.sin(2 * math.pi * (240 + 90 * math.sin(t * 11)) * t) * max(0.0, 1.0 - phase) * 0.10
        envelope = min(1.0, t * 6.0) * math.exp(-t * 1.15)
        samples.append((body * 1.4 + gurgle) * envelope)
    return samples


def giggle():
    """Three quick rising vowels, the way a laugh sounds through a wall."""
    samples = []
    total = int(RATE * 0.85)
    for index in range(total):
        t = index / RATE
        value = 0.0
        for order, (start, pitch) in enumerate(((0.00, 520.0), (0.20, 610.0), (0.40, 560.0))):
            local = t - start
            if 0.0 <= local < 0.18:
                env = math.sin(math.pi * local / 0.18) ** 2
                wobble = 1.0 + 0.02 * math.sin(2 * math.pi * 6.5 * local)
                value += env * (math.sin(2 * math.pi * pitch * wobble * local)
                                + 0.45 * math.sin(2 * math.pi * pitch * 2.0 * wobble * local)
                                + 0.2 * math.sin(2 * math.pi * pitch * 3.0 * wobble * local)) * 0.4
        samples.append(value)
    return samples


def fart():
    """A low buzz with a wobbling filter and an apologetic tail."""
    samples = []
    phase = 0.0
    for index in range(int(RATE * 0.75)):
        t = index / RATE
        bend = 88.0 - 26.0 * t / 0.75 + 9.0 * math.sin(2 * math.pi * 5.5 * t)
        phase += 2 * math.pi * bend / RATE
        buzz = math.sin(phase) + 0.5 * math.sin(phase * 2.02) + 0.25 * math.sin(phase * 3.1)
        flutter = 0.65 + 0.35 * math.sin(2 * math.pi * 22 * t)
        envelope = min(1.0, t * 14.0) * math.exp(-t * 3.4)
        samples.append((buzz * flutter + RNG.uniform(-1, 1) * 0.06) * envelope)
    return samples


def render():
    OUT.mkdir(exist_ok=True)
    save("toilet_flush.wav", flush(), 0.72)
    save("toilet_giggle.wav", giggle(), 0.55)
    save("toilet_fart.wav", fart(), 0.62)
    print("rendered toilet_flush.wav, toilet_giggle.wav, toilet_fart.wav")


if __name__ == "__main__":
    render()
