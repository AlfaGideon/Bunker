#!/usr/bin/env python3
"""Draw a flat preview of defold/main/camp.gui so the layout can be checked
without a Defold toolchain (there is none in CI beyond bob, and bob does not
render).

The parser reads the generated .gui, converts the bottom-left node space back to
top-down screen coordinates (that is the whole point -- defold-1 shipped nodes
whose y was authored top-down and landed mirrored and off-screen), renders the
boxes, pastes the atlas images and draws the text with the same DejaVu fonts the
project uses.

Usage: python3 tools/preview_defold_layout.py [--out docs/previews/defold_camp_layout.png]
"""

import argparse
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUI = os.path.join(ROOT, "defold", "main", "camp.gui")
IMAGES = os.path.join(ROOT, "defold", "main", "images")
FONTS = os.path.join(ROOT, "defold", "main", "fonts")

W, H = 1280, 720

NODE_RE = re.compile(r"nodes \{\n(.*?)\n\}", re.S)


def num(block, key):
    m = re.search(r"%s: (-?[\d.]+)" % key, block)
    return float(m.group(1)) if m else None


def pair(block, key):
    m = re.search(r"%s \{\n\s*x: (-?[\d.]+)\n\s*y: (-?[\d.]+)\n" % key, block)
    return (float(m.group(1)), float(m.group(2))) if m else None


def string(block, key):
    m = re.search(r'%s: "(.*)"' % key, block)
    return m.group(1) if m else None


def token(block, key):
    m = re.search(r"^\s*%s: (\w+)" % key, block, re.M)
    return m.group(1) if m else None


def colour(block):
    m = re.search(r"color \{\n\s*x: ([\d.]+)\n\s*y: ([\d.]+)\n\s*z: ([\d.]+)\n\s*w: ([\d.]+)\n", block)
    if not m:
        return (255, 255, 255, 255)
    r, g, b, a = (float(v) for v in m.groups())
    return (int(r * 255), int(g * 255), int(b * 255), int(a * 255))


def parse():
    nodes = []
    with open(GUI, encoding="utf-8") as fh:
        src = fh.read()
    for m in NODE_RE.finditer(src):
        b = m.group(1)
        pos = pair(b, "position")
        size = pair(b, "size")
        nodes.append(dict(
            kind=(token(b, "type") or "TYPE_BOX").replace("TYPE_", ""),
            id=string(b, "id"),
            text=string(b, "text"),
            font=string(b, "font"),
            texture=string(b, "texture"),
            pos=pos,
            size=size,
            color=colour(b),
            pivot=token(b, "pivot") or "PIVOT_NW",
            xanchor=token(b, "xanchor") or "XANCHOR_LEFT",
            line_break="line_break: true" in b,
            blend=token(b, "blend_mode"),
        ))
    return nodes


def rect(node):
    """Screen rectangle (left, top, right, bottom), y from the top edge."""
    x, y = node["pos"]
    w, h = node["size"] if node["size"] else (0, 0)
    # bottom-left node space -> top-down screen space
    top = H - y
    left = x
    if node["pivot"] in ("PIVOT_N", "PIVOT_NE"):
        left = x - w / 2
    if node["pivot"] in ("PIVOT_W", "PIVOT_C"):
        top = y - h / 2
        if node["pivot"] == "PIVOT_C":
            left = x - w / 2
    if node["pivot"] in ("PIVOT_SW", "PIVOT_S", "PIVOT_SE"):
        top = y - h
        if node["pivot"] == "PIVOT_S":
            left = x - w / 2
    return (left, top, left + w, top + h)


def fit(img, box):
    bw = max(1, int(round(box[2] - box[0])))
    bh = max(1, int(round(box[3] - box[1])))
    scale = min(bw / img.width, bh / img.height)
    w = max(1, int(round(img.width * scale)))
    h = max(1, int(round(img.height * scale)))
    out = img.resize((w, h), Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    canvas.paste(out, ((bw - w) // 2, (bh - h) // 2))
    return canvas


PANEL_IMAGES = {
    "panel": "panel_logo.png",   # channel 0, what the player sees first
    "card": "card_back.png",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "previews", "defold_camp_layout.png"))
    args = ap.parse_args()

    nodes = parse()
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    fonts = {
        "body": ImageFont.truetype(os.path.join(FONTS, "DejaVuSans.ttf"), 26),
        "title": ImageFont.truetype(os.path.join(FONTS, "DejaVuSans-Bold.ttf"), 40),
    }

    for node in nodes:
        # the splash covers the camp at start; the preview shows the camp
        if node["id"].startswith("splash"):
            continue
        box = rect(node)
        if node["kind"] == "BOX" and node["texture"]:
            name = PANEL_IMAGES.get(node["id"])
            if name:
                img = Image.open(os.path.join(IMAGES, name))
                layer.alpha_composite(fit(img, box), (int(box[0]), int(box[1])))
            continue
        if node["kind"] == "BOX":
            if node["blend"] == "BLEND_MODE_ADD":
                r, g, b, a = node["color"]
                draw.rectangle([box[0], box[1], box[2] - 1, box[3] - 1],
                               fill=(r, g, b, int(a * 0.55)))
            else:
                draw.rectangle([box[0], box[1], box[2] - 1, box[3] - 1], fill=node["color"])
            continue

        font = fonts[node["font"]]
        text = (node["text"] or "").replace("\\n", "\n")
        lines = []
        for raw in text.split("\n"):
            if not node["line_break"] or font.getlength(raw) <= node["size"][0]:
                lines.append(raw)
                continue
            current = ""
            for word in raw.split(" "):
                probe = (current + " " + word).strip()
                if current and font.getlength(probe) > node["size"][0]:
                    lines.append(current)
                    current = word
                else:
                    current = probe
            if current:
                lines.append(current)
        line_h = font.size + 6
        for i, line in enumerate(lines):
            tx = box[0]
            if node["xanchor"] == "XANCHOR_NONE":
                tx = box[0] + (box[2] - box[0] - font.getlength(line)) / 2
            draw.text((tx, box[1] + i * line_h), line, font=font, fill=node["color"])

    canvas.alpha_composite(layer)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    canvas.convert("RGB").save(args.out)
    print("wrote %s (%dx%d)" % (os.path.relpath(args.out, ROOT), W, H))


if __name__ == "__main__":
    main()
