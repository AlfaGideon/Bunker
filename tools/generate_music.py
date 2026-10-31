"""Original post-apocalyptic music for the radio, synthesised from scratch.

Four instrumental loops live in `assets/audio`: a campfire guitar piece, a slow
"zone" waltz of detuned pads and ticks, an industrial bunker hum and a
melancholic piano theme. Everything is generated with the Python standard
library — no recordings, no third-party samples, no network — and the result is
CC0 like the rest of the project audio.

Run with `python3 tools/generate_music.py` (or let `tools/generate_audio.py`
call `render()`).
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def save(name, samples):
    # Every track leaves the generator at the same peak so the receiver's
    # volume knob means the same thing on all four stations.
    peak = max(1e-6, max(abs(x) for x in samples))
    scale = 0.78 / peak
    values = [max(-0.98, min(0.98, x * scale)) for x in samples]
    with wave.open(str(OUT / name), "wb") as w:
        w.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in values))


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def mix(target, offset, samples, gain=1.0):
    start = max(0, int(offset))
    for i, value in enumerate(samples):
        index = start + i
        if index >= len(target):
            break
        target[index] += value * gain


# ------------------------------------------------------------------ voices


def karplus(freq, dur, damp=0.9965, bright=0.5, rng=None):
    """Plucked string: the workhorse for guitars, basses and harps."""
    rng = rng or random.Random(int(freq * 977) & 0xFFFF)
    count = int(RATE * dur)
    period = max(2, int(round(RATE / freq)))
    buf = [rng.uniform(-1, 1) * bright for _ in range(period)]
    out = [0.0] * count
    index = 0
    previous = 0.0
    for i in range(count):
        current = buf[index]
        averaged = damp * 0.5 * (current + previous)
        previous = current
        buf[index] = averaged
        index = (index + 1) % period
        out[i] = current
    attack = max(1, int(RATE * 0.003))
    for i in range(min(attack, count)):
        out[i] *= i / attack
    return out


def bell(freq, dur, rng=None, partials=((1.0, 1.0), (2.01, 0.45), (3.03, 0.22), (4.7, 0.1))):
    """Inharmonic percussive bell used for the bunker's metal."""
    rng = rng or random.Random(7)
    count = int(RATE * dur)
    out = [0.0] * count
    for partial, gain in partials:
        beat = rng.uniform(0.0, 0.4)
        for i in range(count):
            t = i / RATE
            out[i] += gain * math.sin(2 * math.pi * freq * partial * t + beat) * math.exp(-t * 3.6 / (1.0 + partial))
    return out


def kick(dur=0.45, start=130.0, end=46.0, punch=12.0):
    count = int(RATE * dur)
    out = [0.0] * count
    phase = 0.0
    for i in range(count):
        t = i / RATE
        freq = end + (start - end) * math.exp(-t * 12.0)
        phase += 2 * math.pi * freq / RATE
        out[i] = math.sin(phase) * math.exp(-t * punch)
    return out


def tick(dur=0.05, cutoff=0.6, rng=None):
    rng = rng or random.Random(3)
    count = int(RATE * dur)
    out = [0.0] * count
    low = 0.0
    for i in range(count):
        noise = rng.uniform(-1, 1)
        low = low * cutoff + noise * (1.0 - cutoff)
        out[i] = (noise - low) * math.exp(-i / RATE * 60.0)
    return out


def pad(notes, dur, attack=1.6, release=2.2, detune=0.004, saw=0.35, rng=None):
    """Wide detuned chord bed with a soft gate."""
    rng = rng or random.Random(11)
    count = int(RATE * dur)
    voices = []
    for note in notes:
        base = hz(note)
        for shift in (-detune, 0.0, detune):
            voices.append((base * (1.0 + shift), rng.uniform(0, math.tau)))
    out = [0.0] * count
    for freq, phase in voices:
        for i in range(count):
            t = i / RATE
            wave_value = math.sin(math.tau * freq * t + phase)
            if saw > 0.0:
                wave_value = (1.0 - saw) * wave_value + saw * (2.0 * ((freq * t + phase) % 1.0) - 1.0)
            out[i] += wave_value
    gain = 1.0 / max(1, len(voices))
    for i in range(count):
        t = i / RATE
        env = min(1.0, t / attack) * min(1.0, max(0.0, (dur - t) / release))
        out[i] *= env * gain * 0.5
    return out


