"""Rooms and the outdoors: beds, a toilet, an operating table, pantry shelving
and the boulders that give the surface some relief.

The bunker grew attached rooms in 0.50, so the furniture they need is modelled
here rather than reusing generic house-interior packs. Every prop keeps the same
style rules as the stations: chunky bevels, one brass or steel accent, flat
colours and a small glow where the object is powered.
"""
import math

import bpy
from mathutils import Vector

import kit


def _metal(name, color, rough=0.42, metallic=0.55):
    return kit.material(name, color, roughness=rough, metallic=metallic)


def bed() -> None:
    """Steel cot: headboard on the short end, pillow, folded blanket."""
    frame = _metal('bed-frame', (0.22, 0.25, 0.26))
    brass = _metal('bed-brass', (0.52, 0.38, 0.16), 0.35, 0.85)
    sheet = kit.material('bed-sheet', (0.80, 0.80, 0.74), roughness=0.85)
    blanket = kit.material('bed-blanket', (0.18, 0.34, 0.36), roughness=0.9)
    pillow = kit.material('bed-pillow', (0.86, 0.85, 0.80), roughness=0.9)

    parts = [
        # Frame, legs and the two rails that make it read as a cot, not a sofa.
        kit.cube('bed-deck', (1.98, 0.90, 0.05), (0, 0, 0.36), mat=frame, bevel=0.008),
        kit.cube('bed-head', (0.06, 0.92, 0.62), (-1.01, 0, 0.55), mat=frame, bevel=0.012),
        kit.cube('bed-foot', (0.05, 0.92, 0.34), (1.01, 0, 0.42), mat=frame, bevel=0.010),
        kit.cube('bed-head-cap', (0.09, 0.96, 0.05), (-1.01, 0, 0.87), mat=brass, bevel=0.008),
        kit.cube('bed-foot-cap', (0.08, 0.96, 0.04), (1.01, 0, 0.60), mat=brass, bevel=0.006),
        # Mattress sits between the rails, head end clear for the pillow.
        kit.cube('bed-mattress', (1.84, 0.78, 0.15), (0, 0, 0.46), mat=sheet,
                 bevel=0.045, segments=4),
        kit.cube('bed-pillow', (0.42, 0.60, 0.13), (-0.68, 0, 0.55), mat=pillow,
                 bevel=0.055, segments=4),
        # Blanket covers the foot two thirds and folds back over the mattress.
        kit.cube('bed-blanket', (1.10, 0.82, 0.10), (0.36, 0, 0.55), mat=blanket,
                 bevel=0.035, segments=3),
        kit.cube('bed-fold', (0.14, 0.82, 0.13), (-0.20, 0, 0.57), mat=blanket,
                 bevel=0.04, segments=3),
    ]
    for x in (-0.92, 0.92):
        for y in (-0.40, 0.40):
            parts.append(kit.cube('bed-leg', (0.06, 0.06, 0.34), (x, y, 0.17), mat=frame,
                                  bevel=0.006))
    for y in (-0.44, 0.44):
        parts.append(kit.cylinder('bed-rail', 0.018, 1.90, (0, y, 0.50),
                                  rotation=(0, math.pi / 2, 0), mat=brass, vertices=10))
    # A folded towel and a tin mug on the head end: someone lives here.
    parts.append(kit.cube('bed-towel', (0.26, 0.30, 0.06), (-0.86, 0.20, 0.53),
                          mat=blanket, bevel=0.012))
    parts.append(kit.cylinder('bed-mug', 0.035, 0.075, (-0.30, 0.30, 0.55), mat=pillow,
                              vertices=14, bevel=0.006))
    kit.join('bed', parts)


