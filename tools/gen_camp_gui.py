#!/usr/bin/env python3
"""Generate defold/main/camp.gui from a top-down layout table.

Why this file exists
--------------------
The first Defold build (defold-1) laid its nodes out as if the gui origin were
the top-left corner, which is how the editor draws them.  On the device the gui
predicate is projected by the default render script with

    vmath.matrix4_orthographic(0, window_width, 0, window_height, near, far)

so the visible y axis points *up* and node y is measured from the **bottom**
edge.  Every node of defold-1 was therefore mirrored: the full-screen "sky" box
ended up below the screen (black background), the ground strip landed across the
middle of the display and the plasma panel plus the profession card were pushed
past the bottom edge -- the crooked, dead picture the first APK showed on a phone.

This generator keeps the layout table readable in ordinary screen coordinates
(y from the top) and converts every node with

    y_node = SCREEN_HEIGHT - y_top

PIVOT_NW / PIVOT_N then anchor the node on its north edge, which is its *top* on
screen, so the table reads exactly like the finished screen.  Column headings in
the table are (id, x, y_top, width, height).

Usage
-----
    python3 tools/gen_camp_gui.py            # rewrite defold/main/camp.gui
    python3 tools/gen_camp_gui.py --check    # fail if the .gui is out of date

The generated file is committed: bob builds it as-is and CI runs --check so the
table and the .gui cannot drift apart.
"""

import os
import sys

OUT = "defold/main/camp.gui"

SCREEN_W = 1280
SCREEN_H = 720


def box(nid, x, y, w, h, color, blend="BLEND_MODE_ALPHA", pivot="PIVOT_NW", texture=None,
        adjust_mode=None):
    return dict(kind="box", id=nid, x=x, y=y, w=w, h=h, color=color, blend=blend,
                pivot=pivot, texture=texture, adjust_mode=adjust_mode)


def text(nid, s, x, y, w, h, color, font="body", xanchor="XANCHOR_LEFT",
         pivot="PIVOT_NW", line_break=True):
    return dict(kind="text", id=nid, text=s, x=x, y=y, w=w, h=h, color=color,
                font=font, xanchor=xanchor, pivot=pivot, line_break=line_break,
                blend="BLEND_MODE_ALPHA", texture=None, adjust_mode=None)


NODES = [
    # --- camp scene -------------------------------------------------------
    box("sky", 0, 0, 1280, 720, (0.043, 0.090, 0.114, 1.0)),
    box("ground_far", 0, 486, 1280, 34, (0.086, 0.149, 0.133, 1.0)),
    box("ground", 0, 520, 1280, 200, (0.075, 0.129, 0.114, 1.0)),
    # --- plasma panel -----------------------------------------------------
    box("panel_frame", 90, 100, 892, 508, (0.110, 0.129, 0.141, 1.0)),
    box("panel", 96, 106, 880, 495, None, texture="atlas", adjust_mode="ADJUST_MODE_FIT"),
    # a moving highlight over the glass: the panel must never look like a photo
    box("scanline", 96, 300, 880, 4, (0.65, 0.95, 0.9, 0.28), blend="BLEND_MODE_ADD"),

    # --- header -----------------------------------------------------------
    text("title", "БУНКЕР • ПОСЛЕДНИЙ ШЛЮЗ", 28, 8, 1000, 50,
         (0.87, 0.95, 0.92, 1.0), font="title"),
    text("subtitle", "DEFOLD-СБОРКА · БЛОК 1: ЛАГЕРЬ И ПЛАЗМА-ПАНЕЛЬ", 28, 58, 1000, 34,
         (0.55, 0.78, 0.75, 1.0)),

    # --- caption under the panel -----------------------------------------
    text("caption", "ТЕЛЕВИЗОР · ЗАСТАВКА ЛОГОТИПА\nнажми — включить кино", 96, 608, 880, 58,
         (0.75, 0.90, 0.87, 1.0)),

    # --- profession card on the right ------------------------------------
    box("card", 1030, 100, 196, 280, None, texture="atlas", adjust_mode="ADJUST_MODE_FIT"),
    text("card_name", "ПРОФЕССИЯ", 1128, 288, 196, 80, (0.95, 0.78, 0.45, 1.0),
         xanchor="XANCHOR_NONE", pivot="PIVOT_N"),

    # --- bottom hint / tap counter ---------------------------------------
    text("hint", "тап — сменить канал · тап по карте — новая профессия", 28, 678, 1224, 32,
         (0.42, 0.55, 0.55, 1.0)),

    # --- splash (drawn last => on top) -----------------------------------
    box("splash", 0, 0, 1280, 720, (0.043, 0.090, 0.114, 1.0)),
    text("splash_title", "BUNKER", 640, 268, 640, 90, (0.87, 0.95, 0.92, 1.0),
         font="title", xanchor="XANCHOR_NONE", pivot="PIVOT_N"),
    text("splash_sub", "ПОСЛЕДНИЙ ШЛЮЗ · ЗАГРУЗКА ЛАГЕРЯ", 640, 368, 720, 40,
         (0.55, 0.78, 0.75, 1.0), xanchor="XANCHOR_NONE", pivot="PIVOT_N"),
]