def lead(note, duration, vivid=0.5, vibrato=4.6):
    """Single sustained melodic note with vibrato and a soft tone."""
    freq = hz(note)
    count = int(RATE * duration)
    out = [0.0] * count
    phase = 0.0
    for i in range(count):
        t = i / RATE
        vib = 1.0 + 0.006 * math.sin(math.tau * vibrato * t) * min(1.0, t / 0.35)
        phase += math.tau * freq * vib / RATE
        value = math.sin(phase) * (1.0 - vivid) + vivid * (2.0 * ((phase / math.tau) % 1.0) - 1.0)
        env = min(1.0, t / 0.25) * min(1.0, max(0.0, (duration - t) / 0.6))
        out[i] = value * env
    return out


# ------------------------------------------------------------------ effects


def highpass(values, alpha=0.004):
    """Removes the sub-bass rumble that makes music read as 'just noise'."""
    out = []
    state = values[0] if values else 0.0
    for value in values:
        state += alpha * (value - state)
        out.append(value - state)
    return out


def lowpass(values, alpha=0.25):
    out = []
    state = 0.0
    for value in values:
        state += alpha * (value - state)
        out.append(state)
    return out


def reverb(values, taps=((0.093, 0.42), (0.171, 0.3), (0.281, 0.22), (0.437, 0.15), (0.63, 0.1))):
    out = list(values)
    for delay, gain in taps:
        offset = int(delay * RATE)
        for i in range(offset, len(values)):
            out[i] += values[i - offset] * gain
    return out


def wrap_tail(values, length):
    """Fold the rendered tail back into the head so the loop has no seam."""
    out = values[:length]
    for i in range(len(values) - length):
        out[i % length] += values[length + i]
    return out


# ------------------------------------------------------------------ tracks


def track_campfire():
    """«Эхо у костра» — Am F C G, Karplus-Strong guitar and a low bass."""
    length = 28.8
    tail = 5.0
    total = int(RATE * (length + tail))
    out = [0.0] * total
    beat = 0.9  # 66 BPM
    bar = beat * 4
    chords = [
        (45, [57, 60, 64, 69]),   # Am
        (41, [53, 57, 60, 65]),   # F
        (48, [55, 60, 64, 67]),   # C
        (43, [55, 59, 62, 67]),   # G
    ]
    rng = random.Random(101)
    for index in range(8):
        root, tones = chords[index % 4]
        start = index * bar
        mix(out, start * RATE, karplus(hz(root), 3.2, damp=0.9985, bright=0.7, rng=rng), 0.30)
        pattern = [0, 1, 2, 3, 2, 1, 2, 3]
        for step, tone in enumerate(pattern):
            at = start + step * (beat / 2)
            note = tones[tone] + (12 if step in (3, 7) and index % 2 else 0)
            mix(out, at * RATE, karplus(hz(note), 1.5, damp=0.997, bright=0.55, rng=rng), 0.17)
        if index % 2 == 1:
            mix(out, (start + bar - beat / 2) * RATE, karplus(hz(tones[0] + 12), 1.8, damp=0.997, bright=0.5, rng=rng), 0.12)
    # A quiet wind bed and a fire that keeps cracking under the guitar.
    noise = 0.0
    fire = random.Random(55)
    for i in range(total):
        t = i / RATE
        noise = noise * 0.992 + fire.uniform(-1, 1) * 0.008
        value = noise * (1.4 + 0.4 * math.sin(math.tau * t / 13.0))
        if fire.random() < 0.0006:
            value += fire.uniform(-0.3, 0.3)
        out[i] += value * 0.22
    return wrap_tail(reverb(highpass(lowpass(out, 0.5))), int(RATE * length))


def track_zone():
    """«Зона» — slow D-minor pads, ticking eight notes and a lonely lead."""
    length = 32.0
    tail = 6.0
    total = int(RATE * (length + tail))
    out = [0.0] * total
    beat = 1.0  # 60 BPM
    sections = [
        (38, [50, 53, 57], [69, 74, 77]),   # Dm
        (34, [46, 50, 53], [65, 70, 74]),   # Bb
        (31, [43, 46, 50], [62, 67, 70]),   # Gm
        (33, [45, 49, 52], [64, 69, 73]),   # A
    ]
    for index, (low, chord, melody) in enumerate(sections):
        start = index * 8.0
        mix(out, start * RATE, pad(chord, 9.2, attack=2.4, release=3.0, detune=0.006, saw=0.28), 0.30)
        mix(out, start * RATE, pad([low], 9.2, attack=2.8, release=3.2, detune=0.002, saw=0.1), 0.22)
        for step, note in enumerate(melody):
            at = start + 1.4 + step * 2.1
            mix(out, at * RATE, lead(note, 2.4, vivid=0.25, vibrato=4.2), 0.20)
    # Ticks and a heartbeat kick carry the rhythm without a drum kit.
    rng = random.Random(17)
    step_count = int(length / (beat / 2))
    for step in range(step_count):
        at = step * beat / 2
        accent = 0.5 if step % 4 == 0 else 0.22
        mix(out, at * RATE, tick(0.04, 0.55, rng=rng), accent * 0.22)
        if step % 4 == 0:
            mix(out, at * RATE, kick(0.5, 95.0, 40.0, punch=9.0), 0.34)
    noise = 0.0
    for i in range(total):
        t = i / RATE
        noise = noise * 0.9 + rng.uniform(-1, 1) * 0.1
        out[i] += noise * 0.05 * (0.6 + 0.4 * math.sin(math.tau * t / 19.0))
    return wrap_tail(reverb(highpass(lowpass(out, 0.45))), int(RATE * length))


