"""Ordino cannon model (Faz 7, docs/04 §1: "Top (cannon) 3D mesh").

Red lacquer + gold trim cannon like docs/referans/02, in two parts that match
src/gameplay/cannon/cannon.tscn:
  Carriage  - cheeks, axle, wheels: turns with the Yaw node
  Barrel    - tapered barrel, gold rings, trunnions, cascabel: pitches with the Pitch node
The origin is the trunnion axis (= the Pitch pivot). The barrel points forward; its muzzle face is
MUZZLE_DIST in front of the pivot (= the Muzzle marker, so the ball leaves the barrel tip).

Blender is Z-up and the glTF exporter turns it into Y-up: Blender +Y (forward) becomes Godot -Z,
Blender +Z becomes Godot +Y.

Run (headless):
  blender -b --python tools/blender/make_cannon.py -- assets/models/cannon/cannon.glb
"""
import math
import sys

import bpy

MUZZLE_DIST = 1.2          # = Muzzle marker distance in cannon.tscn
BREECH = -0.55             # back end of the barrel (behind the pivot)
R_BREECH = 0.30
R_MUZZLE = 0.24
RED = (0.42, 0.025, 0.02, 1.0)
GOLD = (0.95, 0.62, 0.16, 1.0)
DARK = (0.05, 0.03, 0.03, 1.0)
SEGMENTS = 48


def material(name, color, metallic, roughness, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    return m


def finish(obj, mat, smooth=True, bevel=0.0):
    obj.data.materials.append(mat)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    return obj


def cylinder_y(name, r1, r2, y0, y1, mat, z=0.0, x=0.0, verts=SEGMENTS):
    """Cone/cylinder along +Y from y0 to y1."""
    depth = y1 - y0
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth,
                                    location=(x, y0 + depth / 2.0, z), rotation=(-math.pi / 2.0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    return finish(o, mat)


def cylinder_x(name, r, x0, x1, mat, y=0.0, z=0.0, verts=SEGMENTS):
    depth = x1 - x0
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth,
                                        location=(x0 + depth / 2.0, y, z), rotation=(0, math.pi / 2.0, 0))
    o = bpy.context.active_object
    o.name = name
    return finish(o, mat)


def ring_y(name, r, thickness, y, mat):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thickness, location=(0, y, 0),
                                     rotation=(math.pi / 2.0, 0, 0), major_segments=SEGMENTS, minor_segments=12)
    o = bpy.context.active_object
    o.name = name
    return finish(o, mat)


def box(name, size, loc, mat, bevel=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.name = name
    return finish(o, mat, smooth=False, bevel=bevel)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def wheel(side, red, gold):
    x = side * 0.52
    parts = [cylinder_x("wheel", 0.36, x - 0.07, x + 0.07, red),
             cylinder_x("hub", 0.10, x - 0.10, x + 0.10, gold)]
    rim = bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.035, location=(x, 0, 0),
                                           rotation=(0, math.pi / 2.0, 0), major_segments=SEGMENTS, minor_segments=10)
    parts.append(finish(bpy.context.active_object, gold))
    for i in range(6):
        a = i * math.pi / 3.0
        spoke = box("spoke", (0.05, 0.05, 0.62), (x, 0, 0), gold, bevel=0.0)
        spoke.rotation_euler = (a, 0, 0)
        bpy.ops.object.transform_apply(rotation=True)
        parts.append(spoke)
    return parts


def main():
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "cannon.glb"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    red = material("cannon_red", RED, 0.0, 0.32)
    # Low metallic: the canvas background gives no sky reflections, a fully metal gold renders black.
    gold = material("cannon_gold", GOLD, 0.35, 0.35)
    dark = material("cannon_bore", DARK, 0.0, 0.9)

    # Barrel (origin = trunnion axis, forward = +Y).
    barrel = [cylinder_y("tube", R_BREECH, R_MUZZLE, BREECH, MUZZLE_DIST - 0.05, red),
              cylinder_y("muzzle_flare", R_MUZZLE + 0.05, R_MUZZLE + 0.07, MUZZLE_DIST - 0.12, MUZZLE_DIST, gold),
              cylinder_y("bore", R_MUZZLE - 0.06, R_MUZZLE - 0.06, MUZZLE_DIST - 0.3, MUZZLE_DIST + 0.001, dark),
              ring_y("ring_breech", R_BREECH + 0.01, 0.04, BREECH + 0.05, gold),
              ring_y("ring_mid", (R_BREECH + R_MUZZLE) / 2.0 + 0.01, 0.035, 0.25, gold),
              ring_y("ring_front", R_MUZZLE + 0.025, 0.03, MUZZLE_DIST - 0.35, gold),
              cylinder_x("trunnions", 0.07, -R_BREECH - 0.12, R_BREECH + 0.12, gold)]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=(0, BREECH - 0.09, 0), segments=32, ring_count=16)
    barrel.append(finish(bpy.context.active_object, gold))
    barrel.append(cylinder_y("cascabel_neck", 0.05, 0.05, BREECH - 0.05, BREECH + 0.01, gold))
    # Gold crest on top (the fleur in the reference, simplified): a small ridge.
    barrel.append(box("crest", (0.06, 0.32, 0.06), (0, 0.05, R_BREECH - 0.01), gold, bevel=0.015))
    b = join(barrel, "Barrel")

    # Carriage (does not pitch): cheeks, axle, wheels. Below the pivot.
    carriage = [box("cheek_l", (0.12, 0.95, 0.42), (-0.38, -0.05, -0.18), red),
                box("cheek_r", (0.12, 0.95, 0.42), (0.38, -0.05, -0.18), red),
                box("transom", (0.64, 0.22, 0.14), (0, -0.40, -0.28), red),
                box("trim_l", (0.13, 0.96, 0.04), (-0.38, -0.05, 0.035), gold, bevel=0.01),
                box("trim_r", (0.13, 0.96, 0.04), (0.38, -0.05, 0.035), gold, bevel=0.01),
                cylinder_x("axle", 0.06, -0.62, 0.62, gold, y=-0.05, z=-0.36)]
    for side in (-1.0, 1.0):
        for p in wheel(side, red, gold):
            p.location.y += -0.05
            p.location.z += -0.36
            carriage.append(p)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    c = join(carriage, "Carriage")

    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True)
    print("CANNON_OK", out, len(b.data.polygons), len(c.data.polygons))


main()
