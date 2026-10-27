"""Author the meta left-wrist correction into the two existing casting clips."""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT.parent / "Warcraft/assets/Illidan/Illidan.blend"
OUT = ROOT / "build/Other Files/Asset Toolkit/Illidan Hands"
bpy.ops.wm.open_mainfile(filepath=str(MASTER))
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
obj = bpy.data.objects["2 IllidanEvil"]
assert obj.get("goemon_meta_fingers") and not rig.get("goemon_meta_wrist_corrected")
before = hashlib.sha256(MASTER.read_bytes()).hexdigest()
bone = rig.pose.bones["Bone_Hand_L Alternate"]
path = bone.path_from_id("rotation_quaternion")
clips = ["Stand Alternate", "Attack Alternate"]


def untouched_curves():
    values = []
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        if action.name in clips and curve.data_path == path:
                            continue
                        values.append((action.name, curve.data_path, curve.array_index,
                                       [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation)
                                        for k in curve.keyframe_points]))
    return hashlib.sha256(repr(values).encode()).hexdigest()


preserved = untouched_curves()
report = {}
for name in clips:
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    samples = []
    original_max = 0
    for frame in range(int(action.frame_end) + 1):
        bpy.context.scene.frame_set(frame)
        hand = rig.pose.bones["hand Alternate"]
        elbow = rig.pose.bones["forearm Alternate"]
        forearm = (hand.matrix.translation - elbow.matrix.translation).normalized()
        palm = (hand.matrix.to_3x3() @ Vector((0, -1, 0))).normalized()
        angle = palm.angle(forearm)
        original_max = max(original_max, math.degrees(angle))
        correction = Quaternion(palm.cross(forearm).normalized(), max(0, angle - math.radians(15)))
        desired = correction.to_matrix().to_4x4() @ bone.matrix
        desired.translation = bone.matrix.translation
        basis = bone.bone.convert_local_to_pose(desired, bone.bone.matrix_local,
            parent_matrix=bone.parent.matrix, parent_matrix_local=bone.parent.bone.matrix_local, invert=True)
        rotation = basis.to_quaternion()
        if samples and samples[-1].dot(rotation) < 0:
            rotation.negate()
        samples.append(rotation)
    bag = action.layers[0].strips[0].channelbag(action.slots[0])
    for curve in list(bag.fcurves):
        if curve.data_path == path:
            bag.fcurves.remove(curve)
    for frame, rotation in enumerate(samples):
        bone.rotation_quaternion = rotation
        bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone.name)
    for curve in bag.fcurves:
        if curve.data_path == path:
            for key in curve.keyframe_points:
                key.interpolation = "LINEAR"
    maximum = 0
    for frame in range(int(action.frame_end) + 1):
        bpy.context.scene.frame_set(frame)
        h = rig.pose.bones["hand Alternate"].matrix
        e = rig.pose.bones["forearm Alternate"].matrix.translation
        angle = math.degrees((h.translation - e).angle(h.to_3x3() @ Vector((0, -1, 0))))
        maximum = max(maximum, angle)
    assert maximum < 16, (name, maximum)
    report[name] = {"before_max_degrees": original_max, "after_max_degrees": maximum}

assert untouched_curves() == preserved, "An unrelated animation track changed"
# Narrow the two thumbs' hooked tips without changing their roots or bindings.
for digit in json.loads(obj["goemon_meta_fingers"]):
    if digit["digit"] != 4:
        continue
    hand = rig.data.bones[digit["bone"]]
    transform = obj.matrix_world.inverted() @ rig.matrix_world @ hand.matrix_local
    inverse = transform.inverted()
    sign = 1 if digit["bone"] == "hand Alternate" else -1
    start, end = digit["vertices"]
    for i in range(start + 12, end):
        p = inverse @ obj.data.vertices[i].co
        p.z -= 3.5 * sign
        p.x -= 2
        obj.data.vertices[i].co = transform @ p
obj.data.update()
rig["goemon_meta_wrist_corrected"] = True
rig.animation_data.action = bpy.data.actions["Stand"]
rig.animation_data.action_slot = rig.animation_data.action.slots[0]
bpy.context.scene.frame_set(0)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
report.update({"before_sha256": before, "after_sha256": hashlib.sha256(MASTER.read_bytes()).hexdigest(),
               "other_animation_curves_sha256": preserved})
(OUT / "wrist-edit.json").write_text(json.dumps(report, indent=2) + "\n")
print("ILLIDAN_WRIST_RESULT", report)
