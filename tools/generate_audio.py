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
notes = [220, 261.63, 329.63, 293.66, 174.61, 220, 261.63, 329.63,
         130.81, 196, 261.63, 220, 196, 246.94, 293.66, 196]
samples = []
for i in range(RATE * 16):
    t = i / RATE
    beat = int(t)
    u = t - beat
    envelope = (1 - math.exp(-u * 16)) * math.exp(-u * 2.8)
    note = notes[beat]
    chord = sum(math.sin(2 * math.pi * f * t) for f in [55, 82.4069, 110]) / 3
    noise = rng.uniform(-1, 1) * 0.012
    samples.append(0.16 * chord + envelope * 0.18 * math.sin(2 * math.pi * note * t) + noise)
save('radio_station.wav', samples)
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
print('Generated original WAV loops and effects')
