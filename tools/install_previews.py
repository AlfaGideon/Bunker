#!/usr/bin/env python3
"""Install ONE complete current screenshot set from Actions annotation JSON files.
Usage: python tools/install_previews.py .cache/checks.json .cache/variants.json ...
Stable filenames replace previous previews; never delete before validation succeeds.
"""
import base64
import json
import re
import sys
from pathlib import Path

NAMES = dict(SCREENSHOT="bunker", WIDESHOT="wide", MENUSHOT="menu",
             SURVIVALSHOT="survival", FLOODSHOT="flood", METEORSHOT="meteors",
             INFECTIONSHOT="infection", MEDICALSHOT="medical", SLEEPSHOT="sleep",
             CHARACTERSHOT="characters", METEORDETAILSHOT="meteor-detail",
             AURORASHOT="solar", COUNCILSHOT="council", FACILITYSHOT="kitchen",
             ARCHSHOT="architecture-0", ARCHALTSHOT="architecture-17")


def install(files, root):
    parts = {}
    for file in files:
        for row in json.loads(Path(file).read_text()):
            match = re.fullmatch(r"([A-Z]+SHOT)_(\d+):(.+)", row["message"], re.S)
            if match:
                prefix, index, chunk = match.groups()
                if prefix not in NAMES:
                    continue  # Additional diagnostic views are not retained.
                parts.setdefault(prefix, {})[int(index)] = chunk
    if set(parts) != set(NAMES):
        raise ValueError("Need all 16 current previews; missing: " + str(set(NAMES) - set(parts)))
    images = {}
    for prefix, chunks in parts.items():
        if sorted(chunks) != list(range(len(chunks))):
            raise ValueError("Missing chunks: " + prefix)
        data = base64.b64decode("".join(chunks[i] for i in sorted(chunks)), validate=True)
        if not data.startswith(b"\xff\xd8") or not data.endswith(b"\xff\xd9"):
            raise ValueError("Incomplete JPEG: " + prefix)
        images[NAMES[prefix] + ".jpg"] = data
    destination = root / "docs/previews"
    destination.mkdir(parents=True, exist_ok=True)
    for name, data in images.items():
        (destination / name).write_bytes(data)
    for old in destination.glob("*.jpg"):
        if old.name not in images:
            old.unlink()
    for doc in [root / "README.md", *(root / "docs").glob("*.md")]:
        text = doc.read_text()
        text = re.sub(r"-v\d+\.\d+(?=\.jpg)", "", text)
        doc.write_text(text)
    print("Installed 16 current previews; obsolete copies removed.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    install(sys.argv[1:], Path(__file__).resolve().parent.parent)
