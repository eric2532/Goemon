"""One-time additive hand edit; run in Blender, then use the normal Warcraft exporter.

The pre-edit master is retained in Git at refs/codex/illidan-hand-source.
Subsequent sculpt/pose edits belong in Illidan.blend; never rerun over them.
"""
import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT.parent / "Warcraft/assets/Illidan/Illidan.blend"
REPORT = ROOT / "build/Other Files/Asset Toolkit/Illidan Hands"


def actions_digest():
    values = []
    for action in bpy.data.actions:
        values.append((action.name, action.frame_start, action.frame_end))
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        values.append((curve.data_path, curve.array_index,
                            [(tuple(p.co), tuple(p.handle_left), tuple(p.handle_right), p.interpolation)
                             for p in curve.keyframe_points]))
    return hashlib.sha256(repr(values).encode()).hexdigest()


def original_mesh(obj, vertices, faces):
    mesh = obj.data
    return ([tuple(v.co) for v in mesh.vertices[:vertices]],
            [[(g.group, g.weight) for g in v.groups] for v in mesh.vertices[:vertices]],
            [(tuple(p.vertices), p.material_index, p.use_smooth,
              [tuple(mesh.uv_layers.active.data[i].uv) for i in p.loop_indices])
             for p in mesh.polygons[:faces]])


bpy.ops.wm.open_mainfile(filepath=str(MASTER))
obj = bpy.data.objects["2 IllidanEvil"]
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
assert not obj.get("goemon_meta_fingers"), "Already authored: edit the saved master instead"
source_hash = hashlib.sha256(MASTER.read_bytes()).hexdigest()
vertex_count, face_count = len(obj.data.vertices), len(obj.data.polygons)
before = original_mesh(obj, vertex_count, face_count)
actions = actions_digest()
mesh = bmesh.new()
mesh.from_mesh(obj.data)
deform = mesh.verts.layers.deform.verify()
uv = mesh.loops.layers.uv.active
digits = []

for bone, mirror, texture_uv in [("hand Alternate", 1, (.49, .524)),
                                  ("hand01 Alternate", -1, (.09, .524))]:
    transform = obj.matrix_world.inverted() @ rig.matrix_world @ rig.data.bones[bone].matrix_local
    group = obj.vertex_groups[bone].index
    paths = []
    for z, length in [(-8.5, 16), (-2.8, 21), (3, 20), (8.5, 16.5)]:
        paths.append([(4, -12, z, 3.0), (3, -19, z * 1.15, 2.8),
                      (5, -12 - length * .78, z * 1.35, 2.0),
                      (10, -12 - length, z * 1.4, 0)])
    paths.append([(5, -5, 10, 3.8), (4, -10, 17, 3.2),
                  (6, -17, 21, 2.0), (11, -22, 21, 0)])
    for index, path in enumerate(paths):
        start = len(mesh.verts)
        rings = []
        for step, (x, y, z, radius) in enumerate(path):
            center = Vector((x, y, z * mirror))
            next_point = path[min(step + 1, len(path) - 1)]
            prev_point = path[max(0, step - 1)]
            tangent = Vector((next_point[0] - prev_point[0], next_point[1] - prev_point[1],
                              (next_point[2] - prev_point[2]) * mirror)).normalized()
            side = tangent.cross(Vector((1, 0, 0))).normalized()
            up = side.cross(tangent).normalized()
            ring = []
            for corner in range(6 if radius else 1):
                angle = corner * math.tau / 6
                point = center + radius * (side * math.cos(angle) + up * math.sin(angle))
                vertex = mesh.verts.new(transform @ point)
                vertex[deform][group] = 1.0
                ring.append(vertex)
            rings.append(ring)
        faces = []
        faces.append(mesh.faces.new(tuple(reversed(rings[0]))))
        for a, b in zip(rings, rings[1:]):
            for corner in range(6):
                vertices = (a[corner], a[(corner + 1) % 6], b[0]) if len(b) == 1 else (
                    a[corner], a[(corner + 1) % 6], b[(corner + 1) % 6], b[corner])
                faces.append(mesh.faces.new(vertices))
        bmesh.ops.recalc_face_normals(mesh, faces=faces)
        for face in faces:
            face.material_index = 0
            face.smooth = True
            for loop in face.loops:
                loop[uv].uv = texture_uv
        digits.append({"bone": bone, "digit": index, "vertices": [start, len(mesh.verts)]})

mesh.to_mesh(obj.data)
mesh.free()
obj.data.update()
assert original_mesh(obj, vertex_count, face_count) == before, "Original body/UVs/weights changed"
assert actions_digest() == actions, "Original animation changed"
assert len(digits) == 10 and len(obj.data.vertices) == vertex_count + 190
assert all(abs(sum(g.weight for g in v.groups) - 1) < 1e-6 for v in obj.data.vertices[vertex_count:])
obj["goemon_meta_fingers"] = json.dumps(digits)
obj["goemon_original_vertices"] = vertex_count
obj["goemon_original_faces"] = face_count
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
REPORT.mkdir(parents=True, exist_ok=True)
(REPORT / "source-edit.json").write_text(json.dumps({
    "master": str(MASTER), "before_sha256": source_hash,
    "before_git_ref": "refs/codex/illidan-hand-source",
    "after_sha256": hashlib.sha256(MASTER.read_bytes()).hexdigest(),
    "actions_sha256": actions, "original_vertices": vertex_count, "original_faces": face_count,
    "vertices": len(obj.data.vertices), "faces": len(obj.data.polygons), "digits": digits,
    "preserved": ["original vertices", "original faces", "UVs", "weights", "materials", "all actions"]
}, indent=2) + "\n")
print("ILLIDAN_FINGERS_RESULT: 10 digits; original geometry, UVs, weights and actions unchanged")