def toilet() -> None:
    """Wall-hung bowl with a cistern, a lid and a brass flush plate."""
    ceramic = kit.material('toilet-ceramic', (0.90, 0.90, 0.86), roughness=0.32)
    seat = kit.material('toilet-seat', (0.72, 0.74, 0.71), roughness=0.45)
    brass = _metal('toilet-brass', (0.55, 0.40, 0.16), 0.32, 0.9)
    steel = _metal('toilet-steel', (0.42, 0.45, 0.46), 0.35, 0.7)

    parts = [
        # Pedestal and bowl.
        kit.cylinder('toilet-foot', 0.21, 0.09, (0, -0.01, 0.045), mat=ceramic,
                     vertices=20, bevel=0.03),
        kit.cylinder('toilet-base', 0.165, 0.26, (0, 0, 0.21), mat=ceramic,
                     vertices=18, bevel=0.02),
        kit.cylinder('toilet-bowl', 0.22, 0.26, (0, -0.03, 0.40), mat=ceramic,
                     vertices=22, bevel=0.05),
        kit.torus('toilet-rim', 0.20, 0.022, (0, -0.03, 0.53), mat=seat,
                  major_segments=26),
        kit.cylinder('toilet-lid', 0.20, 0.03, (0, -0.03, 0.545), mat=seat,
                     vertices=22, bevel=0.010),
        # Cistern against the wall (the wall is at +Y in the prop's own frame).
        kit.cube('toilet-tank', (0.44, 0.16, 0.42), (0, 0.20, 0.72), mat=ceramic,
                 bevel=0.03, segments=3),
        kit.cube('toilet-tank-lid', (0.48, 0.19, 0.04), (0, 0.20, 0.94), mat=seat,
                 bevel=0.008),
        kit.cube('toilet-flush', (0.16, 0.03, 0.08), (0, 0.11, 0.90), mat=brass,
                 bevel=0.005),
        # Supply pipe and the little paper holder.
        kit.cylinder('toilet-pipe', 0.035, 0.24, (0.16, 0.16, 0.60), mat=steel,
                     vertices=12),
        kit.cube('toilet-paper-plate', (0.02, 0.09, 0.16), (-0.225, 0.12, 0.66), mat=steel,
                 bevel=0.004),
        kit.cube('toilet-paper-arm', (0.07, 0.024, 0.024), (-0.255, 0.12, 0.70), mat=steel,
                 bevel=0.004),
        kit.cylinder('toilet-paper', 0.05, 0.10, (-0.265, 0.12, 0.63),
                     rotation=(math.pi / 2, 0, 0), mat=seat, vertices=12),
    ]
    kit.join('toilet', parts)


def operating_table() -> None:
    """Stainless operating table with straps and a padded top."""
    steel = _metal('op-steel', (0.62, 0.66, 0.66), 0.26, 0.85)
    dark = _metal('op-dark', (0.16, 0.19, 0.20))
    pad = kit.material('op-pad', (0.22, 0.42, 0.44), roughness=0.7)
    strap = kit.material('op-strap', (0.12, 0.13, 0.14), roughness=0.85)
    glow = kit.material('op-glow', (0.75, 0.95, 0.95), roughness=0.3)
    glow.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (0.7, 1.0, 1.0, 1)
    glow.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 1.1

    parts = [
        kit.cube('op-base', (0.62, 0.52, 0.08), (0, 0, 0.04), mat=dark, bevel=0.01),
        kit.cylinder('op-column', 0.10, 0.52, (0, 0, 0.30), mat=steel, vertices=16,
                     bevel=0.012),
        kit.cube('op-frame', (1.10, 0.34, 0.07), (0, 0, 0.60), mat=steel, bevel=0.012),
        kit.cube('op-top', (1.96, 0.66, 0.09), (0, 0, 0.66), mat=steel, bevel=0.02),
        kit.cube('op-pad', (1.86, 0.58, 0.07), (0, 0, 0.735), mat=pad, bevel=0.03,
                 segments=3),
        kit.cube('op-headrest', (0.30, 0.34, 0.10), (-0.78, 0, 0.80), mat=pad,
                 bevel=0.035, segments=3),
    ]
    for x in (-0.46, 0.04, 0.46):
        parts.append(kit.cube('op-strap', (0.09, 0.66, 0.045), (x, 0, 0.78), mat=strap,
                              bevel=0.012))
    # Tray with the instrument roll, standing on the table itself.
    parts.append(kit.cube('op-tray', (0.38, 0.22, 0.03), (0.76, -0.08, 0.795), mat=steel,
                          bevel=0.008))
    parts.append(kit.cube('op-tray-lip', (0.40, 0.24, 0.045), (0.76, -0.08, 0.810), mat=steel,
                          bevel=0.010))
    parts.append(kit.cube('op-roll', (0.28, 0.15, 0.05), (0.76, -0.08, 0.835), mat=pad,
                          bevel=0.02))
    # Floor-standing surgical light on a pole, so the lamp needs no ceiling.
    parts.append(kit.cube('op-lamp-foot', (0.26, 0.22, 0.035), (0, 0.46, 0.018), mat=dark,
                          bevel=0.008))
    parts.append(kit.cylinder('op-lamp-pole', 0.032, 1.56, (0, 0.46, 0.80), mat=steel,
                              vertices=12))
    parts.append(kit.cube('op-lamp-arm', (0.05, 0.05, 0.10), (0, 0.44, 1.54), mat=steel,
                          bevel=0.008))
    parts.append(kit.cylinder('op-lamp', 0.30, 0.06, (0, 0.42, 1.58), rotation=(math.pi / 2, 0, 0),
                              mat=steel, vertices=22, bevel=0.01))
    parts.append(kit.cylinder('op-lamp-face', 0.26, 0.02, (0, 0.36, 1.58),
                              rotation=(math.pi / 2, 0, 0), mat=glow, vertices=22))
    kit.join('operating_table', parts)


