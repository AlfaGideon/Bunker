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

## Рабочая айдентика 0.10

Знак шлюза, прозрачный логотип, загрузочная картинка и SVG-иконка созданы скриптом `tools/create_branding.py`; сторонние игровые логотипы не использованы. Растровые надписи выполнены DejaVu Sans (файл шрифта в APK не добавлен). Лагерь использует уже перечисленные CC0-модели KayKit/Quaternius и программную геометрию; сидячая анимация — KayKit `Sit_Chair_Idle`. Оттенки одежды меняют копию материала торса во время исполнения, не исходные GLB.

## Лагерь и выбранная айдентика 0.11

Выбранный пользователем AI-логотип сохранён как `assets/branding/logo-choice-next.png`; заставка, прозрачная версия меню и иконка производятся из него скриптом `tools/prepare_selected_branding.py`, без повторной генерации или перерисовки. Рабочий знак предыдущей версии заменён.

Подключены Quaternius Ultimate Nature Pack (`PineTree_1`, `PineTree_3`) и Survival Pack (`Bonfire_Fire`), CC0-1.0. Закреплённые источники и SHA-256 — `assets/manifest.json`; архив таблицы лицензий зеркала — `assets/licenses/QUATERNIUS_PACK_LICENSES.md`. Модели не изменялись; ветер, деформация огня, искры и дым применяются во время исполнения. Это стилизованные 3D-модели, не фотореалистические сканы.

## Иконка 0.12

Все варианты иконки теперь производятся из полного выбранного знака, а не из отдельного фрагмента двери. Adaptive foreground имеет прозрачные поля для безопасной области Android; фон отдельный. Новые сторонние изображения и модели для этой правки не добавлялись. Предложение о сотрудничестве — только черновик; аффилиации или интеграции с внешним сайтом нет.
