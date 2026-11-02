"""Validate the Defold build's text resources against Defold's own protobuf schemas.

`bob.jar` rejects a malformed `.gui` or `.atlas` only after a full build, which
costs a CI round trip. Defold publishes the schemas, so the same check runs here
in a second; see defold/proto/README.md for the source and licence.
"""
from __future__ import annotations

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