def pantry_shelf() -> None:
    """Galvanised shelving packed with jars, sacks and tins."""
    steel = _metal('shelf-steel', (0.46, 0.48, 0.46), 0.42, 0.65)
    board = kit.material('shelf-board', (0.52, 0.40, 0.26), roughness=0.85)
    glass = kit.material('shelf-glass', (0.55, 0.66, 0.52), roughness=0.3)
    label = kit.material('shelf-label', (0.70, 0.20, 0.15), roughness=0.7)
    sack = kit.material('shelf-sack', (0.62, 0.55, 0.38), roughness=0.9)
    tin = kit.material('shelf-tin', (0.58, 0.60, 0.56), roughness=0.35, metallic=0.7)

    width, depth, height = 1.30, 0.50, 1.90
    parts = [
        kit.cube('shelf-back', (width, 0.03, height), (0, depth / 2 - 0.015, height / 2),
                 mat=steel, bevel=0.006),
    ]
    for x in (-width / 2 + 0.025, width / 2 - 0.025):
        parts.append(kit.cube('shelf-side', (0.05, depth, height), (x, 0, height / 2),
                              mat=steel, bevel=0.008))
    levels = [0.12, 0.62, 1.12, 1.62]
    for z in levels:
        parts.append(kit.cube('shelf-board', (width - 0.06, depth - 0.04, 0.035),
                              (0, -0.01, z), mat=board, bevel=0.004))
        parts.append(kit.cube('shelf-lip', (width - 0.06, 0.02, 0.06), (0, -depth / 2 + 0.03, z + 0.04),
                              mat=steel, bevel=0.004))
    # Bottom shelves: sacks and tins; upper ones: jars and a couple of boxes.
    for x in (-0.40, -0.05):
        parts.append(kit.sphere('sack', 0.16, (x, -0.02, 0.28), scale=(1.0, 0.75, 1.25),
                                mat=sack))
    for x in (0.30, 0.48):
        parts.append(kit.cylinder('tin', 0.062, 0.20, (x, -0.02, 0.25), mat=tin,
                                  vertices=14, bevel=0.008))
    for index, x in enumerate((-0.42, -0.24, -0.06, 0.12)):
        parts.append(kit.cylinder('jar', 0.058, 0.19, (x, -0.02, 0.74), mat=glass,
                                  vertices=14, bevel=0.012))
        parts.append(kit.cylinder('jar-cap', 0.061, 0.03, (x, -0.02, 0.85), mat=label,
                                  vertices=14))
    parts.append(kit.cube('crate', (0.36, 0.30, 0.24), (0.38, -0.02, 0.77), mat=board,
                          bevel=0.012))
    for index, x in enumerate((-0.44, -0.24, -0.04, 0.16, 0.36)):
        parts.append(kit.cylinder('jar', 0.055, 0.17, (x, -0.02, 1.24), mat=glass,
                                  vertices=14, bevel=0.010))
        parts.append(kit.cylinder('jar-cap', 0.058, 0.03, (x, -0.02, 1.34), mat=label,
                                  vertices=14))
    for index, x in enumerate((-0.38, -0.05, 0.28)):
        parts.append(kit.cube('box', (0.28, 0.30, 0.22), (x, -0.02, 1.74), mat=sack,
                              bevel=0.008))
        parts.append(kit.cube('box-label', (0.14, 0.01, 0.08), (x, -0.18, 1.74), mat=label))
    kit.join('pantry_shelf', parts)


