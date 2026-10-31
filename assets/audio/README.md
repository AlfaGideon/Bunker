# Original procedural audio

`tools/generate_audio.py` generates every mono PCM WAV file with Python's
standard library. No recordings, external stations, licensed music samples or
network streams are used.

- `music_campfire.wav` — «Эхо у костра»: Karplus-Strong guitars over Am–F–C–G,
  wind and a crackling fire (28.8 s).
- `music_zone.wav` — «Зона»: slow detuned D-minor pads, ticking eighths and a
  lonely lead (32 s).
- `music_bunker.wav` — «Гудок»: industrial A drone, metal clangs and a
  mechanical arpeggio (30 s).
- `music_gate.wav` — «Последний шлюз»: D-minor piano, quiet strings and vinyl
  crackle (33.6 s).

  These four are the original score of the game: the camp radio plays them with
  no bunker chatter, the bunker receiver treats them as the «АВРОРА-7» station.
  Each loop is rendered with its reverb tail folded back into the head, so the
  seam is inaudible. `tools/generate_music.py` renders them; the older
  `radio_music.wav` placeholder is gone.
- `radio_static.wav` — the band-limited static bed of a tuned but noisy receiver.
- `radio_voice.wav` — wordless formant "speech" that plays when another bunker
  comes through. It is a synthesiser, not a voice actor, and says no words.
- `air_loop.wav` — ventilation/wind bed.
- `click.wav`, `step.wav`, `door.wav` — short UI, footstep and mechanism effects.

All of these are original project assets dedicated to the public domain under
CC0-1.0; see [`../licenses/CC0-1.0.txt`](../licenses/CC0-1.0.txt).
This does not change the license of any other repository content. Recreate with
`python3 tools/generate_audio.py`.

The radio content itself is local and fictional: `data/radio.json` holds the
three stations, the transmissions attributed to other bunkers and the beacon
messages. Nothing is downloaded, streamed or received from a real network.

Catastrophe narration is separate: Godot's native text-to-speech API uses an
installed Russian system voice, if present. No voice recording is bundled and
the game does not integrate a cloud TTS service or microphone. The installed
Android speech engine may have its own network requirements. The UI explicitly explains unavailable
Russian voices and keeps the entire briefing readable.
