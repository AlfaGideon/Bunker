"""Camp props: the fire pit, the supply crate and the field radio.

Each builder models one prop at real-world scale around the Z axis and returns
nothing; the caller exports the scene. Kept deliberately low-poly and slightly
irregular so the props sit next to the hand-finished KayKit and Quaternius
models instead of looking like primitives from Godot.
"""
import math
import random

import bpy
from mathutils import Euler, Vector
import bpy

import kit


def _stone_material():
    return kit.material('stone', (0.21, 0.22, 0.225), roughness=0.94)


def _char_material():
    return kit.material('charred', (0.035, 0.03, 0.026), roughness=0.96)


def _wood_material():
    return kit.material('firewood', (0.19, 0.115, 0.065), roughness=0.9)


def campfire() -> None:
    stones = _stone_material()
    rng = random.Random(11)
    ring = []
    for index in range(11):
        angle = index * math.tau / 11 + rng.uniform(-0.06, 0.06)
        radius = 0.58 + rng.uniform(-0.03, 0.05)
        stone = kit.sphere('stone', 1.0,
                           (math.cos(angle) * radius, math.sin(angle) * radius, 0.055),
                           scale=(rng.uniform(0.11, 0.16), rng.uniform(0.09, 0.13),
                                  rng.uniform(0.045, 0.065)),
                           mat=stones, smooth=False)
        kit.jitter(stone, 0.012, seed=index)
        stone.rotation_euler = Euler((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12),
                                      angle), 'XYZ')
        ring.append(stone)
    kit.join('stones', ring)

    ash = kit.cylinder('ash', 0.46, 0.07, (0, 0, 0.035), mat=kit.material(
        'ash', (0.105, 0.098, 0.092), roughness=0.98), vertices=20, bevel=0.02)
    kit.jitter(ash, 0.012, seed=7)

    logs = []
    charred = _char_material()
    wood = _wood_material()
    for index in range(6):
        angle = index * math.tau / 6 + 0.25
        length = rng.uniform(0.5, 0.72)
        tilt = rng.uniform(-0.30, 0.30)
        log = kit.cylinder('log', 0.055, length,
                           (math.cos(angle) * 0.12, math.sin(angle) * 0.12,
                            0.075 + index * 0.012),
                           rotation=(math.pi / 2 + tilt, 0, angle),
                           mat=wood, vertices=10)
        logs.append(log)
        # The burnt end of every log is a separate, darker cap.
        logs.append(kit.cylinder('char', 0.058, 0.10,
                                 (math.cos(angle) * (0.12 + math.cos(angle) * length / 2),
                                  math.sin(angle) * (0.12 + math.cos(angle) * length / 2),
                                  0.075 + index * 0.012),
                                 rotation=(math.pi / 2 + tilt, 0, angle),
                                 mat=charred, vertices=10))
    kit.join('logs', logs)

    embers = []
    glow = kit.material('ember', (0.9, 0.32, 0.07), roughness=0.6,
                        emission=(1.0, 0.42, 0.10), emission_strength=6.0)
    for index in range(22):
        angle = rng.uniform(0, math.tau)
        radius = rng.uniform(0.02, 0.34)
        embers.append(kit.sphere('ember', 1.0,
                                 (math.cos(angle) * radius, math.sin(angle) * radius,
                                  rng.uniform(0.05, 0.10)),
                                 scale=(rng.uniform(0.012, 0.030),
                                        rng.uniform(0.012, 0.030),
                                        rng.uniform(0.008, 0.016)),
                                 mat=glow, smooth=False))
    kit.join('embers', embers)

    iron = kit.material('iron', (0.14, 0.14, 0.15), roughness=0.42, metallic=0.85)
    legs = []
    for index in range(3):
        angle = index * math.tau / 3 + 0.4
        base = Vector((math.cos(angle) * 0.62, math.sin(angle) * 0.62, 0.0))
        top = Vector((0, 0, 1.02))
        middle = (base + top) / 2
        direction = top - base
        leg = kit.cylinder('leg', 0.017, direction.length, middle, mat=iron, vertices=8)
        leg.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
        legs.append(leg)
    legs.append(kit.torus('ring', 0.075, 0.012, (0, 0, 1.00), mat=iron))
    kit.join('tripod', legs)

    pot_mat = kit.material('pot', (0.17, 0.16, 0.15), roughness=0.45, metallic=0.55)
    body = kit.cylinder('pot', 0.105, 0.15, (0, 0, 0.70), mat=pot_mat, vertices=18,
                        bevel=0.012)
    lid = kit.cylinder('pot-lid', 0.088, 0.02, (0, 0, 0.786), mat=pot_mat, vertices=18,
                       bevel=0.006)
    knob = kit.sphere('pot-knob', 0.018, (0, 0, 0.802), mat=pot_mat)
    spout = kit.cylinder('spout', 0.019, 0.14, (0.10, 0.0, 0.745),
                         rotation=(0, math.radians(62), 0), mat=pot_mat, vertices=8)
    bail = kit.torus('pot-bail', 0.115, 0.007, (0, 0, 0.80),
                     rotation=(0, math.pi / 2, 0),
                     mat=kit.material('iron-handle', (0.12, 0.12, 0.13), roughness=0.5,
                                      metallic=0.8), major_segments=22)
    kit.join('kettle', [body, lid, knob, spout, bail])


