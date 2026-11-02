"""Validate the Defold build's text resources against Defold's own protobuf schemas.

`bob.jar` rejects a malformed `.gui` or `.atlas` only after a full build, which
costs a CI round trip. Defold publishes the schemas, so the same check runs here
in a second; see defold/proto/README.md for the source and licence.
"""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROTO = ROOT / "defold" / "proto"

PROJECT_FILES = [
    ("defold/main/main.collection", "gameobject_ddf_pb2", "CollectionDesc"),
    ("defold/main/camp.go", "gameobject_ddf_pb2", "PrototypeDesc"),
    ("defold/main/camp.gui", "gui_ddf_pb2", "SceneDesc"),
    ("defold/main/camp.atlas", "atlas_ddf_pb2", "Atlas"),
    ("defold/main/fonts/dejavu.font", "font_ddf_pb2", "FontDesc"),
    ("defold/main/fonts/dejavu_bold.font", "font_ddf_pb2", "FontDesc"),
    ("defold/input/game.input_binding", "input_ddf_pb2", "InputBinding"),
]

PACKAGES = {
    "gameobject_ddf_pb2": "gameobject",
    "properties_ddf_pb2": "gameobject",
    "gui_ddf_pb2": "gamesys",
    "atlas_ddf_pb2": "gamesys",
    "gamesys_ddf_pb2": "gamesys",
    "tile_ddf_pb2": "gamesys",
    "input_ddf_pb2": "input",
    "font_ddf_pb2": "render",
    "glyphbank_ddf_pb2": "font",
}


def _quoted(line: str) -> str:
    parts = line.split('"')
    return parts[1] if len(parts) > 2 else ''


def _flipbook_names(script: str) -> set[str]:
    """Strings handed to hash() inside a play_flipbook(...) call.

    The call is often wrapped over two lines and its argument may be a
    conditional ("anime_1" or "anime_2"), so hash(...) spans are collected and
    every quoted string inside them counts as an animation name.
    """
    names: set[str] = set()
    for match in re.finditer(r"play_flipbook\(", script):
        depth = 1
        i = match.end()
        while i < len(script) and depth:
            if script[i] == "(":
                depth += 1
            elif script[i] == ")":
                depth -= 1
            i += 1
        span = script[match.end():i]
        for call in re.finditer(r"hash\(([^)]*)\)", span):
            names.update(re.findall(r'"([^"]+)"', call.group(1)))
    return names


def check_references() -> int:
    """bob refuses a node that points at a font or atlas that is not registered.

    Registration blocks carry absolute resource paths; nodes carry the short name
    of a registered texture or font.
    """
    failures = 0
    gui = (ROOT / "defold" / "main" / "camp.gui").read_text(encoding="utf-8")
    textures: dict[str, str] = {}
    fonts: dict[str, str] = {}
    name = ""
    for line in gui.splitlines():
        stripped = line.strip()
        if stripped.startswith("name:"):
            name = _quoted(stripped)
        elif stripped.startswith("texture:") and _quoted(stripped).startswith("/"):
            textures[name] = _quoted(stripped)
        elif stripped.startswith("font:") and _quoted(stripped).startswith("/"):
            fonts[name] = _quoted(stripped)
    for registered in (textures, fonts):
        for key, path in registered.items():
            if not (ROOT / "defold" / path.lstrip("/")).exists():
                failures += 1
                print(f"FAIL defold/main/camp.gui: '{key}' points at missing {path}")
    for line in gui.splitlines():
        stripped = line.strip()
        for field, known in (("texture:", textures), ("font:", fonts)):
            if not stripped.startswith(field):
                continue
            value = _quoted(stripped)
            if value.startswith("/"):
                continue
            if value not in known:
                failures += 1
                print(f'FAIL defold/main/camp.gui: {field} "{value}" is not registered')

    # Every node and flipbook the script touches must exist: a nil node aborts
    # init()/update() and the screen freezes on its first frame -- which is
    # exactly what the first device run of this build looked like.
    script = (ROOT / "defold" / "main" / "camp.gui_script").read_text(encoding="utf-8")
    node_ids = set(re.findall(r'^\s*id: "([^"]+)"', gui, re.M))
    for used in sorted(set(re.findall(r'get_node\("([^"]+)"\)', script))):
        if used not in node_ids:
            failures += 1
            print(f'FAIL defold/main/camp.gui_script: get_node("{used}") has no such node')
    atlas = (ROOT / "defold" / "main" / "camp.atlas").read_text(encoding="utf-8")
    animations = set(re.findall(r'^\s*id: "([^"]+)"', atlas, re.M))
    for used in sorted(_flipbook_names(script)):
        if used not in animations:
            failures += 1
            print(f'FAIL defold/main/camp.gui_script: flipbook hash("{used}") is not an atlas animation')

    checks = [
        ("defold/main/camp.atlas", "image:"),
        ("defold/main/camp.go", "component:"),
        ("defold/main/main.collection", "prototype:"),
    ]
    for path, field in checks:
        text = (ROOT / path).read_text(encoding="utf-8")
        for line in text.splitlines():
            if field in line:
                target = _quoted(line)
                if target and not (ROOT / "defold" / target.lstrip("/")).exists():
                    failures += 1
                    print(f"FAIL {path}: missing {target}")

    for path in ("defold/main/fonts/dejavu.font", "defold/main/fonts/dejavu_bold.font"):
        text = (ROOT / path).read_text(encoding="utf-8")
        for line in text.splitlines():
            if line.strip().startswith("font:"):
                target = _quoted(line)
                if target and not (ROOT / "defold" / target.lstrip("/")).exists():
                    failures += 1
                    print(f"FAIL {path}: missing {target}")
    return failures


def main() -> int:
    if not PROTO.is_dir():
        print(f"missing {PROTO}; the schemas live in defold/proto")
        return 1
    workdir = Path(tempfile.mkdtemp(prefix="defold-proto-"))
    sources = [str(path) for path in sorted(PROTO.rglob("*.proto"))]
    try:
        from grpc_tools import protoc  # noqa: F401
    except ImportError:
        print("grpcio-tools is missing: pip install grpcio-tools")
        return 1
    command = [sys.executable, "-m", "grpc_tools.protoc", f"-I{PROTO}",
               f"--python_out={workdir}", *sources]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout + result.stderr)
        return 1

    sys.path.insert(0, str(workdir))
    from google.protobuf import text_format

    failures = 0
    for path, module_name, message_name in PROJECT_FILES:
        module = __import__(f"{PACKAGES[module_name]}.{module_name}", fromlist=["x"])
        message = getattr(module, message_name)()
        text = (ROOT / path).read_text(encoding="utf-8")
        try:
            text_format.Parse(text, message)
            print(f"ok   {path}")
        except Exception as error:  # noqa: BLE001 - report every schema mismatch
            failures += 1
            print(f"FAIL {path}: {error}")

    failures += check_references()

    project = (ROOT / "defold" / "game.project").read_text(encoding="utf-8")
    for needle in ["main_collection = /main/main.collectionc",
                   "game_binding = /input/game.input_bindingc",
                   "package = org.bunker.defold"]:
        if needle not in project:
            failures += 1
            print(f"FAIL defold/game.project: missing '{needle}'")
    print("Defold resources look valid" if failures == 0 else f"{failures} Defold resource problem(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