def boulder() -> None:
    """Angular rock for the outside: two lobes, chipped faces, snow on top."""
    stone = kit.material('boulder-stone', (0.40, 0.41, 0.40), roughness=0.92)
    shade = kit.material('boulder-shade', (0.31, 0.32, 0.31), roughness=0.95)
    snow = kit.material('boulder-snow', (0.83, 0.87, 0.89), roughness=0.95)

    main_rock = kit.sphere('boulder-main', 0.62, (0, 0, 0.32), scale=(1.18, 0.98, 0.74),
                           mat=stone, segments=9, rings=6, smooth=False)
    kit.jitter(main_rock, 0.115, 4)
    parts = [main_rock]
    # A second lobe breaks the silhouette so it does not read as a grey ball.
    lobe = kit.sphere('boulder-lobe', 0.40, (0.52, 0.06, 0.24), scale=(0.95, 0.88, 0.80),
                      mat=shade, segments=8, rings=5, smooth=False)
    kit.jitter(lobe, 0.08, 9)
    parts.append(lobe)
    for index, (x, y, radius) in enumerate(((-0.58, 0.22, 0.26), (-0.34, -0.44, 0.20),
                                            (0.20, 0.58, 0.18))):
        piece = kit.sphere('boulder-chip', radius, (x, y, radius * 0.5),
                           scale=(1.25, 1.1, 0.85), mat=stone,
                           segments=7, rings=4, smooth=False)
        kit.jitter(piece, 0.04, 11 + index)
        parts.append(piece)
    # Snow sits on the crown, not buried inside the stone.
    cap = kit.sphere('boulder-snow-cap', 0.60, (0.02, 0.0, 0.62), scale=(1.02, 0.86, 0.36),
                     mat=snow, segments=9, rings=5, smooth=False)
    kit.jitter(cap, 0.045, 21)
    parts.append(cap)
    kit.join('boulder', parts)


def chair() -> None:
    """Armchair for the hall: someone can finally sit down."""
    fabric = kit.material('chair-fabric', (0.30, 0.36, 0.33), roughness=0.92)
    seam = kit.material('chair-seam', (0.20, 0.24, 0.22), roughness=0.9)
    brass = _metal('chair-brass', (0.50, 0.37, 0.16), 0.36, 0.8)
    frame = _metal('chair-frame', (0.24, 0.26, 0.26))

    parts = [
        kit.cube('chair-seat', (0.66, 0.62, 0.16), (0, 0, 0.42), mat=fabric, bevel=0.06,
                 segments=4),
        kit.cube('chair-back', (0.66, 0.16, 0.52), (0, 0.26, 0.70), mat=fabric, bevel=0.06,
                 segments=4),
        kit.cube('chair-back-cap', (0.70, 0.20, 0.05), (0, 0.26, 0.955), mat=brass, bevel=0.01),
        kit.cube('chair-seam', (0.60, 0.02, 0.02), (0, 0.16, 0.51), mat=seam),
    ]
    for side in (-1, 1):
        parts.append(kit.cube('chair-arm', (0.10, 0.56, 0.10), (side * 0.34, 0.02, 0.56),
                              mat=fabric, bevel=0.03))
        parts.append(kit.cube('chair-arm-post', (0.07, 0.08, 0.20), (side * 0.34, -0.20, 0.50),
                              mat=frame, bevel=0.01))
    for x in (-0.26, 0.26):
        for y in (-0.22, 0.22):
            parts.append(kit.cylinder('chair-leg', 0.028, 0.34, (x, y, 0.17), mat=frame,
                                      vertices=10, bevel=0.006))
    # A blanket draped over the arm: the chair belongs to somebody.
    fabric_throw = blanket_fabric()
    parts.append(kit.cube('chair-throw', (0.28, 0.34, 0.05), (-0.35, 0.02, 0.605),
                          mat=fabric_throw, bevel=0.02))
    parts.append(kit.cube('chair-throw-hang', (0.28, 0.05, 0.28), (-0.35, -0.15, 0.47),
                          mat=fabric_throw, bevel=0.02))
    kit.join('chair', parts)


def blanket_fabric():
    return kit.material('chair-throw', (0.52, 0.24, 0.20), roughness=0.94)


