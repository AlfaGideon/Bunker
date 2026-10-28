# Original procedural audio

`tools/generate_audio.py` generates all five mono PCM WAV files with Python's
standard library. No recordings, external stations, licensed music samples, or
network streams are used. The fictional emergency station is an original
16-second instrumental loop with a faint noise layer; it contains no live news.
`air_loop.wav` is a ventilation/wind bed. The other files are short UI, footstep,
and mechanism effects. These original project sound assets are dedicated to the public domain under
CC0-1.0; see [`../licenses/CC0-1.0.txt`](../licenses/CC0-1.0.txt).
This does not change the license of any other repository content. Recreate with `python3 tools/generate_audio.py`.

Catastrophe narration is separate: Godot's native text-to-speech API uses an
installed Russian system voice, if present. No voice recording is bundled and
no cloud TTS or microphone is used. The UI explicitly explains unavailable
Russian voices and keeps the entire briefing readable.
