"""Sample the approved Blender run without changing the character masters.
Blender --background docs/run-pose-practice/Goemon_Run_Animated.blend --python tools/export_user_run.py
"""
import bpy
import json
from pathlib import Path
from mathutils import Matrix

root = Path(__file__).resolve().parents[1]
rig = bpy.data.objects['Reference_Rig']
action = bpy.data.actions['Run_User_Strides']
rig.animation_data.action = action
rig.animation_data.action_slot = action.slots[0]
for track in rig.animation_data.nla_tracks:
    track.mute = True
# Canonical world vectors: Blender +Y forward / +Z up -> Godot -Z / +Y.
c = Matrix(((1,0,0),(0,0,1),(0,-1,0)))
names = [bone.name for bone in rig.data.bones]
frames = []
shoe_floor = float("inf")
skin = bpy.data.objects["Skin"]
foot_groups = {skin.vertex_groups[name].index for name in ("Foot_L", "Foot_R")}
shoe_vertices = [v.index for v in skin.data.vertices if any(g.group in foot_groups and g.weight > .99 for g in v.groups)]
for frame in range(61):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    samples = []
    for name in names:
        bone = rig.pose.bones[name]
        origin = c @ bone.head
        delta = c @ (bone.matrix.to_3x3() @ bone.bone.matrix_local.to_3x3().inverted()) @ c.inverted()
        q = delta.to_quaternion()
        samples.append([*origin, q.x,q.y,q.z,q.w, *delta.to_scale()])
    frames.append(samples)
    evaluated = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    to_rig = rig.matrix_world.inverted() @ skin.matrix_world
    shoe_floor = min(shoe_floor, min((to_rig @ mesh.vertices[i].co).z for i in shoe_vertices))
    evaluated.to_mesh_clear()
# Frame 60 is the interpolation seam, not an extra displayed frame.
# Later edits can leave the old endpoint behind; close the runtime loop on 0.
frames[60] = frames[0]
output = root / 'assets/animations/goemon_edo_run.json'
output.write_text(json.dumps({'source':'docs/run-pose-practice/Goemon_Run_Animated.blend','action':action.name,'fps':90,'period_frames':60,'floor_offset':-shoe_floor,'bones':names,'frames':frames},separators=(',',':'))+'\n')
print('USER_RUN_EXPORTED', output, 'frames',len(frames),'bones',len(names))
print('ANCHOR',frames[0][names.index('Foot_L')],frames[0][names.index('Foot_R')])
