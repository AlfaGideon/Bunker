"""Original procedural prototype sounds, no third-party recordings or broadcasts."""
import math, random, struct, wave
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


def radio_music():
    """32 s post-apocalyptic ambient loop: A-minor drone, bells, wind, crackle."""
    length = 32.0
    total = int(RATE * length)
    drone = [110.0, 130.8125, 164.8125]
    melody = [440.0, 392.0, 349.23, 329.63, 293.66, 261.63, 392.0, 220.0]
    beats = []
    beat = 0.0
    index = 0
    while beat < length - 2.5:
        beats.append((beat, melody[index % len(melody)]))
        beat += 2.0 if index % 3 else 3.0
        index += 1
    values = []
    noise = 0.0
    for i in range(total):
        t = i / RATE
        pad = 0.0
        for freq in drone:
            swell = 0.75 + 0.25 * math.sin(2 * math.pi * t / 16.0 + freq)
            pad += math.sin(2 * math.pi * freq * t) * swell
        pad /= len(drone)
        bells = 0.0
        for onset, freq in beats:
            age = t - onset
            if age < 0 or age > 6.0:
                continue
            env = (1 - math.exp(-age * 40)) * math.exp(-age * 1.35)
            bells += env * (math.sin(2 * math.pi * freq * t) + 0.4 * math.sin(2 * math.pi * freq * 2.0 * t))
        noise = noise * 0.985 + rng.uniform(-1, 1) * 0.015
        wind = noise * (0.55 + 0.45 * math.sin(2 * math.pi * t / 11.0))
        crackle = rng.uniform(-1, 1) * 0.02 if rng.random() < 0.0009 else 0.0
        # slow pulse every four seconds: something still keeps time down there
        age = t % 4.0
        pulse = math.exp(-age * 5.0) * math.sin(2 * math.pi * 55.0 * t) * 0.5
        values.append(0.17 * pad + 0.15 * bells + 0.5 * wind + 0.16 * pulse + crackle)
    save('radio_music.wav', loop_fade(values))


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


radio_music()
radio_static()
radio_voice()
print('Generated original WAV loops and effects')
