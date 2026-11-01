# Blender kit

Пропсы бункера и лагеря modelled in code, не руками в мышке. Скрипт строит меш из примитивов, ставит материалы и выгружает glTF, который Godot импортирует сам.

## Зачем так

- `.blend` в репозитории не нужен: всё, что видно на экране, воспроизводится из нескольких сот строк Python. Правка «камни крупнее, поленья ниже» — это одна строка и повторный запуск.
- Blender открывает эти же скрипты как обычный `.py` (Text Editor → Run Script), если хочется покрутить параметры руками.
- Результат — обычный `.glb` в `assets/blender/`, рядом с пакетами Quaternius и KayKit. Godot грузит его через `BunkerArt.spawn(self, "blender_campfire", ...)`.

## Своя машина: установить Blender

1. Скачать Blender LTS 4.2 (бесплатно, open source) с blender.org и установить.
2. Проверить, что команда доступна:
   ```
   blender --version
   ```
   На Windows путь обычно `C:\Program Files\Blender Foundation\Блендер 4.2\blender.exe`, на macOS — `/Applications/Blender.app/Contents/MacOS/Blender`.

## Собрать ассеты

Из корня репозитория:

```
blender --background --python tools/blender/build.py -- --out assets/blender
```

Только один пропс и с рендером превью:

```
blender --background --python tools/blender/build.py -- --only radio --preview docs/previews
```

Без установленного Blender (только Python 3.11):

```
python3 -m venv .venv-blender
.venv-blender/bin/pip install 'bpy==4.2.0'
.venv-blender/bin/python tools/blender/build.py --out assets/blender --preview docs/previews
```

На Linux модулю `bpy` нужны системные библиотеки X11: `libxrender1 libxi6 libsm6 libice6 libxfixes3 libxxf86vm1 libxkbcommon0 libgl1`. CI ставит их сам, см. `.github/workflows/blender-assets.yml`.

## Что уже есть

| Пропс | Файл | Где в игре |
| --- | --- | --- |
| `campfire` | `assets/blender/campfire.glb` | костёр в главном меню: кольцо камней, обгоревшие поленья, угли, тренога с котелком |
| `crate` | `assets/blender/crate.glb` | ящик под приёмником |
| `radio` | `assets/blender/radio.glb` | приёмник у костра: решётка, светящаяся шкала, ручки, антенна, ручка для переноски |

Превью для документации — `docs/previews/blender-*.png` (Cycles, CPU, 800 px).

## Как добавить новый пропс

1. Написать функцию в `tools/blender/props_camp.py`, добавить её в словарь `PROPS`.
2. Запустить сборку (см. выше) — появится `assets/blender/<имя>.glb`.
3. В игре вызвать `BunkerArt.spawn(parent, "blender_<имя>", позиция, размер)`.
4. Закоммитить скрипт, `.glb` и превью.

## Ограничения

- Модели статические: без рига и анимаций. Персонажи по-прежнему из пакетов Quaternius/KayKit, у них есть скелет и позы.
- Материалы — Principled BSDF с базовым цветом, шероховатостью и металлом. Текстур нет: стиль игр низкополигональный, цвет плоскостями, поэтому glTF без картинок и мелкий по весу.
- Эмиссия (угли, шкала радио) переносится в glTF и работает в Godot, но её яркость в игре настраивается отдельно: например, у шкалы приёмника своя пульсация в `welcome.gd`.
