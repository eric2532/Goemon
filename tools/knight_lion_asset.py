"""Blender: --python tools/knight_lion_asset.py [-- --create].

--create makes a new editable variant; ordinary runs export saved artist edits.
The Iwa master, rig and animation curves are never written.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/blender/vfx/knight_lion/energy_lion.blend"
DONOR = ROOT / "assets/blender/dogs/iwa.blend"
OUTPUT = ROOT / "assets/vfx/knight_lion/energy_lion.glb"


def motion_digest(rig):
    samples = []
    for track in rig.animation_data.nla_tracks:
        action = track.strips[0].action
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        samples.append([action.name, curve.data_path, curve.array_index,
                                        [(list(k.co), k.interpolation) for k in curve.keyframe_points]])
    return hashlib.sha256(json.dumps(samples, sort_keys=True).encode()).hexdigest()


def create():
    if SOURCE.exists():
        raise RuntimeError("Editable lion already exists; export without --create to preserve edits")
    bpy.ops.wm.open_mainfile(filepath=str(DONOR))
    rig = bpy.data.objects["DogRig"]
    body = bpy.data.objects["Iwa_Skinned"]
    original_motion = motion_digest(rig)
    for obj in list(bpy.data.objects):
        if obj not in (rig, body):
            bpy.data.objects.remove(obj, do_unlink=True)
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    bpy.context.scene.frame_set(0)
    for bone in rig.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    # Keep the existing weighted anatomy; this spirit has no companion equipment.
    mesh = bmesh.new()
    mesh.from_mesh(body.data)
    bmesh.ops.delete(mesh, geom=[f for f in mesh.faces if f.material_index >= 2], context="FACES")
    mesh.to_mesh(body.data)
    mesh.free()
    for vertex in body.data.vertices:
        if vertex.co.x > 1.18 and vertex.co.z > 1.25:
            vertex.co.x = 1.18 + (vertex.co.x - 1.18) * .64
            vertex.co.y *= 1.15
    body.name = "EnergyLion_Skinned"
    colors = body.data.color_attributes.get("DogColor")
    original_colors = [tuple(item.color) for item in colors.data]
    for poly in body.data.polygons:
        for index in poly.loop_indices:
            color_index = body.data.loops[index].vertex_index if colors.domain == "POINT" else index
            old = original_colors[color_index]
            colors.data[color_index].color = (.02, .035, .06, 1) if poly.material_index == 1 and sum(old[:3]) < .25 else (.35, .65, 1, 1)
    material = bpy.data.materials.new("Shield blue spirit")
    material.diffuse_color = (.18, .5, 1, 1)
    material.use_nodes = True
    vertex_color = material.node_tree.nodes.new("ShaderNodeVertexColor")
    vertex_color.layer_name = "DogColor"
    material.node_tree.links.new(vertex_color.outputs["Color"], material.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    body.data.materials.clear()
    body.data.materials.append(material)
    for poly in body.data.polygons:
        poly.material_index = 0
    parts = [body]

    def tuft(name, points, radii, bone, color=(.24, .52, .9, 1), sides=7):
        vertices, faces = [], []
        for i, point in enumerate(points):
            point = Vector(point)
            tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(0, i - 1)])
            axis = tangent.normalized()
            u = axis.cross(Vector((0, 1, 0)))
            if u.length < .01:
                u = axis.cross(Vector((0, 0, 1)))
            u.normalize()
            v = axis.cross(u)
            for j in range(sides):
                angle = j * math.tau / sides
                vertices.append(point + radii[i] * (u * math.cos(angle) + v * math.sin(angle)))
        faces.append(tuple(reversed(range(sides))))
        for i in range(len(points) - 1):
            for j in range(sides):
                a = i * sides + j
                b = i * sides + (j + 1) % sides
                faces.append((a, b, b + sides, a + sides))
        faces.append(tuple(range((len(points) - 1) * sides, len(points) * sides)))
        data = bpy.data.meshes.new(name)
        data.from_pydata(vertices, [], faces)
        data.materials.append(material)
        attribute = data.color_attributes.new(name="DogColor", type="FLOAT_COLOR", domain=colors.domain)
        for item in attribute.data:
            item.color = color
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.parent = rig
        obj.vertex_groups.new(name=bone).add(list(range(len(vertices))), 1, "REPLACE")
        parts.append(obj)

    # Swept, layered mane and curved horns take their silhouette from the reference.
    for row, count in [(0, 18), (1, 14)]:
        for i in range(count):
            angle = (i + .35 * row) * math.tau / count
            y, z = math.cos(angle), math.sin(angle)
            x = .99 - row * .35
            tuft("Swept mane", [(x, y * .29, 1.57 + z * .29),
                                (x - .18, y * .46, 1.57 + z * .44),
                                (x - .65, y * .60, 1.57 + z * .56),
                                (x - 1.25, y * .48, 1.57 + z * .39)],
                 [.085, .12, .065, .003], "head" if row == 0 else "neck")
    for side in [-1, 1]:
        tuft("Royal horn", [(1.03, side * .25, 1.89), (.92, side * .32, 2.16),
                            (.63, side * .36, 2.37), (.29, side * .32, 2.38)],
             [.12, .095, .05, .003], "head", (.8, .88, 1, 1), 10)
        tuft("Fang", [(1.47, side * .12, 1.52), (1.49, side * .12, 1.34)],
             [.042, .002], "head", (.9, .9, .7, 1))
    tip = rig.data.bones["tail2"].tail_local
    for i in range(7):
        angle = i * math.tau / 7
        offset = Vector((0, math.cos(angle), math.sin(angle))) * .13
        tuft("Tail flame", [tip - Vector((.20, 0, 0)), tip + offset, tip + Vector((-.48, 0, .12))],
             [.08, .12, .003], "tail2")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    assert motion_digest(rig) == original_motion, "Donor motion changed"
    rig["donor_motion_sha256"] = original_motion
    rig["donor_sha256"] = hashlib.sha256(DONOR.read_bytes()).hexdigest()
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.frame_end = 48
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)


if "--create" in sys.argv:
    create()
else:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig = bpy.data.objects["DogRig"]
assert hashlib.sha256(DONOR.read_bytes()).hexdigest() == rig["donor_sha256"]
assert motion_digest(rig) == rig["donor_motion_sha256"], "Recheck motion after intentional animation edits"
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = track.name != "run_loop"
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body = bpy.data.objects["EnergyLion_Skinned"]
body.select_set(True)
bpy.context.view_layer.objects.active = rig
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", use_selection=True,
                         export_yup=True, export_cameras=False, export_lights=False,
                         export_animations=True, export_animation_mode="NLA_TRACKS",
                         export_force_sampling=True, export_frame_range=False,
                         export_frame_step=1, export_def_bones=True, export_skins=True)
print("KNIGHT_LION_ASSET", json.dumps({"triangles": sum(len(p.vertices) - 2 for p in body.data.polygons),
                                     "surfaces": len(body.data.materials), "motion": motion_digest(rig)}))
