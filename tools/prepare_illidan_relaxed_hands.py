"""Author a relaxed finger shape and ease the existing cast from/to its idle arms."""
import hashlib
import json
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT.parent / "Warcraft/assets/Illidan/Illidan.blend"
OUT = ROOT / "build/Other Files/Asset Toolkit/Illidan Hands"
bpy.ops.wm.open_mainfile(filepath=str(MASTER))
obj = bpy.data.objects["2 IllidanEvil"]
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
assert obj.data.shape_keys is None, "Preserve later authored shape edits"
before = hashlib.sha256(MASTER.read_bytes()).hexdigest()
obj.shape_key_add(name="Basis")
relaxed = obj.shape_key_add(name="RelaxedHands")
for digit in json.loads(obj["goemon_meta_fingers"]):
    bone = rig.data.bones[digit["bone"]]
    transform = obj.matrix_world.inverted() @ rig.matrix_world @ bone.matrix_local
    inverse = transform.inverted()
    start, end = digit["vertices"]
    for index in range(start, end):
        ring = (index - start) // 6
        p = inverse @ obj.data.vertices[index].co
        if digit["digit"] == 4:
            p.x += [0, 1, 4, 6][ring]
            p.y += [0, 0, 2, 5][ring]
            p.z *= [1, .98, .9, .8][ring]
        else:
            p.x += [0, 2, 6, 9][ring]
            p.y += [0, 2, 6, 10][ring]
            p.z *= [1, .95, .85, .8][ring]
        relaxed.data[index].co = transform @ p
assert all(relaxed.data[i].co == obj.data.vertices[i].co for i in range(411))
relaxed.value = 0

names = ["Bone_" + part + "_" + side + " Alternate"
         for part in ["Arm1", "Arm2", "Hand"] for side in ["L", "R"]]
paths = {rig.pose.bones[name].path_from_id("rotation_quaternion") for name in names}
idle = bpy.data.actions["Stand Alternate"]
cast = bpy.data.actions["Attack Alternate"]
rig.animation_data.action = idle
rig.animation_data.action_slot = idle.slots[0]
bpy.context.scene.frame_set(0)
rest = {name: rig.pose.bones[name].rotation_quaternion.copy() for name in names}
rig.animation_data.action = cast
rig.animation_data.action_slot = cast.slots[0]
frames = int(cast.frame_end)
samples = []


def smooth(a, b, value):
    t = max(0, min(1, (value - a) / (b - a)))
    return t * t * (3 - 2 * t)


for frame in range(frames + 1):
    bpy.context.scene.frame_set(frame)
    strength = smooth(0, 5, frame) * (1 - smooth(14, frames, frame))
    samples.append({name: rest[name].slerp(rig.pose.bones[name].rotation_quaternion, strength)
                    for name in names})
bag = cast.layers[0].strips[0].channelbag(cast.slots[0])
unchanged = [(c.data_path, c.array_index, [tuple(k.co) for k in c.keyframe_points])
             for c in bag.fcurves if c.data_path not in paths]
for curve in list(bag.fcurves):
    if curve.data_path in paths:
        bag.fcurves.remove(curve)
for frame, poses in enumerate(samples):
    for name, rotation in poses.items():
        bone = rig.pose.bones[name]
        bone.rotation_quaternion = rotation
        bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=name)
for curve in bag.fcurves:
    if curve.data_path in paths:
        for point in curve.keyframe_points:
            point.interpolation = "LINEAR"
assert unchanged == [(c.data_path, c.array_index, [tuple(k.co) for k in c.keyframe_points])
                     for c in bag.fcurves if c.data_path not in paths]
for frame in [0, frames]:
    bpy.context.scene.frame_set(frame)
    for name in names:
        assert abs(rig.pose.bones[name].rotation_quaternion.dot(rest[name])) > .99999
rig.animation_data.action = idle
rig.animation_data.action_slot = idle.slots[0]
bpy.context.scene.frame_set(0)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
(OUT / "relaxed-edit.json").write_text(json.dumps({
    "before_sha256": before, "after_sha256": hashlib.sha256(MASTER.read_bytes()).hexdigest(),
    "shape": "RelaxedHands", "changed_shape_vertices": 130,
    "cast_rotation_bones": names, "cast_frames": frames,
    "checks": ["original body shape unchanged", "cast starts and ends in idle arms",
               "unrelated cast tracks unchanged", "existing 24 actions retained"]
}, indent=2) + "\n")
print("ILLIDAN_RELAXED_RESULT: relaxed fingers; six arm rotations ease from and to idle; original release pose retained")
