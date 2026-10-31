"""Original procedural prototype sounds, no third-party recordings or broadcasts."""
import math, random, struct, sys, wave
from pathlib import Path
RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUT.mkdir(exist_ok=True)

def save(name, samples):
    values = [max(-0.95, min(0.95, x)) for x in samples]
    with wave.open(str(OUT / name), 'wb') as w:
        w.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        w.writeframes(b''.join(struct.pack('<h', int(x * 32767)) for x in values))

rng = random.Random(517)
noise = 0.0
wind = []
for i in range(RATE * 4):
    noise = noise * 0.97 + rng.uniform(-1, 1) * 0.03
    wind.append(noise * 0.4 * (0.7 + 0.3 * math.sin(2 * math.pi * i / (RATE * 4))))
save('air_loop.wav', wind)
for name, length, frequency in [('click.wav', 0.08, 660), ('step.wav', 0.12, 95), ('door.wav', 0.6, 160)]:
    samples = []
    for i in range(int(RATE * length)):
        t = i / RATE
        env = math.exp(-t * (35 if name != 'door.wav' else 6))
        samples.append(env * (math.sin(2 * math.pi * frequency * t) * 0.18 + rng.uniform(-1, 1) * 0.05))
    save(name, samples)
# --- Radio receiver -------------------------------------------------------
# Every station sound below is synthesised from scratch: a slow minor drone
# with a sparse melody (the surviving civil station), band-limited static and
# a formant "voice" used for transmissions from other bunkers. No recordings.

def loop_fade(values, fade=0.25):
    """Crossfade the tail into the head so the loop point is inaudible."""
    n = int(RATE * fade)
    head = values[:n]
    tail = values[-n:]
    return [head[i] * (i / n) + tail[i] * (1 - i / n) for i in range(n)] + values[n:-n]


def radio_static():
    """4 s band-limited static bed for an untuned or noisy receiver."""
    values = []
    low = 0.0
    high = 0.0
    for i in range(RATE * 4):
        sample = rng.uniform(-1, 1)
        low = low * 0.82 + sample * 0.18
        high = sample - low
        gate = 0.75 + 0.25 * math.sin(2 * math.pi * i / (RATE * 4))
        values.append((low * 0.55 + high * 0.12) * gate * 0.7)
    save('radio_static.wav', loop_fade(values, 0.12))


def radio_voice():
    """5 s muffled formant chatter — a transmission, deliberately wordless."""
    values = []
    syllable = 0.0
    f1 = 520.0
    f2 = 1500.0
    for i in range(int(RATE * 5)):
        t = i / RATE
        cycle = t % 0.22
        if cycle < 0.001:
            f1 = rng.uniform(320, 700)
            f2 = rng.uniform(1050, 2100)
            syllable = rng.uniform(0.6, 1.0)
        age = cycle
        env = math.exp(-age * 9.5) * syllable
        # carrier far below the formants keeps it speech-like, not tonal
        carrier = math.sin(2 * math.pi * 128.0 * t) + 0.5 * math.sin(2 * math.pi * 256.0 * t)
        body = (math.sin(2 * math.pi * f1 * t) * 0.6 + math.sin(2 * math.pi * f2 * t) * 0.4) * carrier
        values.append(env * body * 0.34 + rng.uniform(-1, 1) * 0.012)
    # one-pole low pass: transmissions are narrow-band and muffled
    smoothed = []
    state = 0.0
    for value in values:
        state = state * 0.72 + value * 0.28
        smoothed.append(state * 1.6)
    save('radio_voice.wav', smoothed)


radio_static()
radio_voice()

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_music  # noqa: E402

generate_music.render()
print('Generated original WAV loops, effects and music')
