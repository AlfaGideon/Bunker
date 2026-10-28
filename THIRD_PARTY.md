# Third-party art

The models under `assets/quaternius/` are authored by **Quaternius** and redistributed under **CC0-1.0**. Downloaded from the fan-maintained GitHub mirror `trebeljahr/quaternius-showcase`, commit `722c39e964360beff2728a8ee4d103e2d11d457c`. The mirror's code license is not used as the model license.

- Exact paths, source URLs and SHA-256 hashes: `assets/manifest.json`.
- Upstream pack license declarations preserved from mirror: `assets/licenses/QUATERNIUS_SOURCES.md`.
- CC0 legal text: `assets/licenses/CC0-1.0.txt`.
- Packs: Ultimate Modular Men/Women, Ultimate Modular Sci-Fi, Ultimate House Interior, Survival Pack.
- Files are unchanged GLB copies; scale, placement and animation are applied at runtime.
- Models contain rigs but no animation clips. Walking, idle and inspection gestures are original procedural skeletal animation in `survivor_visual.gd`, not Quaternius animation clips.

Godot is MIT-licensed. GitHub Actions downloads the official editor/export templates; no engine source is copied into this repository. No external Godot demo source code has been copied.

## Original procedural sound (0.5)

`assets/audio/*.wav` are original synthesized project sounds, not third-party
recordings. They are offered under CC0-1.0 (legal text above). Provenance and
reproduction instructions: `assets/audio/README.md`, `tools/generate_audio.py`.
The radio is a fictional local instrumental loop, not an external broadcast.
Narration uses the installed system TTS engine; no voice recordings are
redistributed. The engine and installed voice may have separate terms and
network requirements.

## KayKit character models and authored animation (0.6)

The unchanged `assets/kaykit/*.glb` files are from **KayKit Adventurers** by
**Kay Lousberg**, released under CC0-1.0. Source repository, pinned revision
and runtime adaptations: `assets/licenses/KAYKIT_SOURCE.md`; original license:
`assets/licenses/KAYKIT.txt`; original-file SHA-256: `assets/manifest.json`.
Weapons, shields, capes and helmet are hidden at runtime. These remain
stylised characters, not photorealistic humans.

Unlike the older Quaternius rigs above, KayKit includes authored animation.
The game uses `Walking_C`, `Idle` and `Use_Item` clips through a manually
advanced AnimationPlayer. The original procedural animation remains only as
a fallback for the legacy figures, including exterior infected characters.
