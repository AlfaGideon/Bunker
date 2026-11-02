#!/usr/bin/env python3
"""Draw defold/main/images/card_back.png -- the face-down profession card of the
camp scene.  Kept as a script so the asset can be regenerated instead of being
an unexplained binary.

Usage: python3 tools/make_defold_card_back.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "defold", "main", "images", "card_back.png")
BOLD = os.path.join(ROOT, "defold", "main", "fonts", "DejaVuSans-Bold.ttf")
BODY = os.path.join(ROOT, "defold", "main", "fonts", "DejaVuSans.ttf")

W, H = 420, 620
INK = (22, 33, 31, 255)
PANEL = (27, 42, 39, 255)
GOLD = (201, 162, 39, 255)
DIM = (120, 132, 126, 255)
PAPER = (232, 236, 230, 255)


def centre(draw, y, text, font, fill):
    x = (W - draw.textlength(text, font=font)) / 2
    draw.text((x, y), text, font=font, fill=fill)


def main():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=18, fill=INK)
    d.rounded_rectangle([10, 10, W - 11, H - 11], radius=12, outline=GOLD, width=3)
    d.rounded_rectangle([22, 22, W - 23, H - 23], radius=8, fill=PANEL)

    # corner ticks, like a stamped dossier
    for cx, cy, sx, sy in ((34, 34, 1, 1), (W - 34, 34, -1, 1), (34, H - 34, 1, -1), (W - 34, H - 34, -1, -1)):
        d.line([(cx, cy), (cx + sx * 34, cy)], fill=GOLD, width=2)
        d.line([(cx, cy), (cx, cy + sy * 34)], fill=GOLD, width=2)

    centre(d, 48, "ПРОФЕССИЯ", ImageFont.truetype(BOLD, 30), GOLD)
    d.line([(70, 96), (W - 70, 96)], fill=(201, 162, 39, 120), width=2)

    centre(d, 150, "?", ImageFont.truetype(BOLD, 200), (46, 66, 61, 255))
    centre(d, 162, "?", ImageFont.truetype(BOLD, 200), (64, 90, 84, 255))

    # the lower third is left empty on purpose: camp.gui_script writes the
    # profession name there at run time
    d.line([(150, H - 46), (W - 150, H - 46)], fill=(201, 162, 39, 140), width=2)

    img.convert("RGB").save(OUT)
    print("wrote %s (%dx%d)" % (os.path.relpath(OUT, ROOT), W, H))


if __name__ == "__main__":
    main()