HEADER = '''script: "/main/camp.gui_script"
material: "/builtins/materials/gui.material"
adjust_reference: ADJUST_REFERENCE_PARENT
textures {
  name: "atlas"
  texture: "/main/camp.atlas"
}
fonts {
  name: "body"
  font: "/main/fonts/dejavu.font"
}
fonts {
  name: "title"
  font: "/main/fonts/dejavu_bold.font"
}
'''


def emit_color(c):
    return (
        "  color {\n"
        f"    x: {c[0]}\n    y: {c[1]}\n    z: {c[2]}\n    w: {c[3]}\n"
        "  }\n"
    )


def emit(node):
    y = SCREEN_H - node["y"]
    out = ["nodes {\n"]
    out.append("  type: %s\n" % ("TYPE_BOX" if node["kind"] == "box" else "TYPE_TEXT"))
    out.append('  id: "%s"\n' % node["id"])
    if node["kind"] == "text":
        escaped = node["text"].replace(chr(92), chr(92)+chr(92)).replace(chr(10), chr(92)+"n")
        out.append('  text: "%s"\n' % escaped)
        out.append('  font: "%s"\n' % node["font"])
    elif node.get("texture"):
        out.append('  texture: "%s"\n' % node["texture"])
    out.append("  position {\n    x: %d\n    y: %d\n  }\n" % (node["x"], y))
    out.append("  size {\n    x: %d\n    y: %d\n  }\n" % (node["w"], node["h"]))
    if node.get("color"):
        out.append(emit_color(node["color"]))
    out.append("  pivot: %s\n" % node["pivot"])
    if node["kind"] == "text":
        out.append("  xanchor: %s\n  yanchor: YANCHOR_TOP\n" % node["xanchor"])
        if node["line_break"]:
            out.append("  line_break: true\n")
    if node.get("adjust_mode"):
        out.append("  adjust_mode: %s\n" % node["adjust_mode"])
    out.append("  blend_mode: %s\n" % node["blend"])
    out.append("}\n")
    return "".join(out)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, OUT)
    body = HEADER + "".join(emit(n) for n in NODES)
    if "--check" in sys.argv[1:]:
        try:
            with open(path, encoding="utf-8") as fh:
                current = fh.read()
        except FileNotFoundError:
            print("FAIL %s is missing" % OUT)
            return 1
        if current != body:
            print("FAIL %s does not match tools/gen_camp_gui.py; run the generator" % OUT)
            return 1
        print("camp.gui matches the layout table (%d nodes)" % len(NODES))
        return 0
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body)
    print("wrote camp.gui with %d nodes" % len(NODES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
