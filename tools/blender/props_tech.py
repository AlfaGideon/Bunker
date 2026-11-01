"""Interactive bunker stations: radio, galley, first-aid cabinet, terminal.

The look is deliberately "cinematic anime": chunky readable silhouettes built
from a few big shapes, strong two-tone colour blocking, one saturated emissive
accent per prop and no textures at all. Godot adds the ink outline on top (see
``BunkerArt.outline``), so the models themselves stay clean.

Emissive parts are deliberately dim in the Blender preview: a Principled BSDF
with a strong emission clips straight to white, and the whole point of the
accents is that they keep their hue (amber for the radio, cyan for the CRT).
"""
import math
import random

import kit

# Shared palette: one warm accent and one cold accent, everything else is a
# muted industrial tone so the emissive parts read from across the room.
STEEL = (0.30, 0.32, 0.33)
STEEL_DARK = (0.085, 0.10, 0.105)
BRASS = (0.55, 0.40, 0.16)
ENAMEL = (0.72, 0.74, 0.70)
RUST = (0.36, 0.17, 0.10)
AMBER = (1.0, 0.62, 0.22)
CYAN = (0.30, 0.92, 0.92)


def _glow(name: str, color, strength: float = 2.0):
    """Emissive material that keeps its hue instead of clipping to white."""
    tinted = tuple(component * 0.55 for component in color)
    return kit.material(name, tinted, roughness=0.35, emission=tinted,
                        emission_strength=strength)


def _brass(name: str = 'brass'):
    return kit.material(name, BRASS, roughness=0.28, metallic=0.9)


def radio_station() -> None:
    """The bunker receiver: twin speakers, a glowing dial and a whip antenna."""
    shell = kit.material('radio-shell', (0.20, 0.26, 0.22), roughness=0.55)
    trim = _brass('radio-trim')
    dark = kit.material('radio-dark', STEEL_DARK, roughness=0.6, metallic=0.3)
    glow = _glow('radio-glass', AMBER, 2.2)
    cap = kit.material('radio-cone', (0.46, 0.47, 0.42), roughness=0.65)

    parts = [kit.cube('body', (0.54, 0.28, 0.34), (0, 0, 0.19), mat=shell,
                      bevel=0.03, segments=3),
             kit.cube('plinth', (0.58, 0.32, 0.045), (0, 0, 0.028), mat=dark,
                      bevel=0.012)]
    # Two speaker wells: a brass rim, a dark cone and a pale dust cap. The
    # rings are what make the box read as "big sound" from across the room.
    for side in (-1, 1):
        x = side * 0.14
        parts.append(kit.torus('speaker-rim', 0.088, 0.011, (x, -0.143, 0.205),
                               rotation=(math.pi / 2, 0, 0), mat=trim,
                               major_segments=26))
        parts.append(kit.cylinder('speaker-cone', 0.082, 0.03, (x, -0.14, 0.205),
                                  rotation=(math.pi / 2, 0, 0), mat=dark,
                                  vertices=26, bevel=0.006))
        parts.append(kit.sphere('speaker-cap', 0.040, (x, -0.158, 0.205),
                                scale=(1, 0.5, 1), mat=cap))
    # Dial plate with an amber window and a brass needle.
    parts.append(kit.cube('dial-plate', (0.50, 0.024, 0.078), (0, -0.146, 0.318),
                          mat=dark, bevel=0.008))
    parts.append(kit.cube('dial-glass', (0.44, 0.01, 0.05), (0, -0.158, 0.318),
                          mat=glow, bevel=0.004))
    parts.append(kit.cube('needle', (0.006, 0.02, 0.062), (0.085, -0.166, 0.318),
                          mat=trim))
    # Knobs with visible pointer marks.
    for x in (-0.185, 0.0, 0.185):
        parts.append(kit.cylinder('knob', 0.038, 0.028, (x, -0.152, 0.075),
                                  rotation=(math.pi / 2, 0, 0), mat=trim,
                                  vertices=20, bevel=0.005))
        parts.append(kit.cube('knob-mark', (0.007, 0.012, 0.026),
                              (x, -0.166, 0.095), mat=dark))
    # Power lamp and carry handle.
    parts.append(kit.cylinder('power-lamp', 0.012, 0.014, (0.235, -0.15, 0.318),
                              rotation=(math.pi / 2, 0, 0), mat=_glow(
                                  'radio-lamp', (0.35, 1.0, 0.55), 2.4),
                              vertices=12))
    parts.append(kit.torus('handle', 0.10, 0.012, (0, 0.02, 0.40),
                           rotation=(0, math.pi / 2, 0), mat=trim,
                           major_segments=20))
    # Whip antenna, leaning back like an old receiver.
    parts.append(kit.cylinder('antenna', 0.007, 0.55, (-0.22, 0.10, 0.55),
                              rotation=(math.radians(-14), 0, math.radians(4)),
                              mat=trim, vertices=10))
    parts.append(kit.sphere('antenna-tip', 0.017, (-0.255, 0.135, 0.815),
                            mat=trim))
    for side in (-1, 1):
        parts.append(kit.cube('foot', (0.07, 0.06, 0.018), (side * 0.24, 0.10, 0.008),
                              mat=dark, bevel=0.004))
    kit.join('radio-station', parts)