def track_bunker():
    """«Гудок» — industrial hum, metal clangs and a mechanical arpeggio."""
    length = 30.0
    tail = 5.0
    total = int(RATE * (length + tail))
    out = [0.0] * total
    # Drone: two low A oscillators beating against each other.
    for i in range(total):
        t = i / RATE
        drone = math.sin(math.tau * 55.0 * t) * 0.55 + math.sin(math.tau * 55.6 * t) * 0.35
        drone += math.sin(math.tau * 110.0 * t + math.sin(math.tau * 0.13 * t) * 1.5) * 0.18
        out[i] += drone * 0.30
    rng = random.Random(23)
    # Metal every four seconds and a slow mechanical arpeggio above it.
    arp = [57, 60, 64, 67, 64, 60]
    for index in range(int(length / 4)):
        at = index * 4.0
        mix(out, at * RATE, bell(hz(45 + (index % 3) * 2), 2.6, rng=rng), 0.35)
        mix(out, at * RATE, kick(0.6, 80.0, 38.0, punch=7.0), 0.45)
        for step, note in enumerate(arp):
            offset = at + 0.5 + step * 0.5
            mix(out, offset * RATE, karplus(hz(note), 0.9, damp=0.995, bright=0.8, rng=rng), 0.09)
    # A distant horn twice per loop.
    for at in (6.0, 21.0):
        count = int(RATE * 3.4)
        horn = [0.0] * count
        phase = 0.0
        state = 0.0
        for i in range(count):
            t = i / RATE
            freq = hz(38) * (1.0 + 0.02 * math.sin(math.tau * 0.5 * t))
            phase += math.tau * freq / RATE
            value = 2.0 * ((phase / math.tau) % 1.0) - 1.0
            state += 0.08 * (value - state)
            horn[i] = state * min(1.0, t / 0.6) * min(1.0, max(0.0, (3.4 - t) / 1.4))
        mix(out, at * RATE, horn, 0.5)
    return wrap_tail(reverb(highpass(lowpass(out, 0.35), 0.002), taps=((0.12, 0.34), (0.24, 0.22), (0.41, 0.14))), int(RATE * length))


def track_gate():
    """«Последний шлюз» — D-minor piano, quiet strings and vinyl crackle."""
    length = 33.6
    tail = 6.0
    total = int(RATE * (length + tail))
    out = [0.0] * total
    bar = 4.2
    progression = [
        ([50, 53, 57], 74),   # Dm
        ([46, 50, 53], 70),   # Bb
        ([41, 45, 48], 69),   # F
        ([48, 52, 55], 67),   # C
    ]
    rng = random.Random(77)
    for index in range(8):
        chord, melody = progression[index % 4]
        start = index * bar
        for tone in chord:
            mix(out, start * RATE, karplus(hz(tone), 3.0, damp=0.998, bright=0.45, rng=rng), 0.16)
        mix(out, (start + 0.35) * RATE, karplus(hz(melody), 2.6, damp=0.9978, bright=0.4, rng=rng), 0.20)
        mix(out, (start + 1.9) * RATE, karplus(hz(melody + 3), 2.2, damp=0.9975, bright=0.4, rng=rng), 0.12)
        mix(out, start * RATE, pad([chord[0] - 12, chord[0]], 4.6, attack=1.2, release=1.6, detune=0.003, saw=0.15), 0.16)
    # Vinyl crackle keeps the piano company.
    for i in range(total):
        if rng.random() < 0.00035:
            out[i] += rng.uniform(-0.25, 0.25)
        out[i] += rng.uniform(-1, 1) * 0.004
    return wrap_tail(reverb(highpass(lowpass(out, 0.45))), int(RATE * length))


TRACKS = [
    ("music_campfire.wav", track_campfire),
    ("music_zone.wav", track_zone),
    ("music_bunker.wav", track_bunker),
    ("music_gate.wav", track_gate),
]


def render():
    OUT.mkdir(exist_ok=True)
    for name, builder in TRACKS:
        save(name, builder())
        print("wrote", name)


if __name__ == "__main__":
    render()
