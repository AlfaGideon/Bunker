# Порт на Defold: план по блокам

Отдельная сборка на движке **Defold** живёт рядом с Godot-версией: свой проект в
`defold/`, свой workflow и свой тег релиза `defold-N`. Пакет —
`org.bunker.defold`, поэтому Defold-APK ставится рядом с основной игрой и ничего
не затирает. Нумерация основной игры (`android-NN`, `web-NN`) не затрагивается.

Первая сборка: [defold-1](https://github.com/AlfaGideon/Bunker/releases/tag/defold-1) —
[`Bunker-Defold-1.apk`](https://github.com/AlfaGideon/Bunker/releases/download/defold-1/Bunker-Defold-1.apk),
16,9 МБ, `org.bunker.defold`, versionCode 1, versionName 0.51.1, minSdk 21,
подпись «CN=Bunker Android Release» (V3), ставится рядом с основной игрой.

## Зачем отдельная сборка

- Проверить, как игра выглядит и ощущается на другом движке, не ломая рабочую
  Godot-версию.
- Defold даёт маленький рантайм, быстрый старт и простой Android-пайплайн
  (`bob.jar` + Android SDK), что важно для слабых телефонов.
- Общий источник правды — `data/content.json`: он экспортируется в Lua
  (`tools/export_defold_data.py` → `defold/main/data/content.lua`), и CI падает,
  если экспорт разошёлся с JSON.

## Блоки

| № | Блок | Статус | Что считается готовым |
| - | --- | --- | --- |
| 1 | Лагерь и плазменная панель | **готово, `defold-1`** | сцена лагеря, панель с заставкой логотипа, аниме-канал со сменой кадров, рекламный блок, карточка профессии из общего JSON, сборка и подпись APK в CI |
| 2 | Колода 70 профессий | в работе | все 70 портретов и пиктограмм, раздача карточек, переворот карты к параметрам, библиотека профессий |
| 3 | Партия: раунды и правила | — | раскрытие карточек, голосование, способности профессий, лог партии — паритет с `server/match_game.py` |
| 4 | Бункер: помещения и станции | — | зал, кинозал, кухня, медотсек, пристройки; взаимодействия и станции |
| 5 | Лобби по WebSocket | — | те же комнаты и протокол, что у Godot-клиента (`server/app.py`), приглашения и боты |
| 6 | Звук и музыка | — | те же треки и звуки, что в `assets/audio` |

Блоки 1–2 — 2D-интерфейс; 3D-сцена лагеря (Blender-модели через glTF) встаёт в
блок 4, когда появятся материалы и свет под Defold.

## Что уже есть в блоке 1

- `defold/game.project` — 1280×720, `org.bunker.defold`, version code 1.
- `defold/main/main.collection`, `camp.go`, `camp.gui`, `camp.gui_script` — сцена
  лагеря: небо, земля, костёр, рама панели, панель, подписи, карточка.
- `defold/main/camp.atlas` — кадры панели (логотип, две аниме-раскадровки,
  рекламный щит) и рубашка карты.
- `defold/main/fonts/` — DejaVu Sans (кириллица в `extra_characters`).
- `defold/main/data/content.lua` — сгенерированный экспорт общего контента.

## Проверка ресурсов без движка

`tools/check_defold_files.py` разбирает `.gui`, `.atlas`, `.go`, `.collection`,
`.font` и `.input_binding` теми же protobuf-схемами, которыми их проверяет
`bob.jar` (копия схем — в `defold/proto`). Первые итерации показали, зачем это
нужно: `bob` ругался на `Atlas.material` и на несуществующий `TYPE_TEXTURE`
только после полной сборки APK, а проверка находит такое за секунду.

```bash
python3 -m pip install grpcio-tools
python3 tools/check_defold_files.py
```

## Конвейер сборки

`.github/workflows/defold-build.yml` срабатывает на изменения в `defold/**` и
`tools/export_defold_data.py`:

1. `tools/export_defold_data.py --check` — Lua-экспорт совпадает с `data/content.json`.
2. `tools/check_defold_files.py` — текстовые ресурсы проверены схемами Defold и
   ссылками (шрифт/атлас/прообраз зарегистрированы и существуют).
3. `bob.jar` 1.14.0 берётся из релиза `defold/defold` (нужен **JDK 25**: bob
   собран под class file version 69).
4. Сборка и бандлинг: `--archive` обязателен — бандлер 1.14 сначала собирает
   AAB, а из него через `bundletool` делает universal APK. `--keystore-pass` и
   `--key-pass` у bob — это **пути к файлам** с паролями, а не сами пароли.
5. APK проверяется `aapt2 dump badging` и `apksigner verify`, отчёт попадает в
   заметки релиза; APK и `SHA256SUMS` уходят в релиз `defold-1`.

Ключ подписи — тот же, что у Godot-сборки (секреты `BUNKER_KEYSTORE_*`).
Если секретов нет, workflow собирает debug-вариант, чтобы пайплайн не стоял.

## Как собрать

```bash
python3 tools/export_defold_data.py            # обновить Lua-экспорт
cd defold
java -jar bob.jar --platform armv7-android --architectures arm64-android,armv7-android \
  --variant debug --bundle-output build/bob resolve build bundle
```

В CI это делает `.github/workflows/defold-build.yml`: качает `bob.jar` по
`https://d.defold.com/stable/info.json`, собирает и подписывает APK ключом
проекта (если секретов нет — debug-подписью), затем обновляет релиз `defold-1`.

## Ограничения текущего блока

- Лагерь нарисован 2D-примитивами: 3D-сцена и модели из Blender — в блоке 4.
- Панель локальная: канал переключает сам игрок, лобби и «ведущий» появятся в
  блоке 5.
- Карточка показывает профессию без портрета — портреты в блоке 2.
- Рантайм проверен только сборкой и подписью: установку на телефон нужно
  подтвердить вручную, автоматического запуска APK в CI нет.
- Текст на экране рисуется DejaVu Sans (кириллица в `extra_characters`), а не
  шрифтом Godot-версии: шрифты пока не общие.
