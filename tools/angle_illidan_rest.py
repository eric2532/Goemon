"""Apply the requested screen-space resting arm angles in the saved animation."""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT.parent / "Warcraft/assets/Illidan/Illidan.blend"
bpy.ops.wm.open_mainfile(filepath=str(MASTER))
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
assert not rig.get("goemon_rest_angles"), "Preserve subsequent authored arm poses"
before = hashlib.sha256(MASTER.read_bytes()).hexdigest()
view = Matrix.Rotation(math.radians(105), 3, 'X') @ Matrix.Rotation(math.pi / 2, 3, 'Y') @ Matrix.Rotation(-math.pi / 2, 3, 'X')
axis = rig.matrix_world.to_3x3().inverted() @ view.inverted() @ Vector((0, 0, 1))
names = {"Bone_Arm1_L Alternate": 30, "Bone_Arm1_R Alternate": -30}
idle = bpy.data.actions["Stand Alternate"]
cast = bpy.data.actions["Attack Alternate"]


def select(action):
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]


def write(action, samples):
    bag = action.layers[0].strips[0].channelbag(action.slots[0])
    paths = {rig.pose.bones[name].path_from_id("rotation_quaternion") for name in names}
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


select(idle)
bpy.context.scene.frame_set(0)
old = {name: rig.pose.bones[name].rotation_quaternion.copy() for name in names}
samples = []
for frame in range(int(idle.frame_end) + 1):
    bpy.context.scene.frame_set(frame)
    poses = {}
    for name, angle in names.items():
        bone = rig.pose.bones[name]
        original = bone.matrix.copy()
        desired = Quaternion(axis, math.radians(angle)).to_matrix().to_4x4() @ original
        desired.translation = original.translation
        basis = bone.bone.convert_local_to_pose(desired, bone.bone.matrix_local,
            parent_matrix=bone.parent.matrix, parent_matrix_local=bone.parent.bone.matrix_local, invert=True)
        poses[name] = basis.to_quaternion()
        assert abs(original.to_quaternion().rotation_difference(desired.to_quaternion()).angle - math.radians(30)) < .0001
    samples.append(poses)
offsets = {name: samples[0][name] @ old[name].inverted() for name in names}
write(idle, samples)
select(cast)
samples = []
last = int(cast.frame_end)
for frame in range(last + 1):
    bpy.context.scene.frame_set(frame)
    rise = max(0, min(1, frame / 5))
    fall = max(0, min(1, (frame - 14) / (last - 14)))
    strength = rise * rise * (3 - 2 * rise) * (1 - fall * fall * (3 - 2 * fall))
    samples.append({name: Quaternion().slerp(offsets[name], 1 - strength) @ rig.pose.bones[name].rotation_quaternion
                    for name in names})
write(cast, samples)
select(idle)
bpy.context.scene.frame_set(0)
rig["goemon_rest_angles"] = "Left +30 / right -30 degrees in the 105-degree FPS resting view; zero at release"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
(ROOT / "build/Other Files/Asset Toolkit/Illidan Hands/rest-angles.json").write_text(json.dumps({
    "before_sha256": before, "after_sha256": hashlib.sha256(MASTER.read_bytes()).hexdigest(),
    "screen_degrees": {"left_counterclockwise": 30, "right_clockwise": 30},
    "release_frame": 8, "release_offset_degrees": 0
}, indent=2) + "\n")
print("ILLIDAN_REST_ANGLES_RESULT: left counterclockwise 30; right clockwise 30; cast release unchanged")