def plasma_tv() -> None:
    """Big plasma panel on a banner stand.

    The screen faces -Y in Blender, which is +Z in Godot: the camp camera looks
    down -Z, so the panel greets the camp fire. The glass surface is a separate
    material named `tv-screen`, and the game swaps it for a live viewport.
    """
    shell = _metal('tv-shell', (0.13, 0.15, 0.16), 0.34, 0.6)
    edge = _metal('tv-edge', (0.24, 0.27, 0.28), 0.28, 0.55)
    glass = kit.material('tv-screen', (0.02, 0.04, 0.05), roughness=0.12, metallic=0.25)
    on_air = kit.material('tv-on-air', (0.85, 0.18, 0.12), roughness=0.4)
    on_air.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (1.0, 0.16, 0.10, 1)
    on_air.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 2.2
    power = kit.material('tv-power', (0.35, 0.85, 0.55), roughness=0.4)
    power.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (0.35, 1.0, 0.6, 1)
    power.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 1.4
    rubber = kit.material('tv-rubber', (0.09, 0.10, 0.10), roughness=0.85)

    parts = [
        # Panel shell and the glass itself.
        kit.cube('tv-frame', (3.98, 0.14, 2.32), (0, 0, 1.74), mat=shell, bevel=0.025),
        kit.cube('tv-screen', (3.80, 0.02, 2.14), (0, -0.075, 1.74), mat=glass, bevel=0.006),
        # Thin lit edge: reads as a modern panel even at a distance.
        kit.cube('tv-edge-top', (3.98, 0.03, 0.03), (0, -0.07, 2.89), mat=edge),
        kit.cube('tv-edge-bottom', (3.98, 0.03, 0.03), (0, -0.07, 0.59), mat=edge),
        # Indicator lamps on the right of the bezel.
        kit.cube('tv-on-air', (0.16, 0.04, 0.05), (1.80, -0.085, 2.78), mat=on_air),
        kit.cube('tv-power', (0.06, 0.04, 0.05), (1.60, -0.085, 2.78), mat=power),
        # Soundbar under the panel.
        kit.cube('tv-soundbar', (3.20, 0.11, 0.13), (0, -0.05, 0.47), mat=edge, bevel=0.02),
        # Standing frame: two legs, feet and a brace, like a trade-show banner.
        kit.cube('tv-leg', (0.10, 0.10, 0.60), (-1.26, 0.02, 0.30), mat=shell, bevel=0.01),
        kit.cube('tv-leg', (0.10, 0.10, 0.60), (1.26, 0.02, 0.30), mat=shell, bevel=0.01),
        kit.cube('tv-foot', (0.54, 0.76, 0.07), (-1.26, 0.0, 0.035), mat=shell, bevel=0.015),
        kit.cube('tv-foot', (0.54, 0.76, 0.07), (1.26, 0.0, 0.035), mat=shell, bevel=0.015),
        kit.cube('tv-brace', (2.52, 0.06, 0.07), (0, 0.02, 0.16), mat=edge, bevel=0.008),
        # Back: vents and a service hatch so the panel reads from both sides.
        kit.cube('tv-back', (3.86, 0.05, 2.20), (0, 0.10, 1.74), mat=shell, bevel=0.012),
        kit.cube('tv-hatch', (0.70, 0.03, 0.46), (0.9, 0.135, 1.30), mat=edge, bevel=0.008),
    ]
    for index, z in enumerate((2.10, 2.02, 1.94)):
        parts.append(kit.cube('tv-vent', (2.10, 0.03, 0.02), (0.0, 0.135, z), mat=edge))
    # Cables dropping from the back of the panel to the floor.
    parts.append(kit.cylinder('tv-cable', 0.018, 1.10, (-1.52, 0.16, 0.62),
                              rotation=(math.radians(4), 0, math.radians(3)), mat=rubber,
                              vertices=8))
    parts.append(kit.cylinder('tv-cable', 0.014, 0.86, (-1.72, 0.20, 0.46),
                              rotation=(math.radians(2), 0, math.radians(-4)), mat=rubber,
                              vertices=8))
    kit.join('plasma_tv', parts)


PROPS = {
    'bed': bed,
    'toilet': toilet,
    'operating_table': operating_table,
    'pantry_shelf': pantry_shelf,
    'boulder': boulder,
    'chair': chair,
    'plasma_tv': plasma_tv,
}
