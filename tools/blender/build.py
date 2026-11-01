"""Build every prop in the Blender kit and export it as glTF for Godot.

Run with the Blender GUI's Python or with the ``bpy`` module:

    blender --background --python tools/blender/build.py -- --out assets/blender
    python tools/blender/build.py --out assets/blender --preview docs/previews

Outputs one ``<prop>.glb`` per builder plus, with ``--preview``, a Cycles
render next to the other documentation images.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import kit  # noqa: E402
import props_camp  # noqa: E402
import props_rooms  # noqa: E402
import props_tech  # noqa: E402

PROPS = dict(props_camp.PROPS)
PROPS.update(props_tech.PROPS)
PROPS.update(props_rooms.PROPS)


def parse() -> argparse.Namespace:
    argv = sys.argv[1:]
    if '--' in sys.argv:
        argv = sys.argv[sys.argv.index('--') + 1:]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', default='assets/blender')
    parser.add_argument('--preview', default='')
    parser.add_argument('--only', default='')
    parser.add_argument('--resolution', type=int, default=900)
    return parser.parse_args(argv)


def main() -> int:
    options = parse()
    selected = [name.strip() for name in options.only.split(',') if name.strip()]
    names = selected or list(PROPS)
    os.makedirs(options.out, exist_ok=True)
    if options.preview:
        os.makedirs(options.preview, exist_ok=True)
    built = []
    for name in names:
        kit.reset()
        PROPS[name]()
        path = os.path.join(options.out, name + '.glb')
        kit.export(path)
        built.append((name, path, os.path.getsize(path)))
        if options.preview:
            kit.reset()
            PROPS[name]()
            framing = {'campfire': ((0, 0, 0.42), 2.1, 1.45),
                       'crate': ((0, 0, 0.22), 1.35, 0.95),
                       'radio': ((0, 0, 0.19), 1.05, 0.72),
                       'radio_station': ((0, 0, 0.32), 1.25, 0.95),
                       'food_station': ((0, 0, 0.78), 2.45, 1.95),
                       'medkit': ((-0.12, 0, 0.30), 1.75, 1.02),
                       'terminal': ((0, 0, 0.58), 1.75, 1.30),
                       'bed': ((0, 0, 0.42), 3.90, 2.30),
                       'toilet': ((0, 0, 0.50), 2.30, 1.50),
                       'operating_table': ((0, 0, 0.85), 3.70, 2.35),
                       'pantry_shelf': ((0, 0, 0.95), 3.70, 2.50),
                       'boulder': ((0, 0, 0.34), 2.70, 1.60),
                       'chair': ((0, 0, 0.50), 2.45, 1.55)}.get(
                           name, ((0, 0, 0.3), 2.1, 1.45))
            # A per-prop fourth value overrides the default camera azimuth so
            # props with an open door or an off-centre silhouette still frame.
            kit.studio(target=framing[0], radius=framing[1], height=framing[2],
                       angle=framing[3] if len(framing) > 3 else -0.9,
                       resolution=options.resolution)
            kit.render(os.path.join(options.preview, 'blender-' + name + '.png'))
    for name, path, size in built:
        print(f'built {name}: {path} ({size} bytes)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
