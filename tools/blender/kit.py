"""Shared helpers for the headless Blender asset kit.

Every prop here is modelled from primitives in code, so the assets stay
reproducible: no binary .blend is required, and the same script runs in the
Blender GUI, in CI and in the ``bpy`` Python module.

Units are metres, Z is up (Blender native). The glTF exporter converts to
Y-up for Godot.
"""
import math
import random

import bpy
from mathutils import Euler, Vector


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0


def material(name: str, color, roughness: float = 0.72, metallic: float = 0.0,
             emission=None, emission_strength: float = 4.0):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get('Principled BSDF')
    rgba = tuple(color) + (1.0,) if len(color) == 3 else tuple(color)
    bsdf.inputs['Base Color'].default_value = rgba
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    if emission is not None:
        bsdf.inputs['Emission Color'].default_value = tuple(emission) + (1.0,)
        bsdf.inputs['Emission Strength'].default_value = emission_strength
    return mat


def _finish(obj, mat, bevel: float = 0.0, segments: int = 2, smooth: bool = False):
    if mat is not None:
        obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new('bevel', 'BEVEL')
        modifier.width = bevel
        modifier.segments = segments
        modifier.limit_method = 'ANGLE'
        modifier.angle_limit = math.radians(35)
        with bpy.context.temp_override(object=obj):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def cube(name: str, size, location, rotation=(0, 0, 0), mat=None,
         bevel: float = 0.0, segments: int = 2):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location,
                                    rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat, bevel, segments)


def cylinder(name: str, radius: float, depth: float, location,
             rotation=(0, 0, 0), mat=None, vertices: int = 16,
             bevel: float = 0.0, cap: str = 'NGON'):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth,
                                        vertices=vertices, location=location,
                                        rotation=rotation,
                                        end_fill_type=cap)
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, mat, bevel)


def sphere(name: str, radius: float, location, scale=(1, 1, 1), mat=None,
           segments: int = 12, rings: int = 8, smooth: bool = True):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, subdivisions=2,
                                          location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, mat, 0.0, smooth=smooth)


def torus(name: str, major: float, minor: float, location,
          rotation=(0, 0, 0), mat=None, major_segments: int = 24):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=major_segments,
                                     minor_segments=8, location=location,
                                     rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, mat, 0.0, smooth=True)


def jitter(obj, amount: float, seed: int) -> None:
    """Break the perfect symmetry of a primitive so props read as handmade."""
    rng = random.Random(seed)
    for vertex in obj.data.vertices:
        vertex.co.x += rng.uniform(-amount, amount)
        vertex.co.y += rng.uniform(-amount, amount)
        vertex.co.z += rng.uniform(-amount, amount) * 0.6


def join(name: str, objects) -> None:
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    merged = bpy.context.object
    merged.name = name
    return merged


def export(path: str) -> None:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_skins=False,
        export_morph=False,
        export_texcoords=False,
        export_normals=True,
        export_materials='EXPORT',
        export_extras=False,
    )


def studio(target=(0, 0, 0.35), radius: float = 3.2,
           height: float = 1.9, angle: float = -0.9, resolution: int = 900,
           background=(0.055, 0.075, 0.09)) -> None:
    """Neutral three-light studio used for the documentation renders."""
    target = Vector(target)
    scene = bpy.context.scene
    world = bpy.data.worlds.new('studio') if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = tuple(background) + (1.0,)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9

    camera_data = bpy.data.cameras.new('camera')
    camera = bpy.data.objects.new('camera', camera_data)
    scene.collection.objects.link(camera)
    location = Vector((math.cos(angle) * radius, math.sin(angle) * radius, height))
    camera.location = location
    direction = target - location
    camera.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    camera_data.lens = 62
    scene.camera = camera

    key = bpy.data.lights.new('key', 'AREA')
    key.energy = 13
    key.size = 3.0
    key.color = (1.0, 0.86, 0.72)
    key_obj = bpy.data.objects.new('key', key)
    key_obj.location = (2.4, -2.6, 3.4)
    key_obj.rotation_euler = (Vector((0, 0, 0.4)) - Vector(key_obj.location)).to_track_quat('-Z', 'Y').to_euler()
    scene.collection.objects.link(key_obj)

    fill = bpy.data.lights.new('fill', 'AREA')
    fill.energy = 4.5
    fill.size = 4.0
    fill.color = (0.65, 0.78, 1.0)
    fill_obj = bpy.data.objects.new('fill', fill)
    fill_obj.location = (-3.2, -1.4, 2.2)
    fill_obj.rotation_euler = (Vector((0, 0, 0.3)) - Vector(fill_obj.location)).to_track_quat('-Z', 'Y').to_euler()
    scene.collection.objects.link(fill_obj)

    rim = bpy.data.lights.new('rim', 'AREA')
    rim.energy = 8
    rim.size = 2.0
    rim.color = (1.0, 0.62, 0.36)
    rim_obj = bpy.data.objects.new('rim', rim)
    rim_obj.location = (-1.2, 3.0, 2.0)
    rim_obj.rotation_euler = (Vector((0, 0, 0.4)) - Vector(rim_obj.location)).to_track_quat('-Z', 'Y').to_euler()
    scene.collection.objects.link(rim_obj)

    floor = cube('floor', (14, 14, 0.02), (0, 0, -0.01),
                 mat=material('preview-floor', (0.10, 0.12, 0.13), roughness=0.85))

    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'


def render(path: str) -> None:
    scene = bpy.context.scene
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