def crate() -> None:
    plank = kit.material('crate-wood', (0.25, 0.165, 0.095), roughness=0.88)
    dark = kit.material('crate-wood-dark', (0.175, 0.115, 0.07), roughness=0.9)
    band = kit.material('crate-band', (0.20, 0.20, 0.21), roughness=0.5, metallic=0.7)

    width, depth, height = 0.72, 0.5, 0.42
    parts = []
    # Five slats per long side with real gaps, so light falls between them.
    for side in (-1, 1):
        for index in range(5):
            z = 0.045 + index * (height - 0.06) / 4
            parts.append(kit.cube('slat', (width - 0.04, 0.028, 0.062),
                                  (0, side * (depth / 2 - 0.014), z),
                                  mat=plank if index % 2 == 0 else dark, bevel=0.006))
    for side in (-1, 1):
        for index in range(4):
            z = 0.05 + index * (height - 0.07) / 3
            parts.append(kit.cube('end', (0.028, depth - 0.05, 0.068),
                                  (side * (width / 2 - 0.014), 0, z),
                                  mat=dark, bevel=0.006))
    parts.append(kit.cube('bottom', (width - 0.03, depth - 0.03, 0.03), (0, 0, 0.02),
                          mat=dark, bevel=0.006))
    for corner in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        parts.append(kit.cube('post', (0.055, 0.055, height),
                              (corner[0] * (width / 2 - 0.03), corner[1] * (depth / 2 - 0.03),
                               height / 2), mat=plank, bevel=0.008))
    for z in (0.075, height - 0.07):
        parts.append(kit.cube('band', (width + 0.005, depth + 0.005, 0.022),
                              (0, 0, z), mat=band, bevel=0.004))
    kit.join('crate', parts)


def radio() -> None:
    case = kit.material('radio-case', (0.16, 0.20, 0.155), roughness=0.62)
    plate = kit.material('radio-plate', (0.085, 0.095, 0.09), roughness=0.55)
    metal = kit.material('radio-metal', (0.34, 0.34, 0.325), roughness=0.35, metallic=0.8)
    glass = kit.material('radio-glass', (0.95, 0.72, 0.38), roughness=0.2,
                         emission=(1.0, 0.66, 0.28), emission_strength=2.4)

    parts = []
    parts.append(kit.cube('body', (0.46, 0.22, 0.30), (0, 0, 0.15), mat=case, bevel=0.022,
                          segments=3))
    parts.append(kit.cube('grille-back', (0.20, 0.012, 0.22), (-0.10, -0.112, 0.15),
                          mat=plate, bevel=0.004))
    for index in range(7):
        z = 0.055 + index * 0.031
        parts.append(kit.cube('grille', (0.185, 0.012, 0.011), (-0.10, -0.118, z),
                              mat=metal, bevel=0.002))
    parts.append(kit.cube('dial', (0.19, 0.012, 0.075), (0.115, -0.114, 0.215),
                          mat=glass, bevel=0.006))
    parts.append(kit.cube('dial-frame', (0.205, 0.014, 0.09), (0.115, -0.110, 0.215),
                          mat=plate, bevel=0.004))
    for index, x in enumerate((0.055, 0.175)):
        parts.append(kit.cylinder('knob', 0.026, 0.028, (x, -0.124, 0.075),
                                  rotation=(math.pi / 2, 0, 0), mat=metal, vertices=14))
        parts.append(kit.cylinder('knob-cap', 0.014, 0.032, (x, -0.126, 0.075),
                                  rotation=(math.pi / 2, 0, 0), mat=plate, vertices=12))
    # Carrying handle: a half torus flattened into an arch above the case.
    handle = kit.torus('handle', 0.085, 0.012, (0, 0, 0.325),
                       rotation=(0, math.pi / 2, 0), mat=metal, major_segments=20)
    handle.scale = Vector((1.0, 1.6, 1.0))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(handle)
    antenna = kit.cylinder('antenna', 0.006, 0.42, (0.19, 0.06, 0.45),
                           rotation=(math.radians(-14), math.radians(12), 0),
                           mat=metal, vertices=8)
    antenna_tip = kit.sphere('antenna-tip', 0.014, (0.235, 0.075, 0.655), mat=metal)
    parts.extend([antenna, antenna_tip])
    for side in (-1, 1):
        parts.append(kit.cube('foot', (0.05, 0.05, 0.02), (side * 0.19, 0.08, 0.008),
                              mat=plate, bevel=0.003))
    kit.join('radio', parts)


PROPS = {
    'campfire': campfire,
    'crate': crate,
    'radio': radio,
}