def food_station() -> None:
    """Galley counter: a heavy pot on a glowing burner, bowls, ladle, tins."""
    iron = kit.material('pot-iron', (0.14, 0.145, 0.15), roughness=0.42, metallic=0.6)
    iron_worn = kit.material('pot-rim', (0.26, 0.24, 0.21), roughness=0.55, metallic=0.4)
    fire = _glow('burner-glow', (1.0, 0.45, 0.12), 3.0)
    enamel = kit.material('bowl-enamel', ENAMEL, roughness=0.45)
    soup = kit.material('bowl-soup', (0.60, 0.44, 0.24), roughness=0.85)
    tin = kit.material('ration-tin', (0.34, 0.38, 0.28), roughness=0.5, metallic=0.35)
    label = kit.material('ration-label', (0.66, 0.17, 0.12), roughness=0.7)
    cabinet = kit.material('galley-cabinet', (0.20, 0.24, 0.25), roughness=0.55)
    top = kit.material('galley-top', (0.52, 0.55, 0.53), roughness=0.35, metallic=0.5)
    trim = _brass('galley-trim')
    steam = kit.material('steam', (0.90, 0.92, 0.90), roughness=0.95,
                         emission=(0.5, 0.5, 0.5), emission_strength=0.25)

    width, depth, height = 1.0, 0.50, 0.88
    parts = [kit.cube('cabinet', (width - 0.06, depth - 0.06, height - 0.10),
                      (0, 0, (height - 0.10) / 2), mat=cabinet, bevel=0.02,
                      segments=2),
             kit.cube('counter', (width, depth, 0.06), (0, 0, height - 0.03),
                      mat=top, bevel=0.012, segments=2),
             kit.cube('kick', (width - 0.12, 0.02, 0.10), (0, -depth / 2 + 0.02, 0.05),
                      mat=iron, bevel=0.006)]
    # Two brass drawer fronts read as a real galley unit.
    for z, size_z in ((0.62, 0.20), (0.38, 0.20)):
        parts.append(kit.cube('drawer', (width - 0.14, 0.02, size_z),
                              (0, -depth / 2 + 0.005, z), mat=iron_worn,
                              bevel=0.008))
        parts.append(kit.cube('drawer-pull', (width - 0.34, 0.02, 0.022),
                              (0, -depth / 2 - 0.012, z + 0.05), mat=trim,
                              bevel=0.006))
    # Burner: stepped drum with a hot slot ring under the pot.
    deck = height
    parts.append(kit.cylinder('burner-base', 0.21, 0.07, (0, 0, deck + 0.035),
                              mat=iron, vertices=24, bevel=0.012))
    parts.append(kit.cylinder('burner-ring', 0.175, 0.03, (0, 0, deck + 0.082),
                              mat=iron_worn, vertices=24, bevel=0.008))
    parts.append(kit.torus('burner-flame', 0.155, 0.015, (0, 0, deck + 0.098),
                           mat=fire, major_segments=28))
    for index in range(8):
        angle = index * math.tau / 8
        parts.append(kit.cube('burner-slot', (0.016, 0.045, 0.016),
                              (math.cos(angle) * 0.19, math.sin(angle) * 0.19,
                               deck + 0.045),
                              rotation=(0, 0, angle), mat=fire))
    # Pot: barrel, rim, lid, knob and two side ears.
    pot_bottom = deck + 0.10
    parts.append(kit.cylinder('pot', 0.165, 0.20, (0, 0, pot_bottom + 0.10),
                              mat=iron, vertices=28, bevel=0.016))
    parts.append(kit.torus('pot-rim', 0.165, 0.011, (0, 0, pot_bottom + 0.198),
                           mat=iron_worn, major_segments=28))
    # Open pot: a visible soup surface is what sells "hot food is ready".
    parts.append(kit.cylinder('soup', 0.152, 0.02, (0, 0, pot_bottom + 0.20),
                              mat=soup, vertices=28))
    parts.append(kit.cylinder('stew-chunk', 0.03, 0.03, (0.05, 0.03, pot_bottom + 0.212),
                              mat=kit.material('stew-chunk', (0.70, 0.50, 0.22),
                                               roughness=0.9), vertices=10))
    for side in (-1, 1):
        parts.append(kit.torus('pot-ear', 0.042, 0.009,
                               (side * 0.168, 0, pot_bottom + 0.155),
                               rotation=(0, math.pi / 2, 0), mat=iron_worn,
                               major_segments=16))
    # Ladle standing in the pot, leaning out over the front rim.
    parts.append(kit.cylinder('ladle-handle', 0.011, 0.36, (0.10, -0.12, deck + 0.30),
                              rotation=(math.radians(20), 0, math.radians(-35)),
                              mat=iron_worn, vertices=10))
    parts.append(kit.sphere('ladle-bowl', 0.045, (0.10, -0.09, pot_bottom + 0.17),
                            scale=(1, 1, 0.6), mat=iron_worn))
    # Bowls with soup on the left of the counter.
    for x, y in ((-0.36, -0.13), (-0.15, -0.20)):
        parts.append(kit.cylinder('bowl', 0.078, 0.05, (x, y, deck + 0.025),
                                  mat=enamel, vertices=22, bevel=0.014))
        parts.append(kit.torus('bowl-rim', 0.072, 0.011, (x, y, deck + 0.05),
                               mat=enamel, major_segments=22))
        parts.append(kit.cylinder('bowl-soup', 0.062, 0.016, (x, y, deck + 0.048),
                                  mat=soup, vertices=22))
    # Ration tins on the right.
    for index in range(3):
        x = 0.30 + (index % 2) * 0.10
        y = -0.14 + (index // 2) * 0.16
        parts.append(kit.cylinder('tin', 0.043, 0.085, (x, y, deck + 0.042),
                                  mat=tin, vertices=16, bevel=0.006))
        parts.append(kit.cylinder('tin-label', 0.045, 0.032, (x, y, deck + 0.052),
                                  mat=label, vertices=16))
    # Stylised steam: three pale puffs, the cheapest way to say "hot food".
    for dx, dz, radius, lift in ((-0.05, 0.02, 0.072, 0.06),
                                 (0.06, -0.02, 0.052, 0.16),
                                 (0.14, 0.04, 0.036, 0.25)):
        parts.append(kit.sphere('steam', radius,
                                (dx, dz, pot_bottom + 0.22 + lift),
                                scale=(1, 1, 0.72), mat=steam))
    kit.join('food-station', parts)


def medkit() -> None:
    """Wall cabinet with the door swung open: red cross, bottles, warm inside."""
    parts = []
    case = kit.material('medkit-case', (0.78, 0.80, 0.78), roughness=0.42)
    back = kit.material('medkit-back', (0.34, 0.37, 0.36), roughness=0.8)
    red = kit.material('medkit-cross', (0.74, 0.10, 0.10), roughness=0.5,
                       emission=(0.42, 0.03, 0.03), emission_strength=1.0)
    latch = _brass('medkit-latch')
    bottle_colors = [(0.75, 0.35, 0.16), (0.30, 0.55, 0.72), (0.60, 0.66, 0.42),
                     (0.80, 0.72, 0.30)]

    width, depth, height = 0.50, 0.16, 0.58
    half_w, half_d = width / 2, depth / 2
    # A real open box: five panels, no boolean, so the shelves are visible.
    parts.append(kit.cube('back', (width, 0.02, height), (0, half_d - 0.01, height / 2),
                          mat=back, bevel=0.004))
    for side in (-1, 1):
        parts.append(kit.cube('side', (0.022, depth, height),
                              (side * (half_w - 0.011), 0, height / 2),
                              mat=case, bevel=0.01, segments=3))
    parts.append(kit.cube('top', (width, depth, 0.022), (0, 0, height - 0.011),
                          mat=case, bevel=0.01))
    parts.append(kit.cube('bottom', (width, depth, 0.022), (0, 0, 0.011),
                          mat=case, bevel=0.01))
    # Warm strip light under the top panel.
    parts.append(kit.cube('inner-light', (width - 0.12, 0.06, 0.016),
                          (0, -0.02, height - 0.032), mat=_glow(
                              'medkit-light', (1.0, 0.80, 0.45), 1.8),
                          bevel=0.004))
    # Shelves with tinted bottles.
    rng = random.Random(4)
    for shelf_index, z in enumerate((0.13, 0.28, 0.43)):
        parts.append(kit.cube('shelf', (width - 0.06, depth - 0.04, 0.012),
                              (0, 0, z), mat=latch, bevel=0.003))
        for bottle_index in range(3):
            x = -0.14 + bottle_index * 0.13
            tint = bottle_colors[(shelf_index + bottle_index) % len(bottle_colors)]
            h = rng.uniform(0.055, 0.085)
            parts.append(kit.cylinder('bottle', 0.024, h, (x, 0.0, z + 0.008 + h / 2),
                                      mat=kit.material(
                                          'bottle-%d' % ((shelf_index + bottle_index) % 4),
                                          tint, roughness=0.22),
                                      vertices=12, bevel=0.004))
            parts.append(kit.cylinder('bottle-cap', 0.012, 0.014,
                                      (x, 0.0, z + 0.016 + h), mat=latch,
                                      vertices=10))
    # Door hung on the left stile, swung open towards the room (-Y is out).
    hinge = (-half_w + 0.012, -half_d + 0.012)
    angle = math.radians(-100.0)
    door_w, door_h = 0.46, height - 0.05
    door_at = (hinge[0] + math.cos(angle) * door_w / 2,
               hinge[1] + math.sin(angle) * door_w / 2, height / 2)
    normal = (math.sin(angle), -math.cos(angle))
    parts.append(kit.cube('door', (door_w, 0.022, door_h), door_at,
                          rotation=(0, 0, angle), mat=case, bevel=0.012,
                          segments=3))
    cross_at = (door_at[0] + normal[0] * 0.013, door_at[1] + normal[1] * 0.013,
                height / 2 + 0.075)
    parts.append(kit.cube('cross-v', (0.07, 0.014, 0.22), cross_at,
                          rotation=(0, 0, angle), mat=red, bevel=0.004))
    parts.append(kit.cube('cross-h', (0.20, 0.014, 0.07), cross_at,
                          rotation=(0, 0, angle), mat=red, bevel=0.004))
    handle_at = (door_at[0] + normal[0] * 0.026 + math.cos(angle) * 0.15,
                 door_at[1] + normal[1] * 0.026 + math.sin(angle) * 0.15,
                 height / 2 - 0.20)
    parts.append(kit.cube('latch', (0.06, 0.022, 0.018), handle_at,
                          rotation=(0, 0, angle), mat=latch, bevel=0.005))
    # Cross baked on the outer side panel too: with the door swung open the
    # front cross turns away from half the room, this one never does.
    side_at = (half_w + 0.004, 0, height * 0.56)
    parts.append(kit.cube('cross-side-v', (0.012, 0.07, 0.22), side_at,
                          mat=red, bevel=0.003))
    parts.append(kit.cube('cross-side-h', (0.012, 0.20, 0.07), side_at,
                          mat=red, bevel=0.003))
    # Wall brackets so it does not float on the wall.
    for side in (-1, 1):
        parts.append(kit.cube('bracket', (0.05, 0.05, 0.14),
                              (side * (half_w - 0.06), half_d + 0.02, height - 0.09),
                              mat=latch, bevel=0.006))
    kit.join('medkit', parts)


def terminal() -> None:
    """Console: chunky CRT with a cyan screen, scan lines, key slab and vents."""
    parts = []
    shell = kit.material('terminal-shell', (0.24, 0.27, 0.26), roughness=0.5)
    dark = kit.material('terminal-dark', STEEL_DARK, roughness=0.45, metallic=0.4)
    bezel = _brass('terminal-bezel')
    screen = _glow('terminal-screen', (0.18, 0.72, 0.76), 1.7)
    scan = _glow('terminal-scan', CYAN, 3.2)
    keys = kit.material('terminal-keys', (0.66, 0.64, 0.56), roughness=0.55)
    led = _glow('terminal-led', AMBER, 2.6)

    desk_top = 0.58
    parts.append(kit.cube('pedestal', (0.70, 0.40, desk_top - 0.06),
                          (0, 0.02, (desk_top - 0.06) / 2), mat=dark,
                          bevel=0.014, segments=2))
    parts.append(kit.cube('desk', (0.80, 0.44, 0.06), (0, 0, desk_top),
                          mat=shell, bevel=0.012))
    for index in range(3):
        parts.append(kit.cube('vent-slot', (0.26, 0.02, 0.014),
                              (-0.14, -0.195, 0.16 + index * 0.09), mat=shell,
                              bevel=0.003))
    parts.append(kit.cube('hatch', (0.18, 0.02, 0.20), (0.20, -0.195, 0.30),
                          mat=shell, bevel=0.008))
    parts.append(kit.cube('hatch-pull', (0.06, 0.02, 0.02), (0.20, -0.207, 0.38),
                          mat=bezel, bevel=0.004))
    # Key slab, framed so the keys stay inside the plate.
    parts.append(kit.cube('key-plate', (0.52, 0.20, 0.03), (0, -0.10, desk_top + 0.04),
                          mat=dark, bevel=0.008))
    for row in range(3):
        for column in range(9):
            parts.append(kit.cube('key', (0.038, 0.034, 0.018),
                                  (-0.20 + column * 0.05, -0.05 - row * 0.05,
                                   desk_top + 0.062),
                                  mat=keys, bevel=0.004))
    # CRT body, tilted back a little, with a brass bezel ring.
    tilt = math.radians(-7)
    crt_z = desk_top + 0.05
    parts.append(kit.cube('crt', (0.62, 0.34, 0.36), (0, 0.10, crt_z + 0.20),
                          rotation=(tilt, 0, 0), mat=shell, bevel=0.026,
                          segments=3))
    parts.append(kit.cube('bezel', (0.54, 0.03, 0.33), (0, -0.075, crt_z + 0.20),
                          rotation=(tilt, 0, 0), mat=bezel, bevel=0.01))
    parts.append(kit.cube('screen', (0.42, 0.014, 0.23), (0, -0.090, crt_z + 0.205),
                          rotation=(tilt, 0, 0), mat=screen, bevel=0.006))
    # Scan lines and a cursor bar: the "cinematic" tell of a live terminal.
    for index in range(5):
        parts.append(kit.cube('scan-line', (0.36 - index * 0.022, 0.006, 0.008),
                              (0.02, -0.097, crt_z + 0.29 - index * 0.042),
                              rotation=(tilt, 0, 0), mat=scan, bevel=0.002))
    parts.append(kit.cube('cursor', (0.05, 0.006, 0.022), (0.155, -0.097, crt_z + 0.10),
                          rotation=(tilt, 0, 0), mat=scan, bevel=0.002))
    # Status LEDs on the bezel and cooling vents on both flanks.
    for index, color in enumerate([(0.95, 0.25, 0.20), (0.35, 0.95, 0.45),
                                   (1.0, 0.70, 0.25)]):
        parts.append(kit.cylinder('led', 0.011, 0.012,
                                  (-0.16 + index * 0.05, -0.095, crt_z + 0.055),
                                  rotation=(math.pi / 2, 0, 0),
                                  mat=_glow('terminal-led-%d' % index, color, 2.4),
                                  vertices=10))
    for side in (-1, 1):
        for index in range(4):
            parts.append(kit.cube('vent', (0.02, 0.18, 0.014),
                                  (side * 0.315, 0.12, crt_z + 0.10 + index * 0.045),
                                  mat=dark, bevel=0.003))
    kit.join('terminal', parts)


PROPS = {
    'radio_station': radio_station,
    'food_station': food_station,
    'medkit': medkit,
    'terminal': terminal,
}
