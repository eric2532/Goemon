"""Build an editable run from the user's exact two stride designs.

Run against Goemon_Run_Source_Design.blend. All output stays in this practice
directory; the game's character, model exports, and scripts are untouched.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

OUT = Path(__file__).resolve().parent
rig = bpy.data.objects['Reference_Rig']
scene = bpy.context.scene
source_action = rig.animation_data.action
assert source_action.name == 'Run', source_action.name
source_action.use_fake_user = True

def snapshot(frame):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    return {
        b.name: {
            'location': b.location.copy(),
            'rotation': b.matrix_basis.to_quaternion(),
            'scale': b.scale.copy(),
            'matrix': b.matrix.copy(),
            'head': b.head.copy(), 'tail': b.tail.copy(),
        } for b in rig.pose.bones
    }

anchors = [snapshot(0), snapshot(30)]
skin = bpy.data.objects['Skin']
foot_local = {}
for side in ('L', 'R'):
    name = 'Foot_' + side
    group_index = skin.vertex_groups[name].index
    indices = [v.index for v in skin.data.vertices
               if any(g.group == group_index and g.weight > .99 for g in v.groups)]
    assert indices, name
    # Capture actual deformed shoe vertices relative to the posed ankle.
    scene.frame_set(0)
    bpy.context.view_layer.update()
    evaluated = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    to_bone = anchors[0][name]['matrix'].inverted() @ rig.matrix_world.inverted() @ skin.matrix_world
    foot_local[side] = [to_bone @ mesh.vertices[i].co for i in indices]
    evaluated.to_mesh_clear()

def shoe_low(matrix, side):
    return min((matrix @ point).z for point in foot_local[side])

ground = min(shoe_low(anchors[0]['Foot_L']['matrix'], 'L'),
             shoe_low(anchors[1]['Foot_R']['matrix'], 'R'))

def blend(a, b, t):
    return a + (b - a) * t

def smooth(t):
    t = max(0., min(1., t))
    return t * t * (3. - 2. * t)

def hermite(a, b, va, vb, t):
    return ((2*t**3 - 3*t*t + 1)*a + (t**3 - 2*t*t + t)*va
            + (-2*t**3 + 3*t*t)*b + (t**3-t*t)*vb)

def foot_path(side, phase):
    # The left foot is the planted foot in the first user pose. Labels in the
    # timeline retain the user's first/right-stride, second/left-stride naming.
    q = (phase + (0. if side == 'L' else .5)) % 1.
    front = anchors[0 if side == 'L' else 1]['Foot_' + side]
    rear = anchors[1 if side == 'L' else 0]['Foot_' + side]
    a, b = front['head'], rear['head']
    if q <= .30:
        t = q / .30
        y = blend(a.y, b.y + .32, t)
        rotation = front['matrix'].to_quaternion()
        clearance = .015 * smooth(max(0., (t - .65) / .35))
        x = blend(a.x, b.x, .30 * t)
        z = ground - min((rotation @ v).z for v in foot_local[side]) + clearance
    elif q <= .5:
        t = (q - .30) / .20
        y = hermite(b.y + .32, b.y, (b.y + .32 - a.y)*(.20/.30), 0., t)
        rotation = front['matrix'].to_quaternion().slerp(rear['matrix'].to_quaternion(), smooth(t))
        start_rotation = front['matrix'].to_quaternion()
        start_z = ground - min((start_rotation @ v).z for v in foot_local[side]) + .015
        z = blend(start_z, b.z, smooth(t))
        x = blend(blend(a.x, b.x, .30), b.x, smooth(t))
    else:
        t = (q - .5) / .5
        # Heel recovery, knee passing, then a controlled forward landing.
        y = hermite(b.y, a.y, 0., (b.y + .32 - a.y)*(.5/.30), t)
        z = blend(b.z, a.z, smooth(t)) + .14 * math.sin(math.pi*t)**2
        x = blend(b.x, a.x, smooth(t))
        rotation = rear['matrix'].to_quaternion().slerp(front['matrix'].to_quaternion(), smooth(t))
    # The toe projects well below the ankle while pitching out of push-off.
    # Clear the actual shoe sole throughout flight, not just the ankle joint.
    if q > .30:
        z = max(z, ground - min((rotation @ v).z for v in foot_local[side])
                + .025 * math.sin(math.pi*(q-.30)/.70)**2)
    return Vector((x, y, z)), rotation, q

def solve_leg(side, goal, foot_rotation, phase):
    upper, lower, foot = [rig.pose.bones[prefix + '_' + side]
                          for prefix in ('Leg', 'Shin', 'Foot')]
    old_upper, old_lower = upper.matrix.copy(), lower.matrix.copy()
    hip, old_knee = upper.head.copy(), lower.head.copy()
    old_ankle = foot.head.copy()
    upper_length = (old_knee - hip).length
    lower_length = (old_ankle - old_knee).length
    line = goal - hip
    length = max(.01, line.length)
    direction = line.normalized()
    distance = min(length, upper_length + lower_length - .001)
    # Interpolate the user's bend-plane normals. Projecting an FK knee against
    # an unrelated IK ankle can cross the limb axis and flip the knee abruptly.
    normals = []
    for anchor in anchors:
        a = anchor['Leg_' + side]['head']
        b = anchor['Shin_' + side]['head']
        c = anchor['Foot_' + side]['head']
        normals.append((b-a).cross(c-b).normalized())
    normal = normals[0].lerp(normals[1], .5-.5*math.cos(phase*math.tau)).normalized()
    pole = direction.cross(normal)
    if pole.length < .0001:
        pole = Vector((0, 1, 0))
        pole -= direction * pole.dot(direction)
    pole.normalize()
    along = (upper_length**2 + distance**2 - lower_length**2)/(2*distance)
    height = math.sqrt(max(0., upper_length**2 - along**2))
    knee = hip + direction*along + pole*height
    ankle = hip + direction*distance
    old_upper_direction = (old_knee - hip).normalized()
    old_lower_direction = (old_ankle - old_knee).normalized()
    upper_rotation = old_upper_direction.rotation_difference((knee-hip).normalized())
    lower_rotation = old_lower_direction.rotation_difference((ankle-knee).normalized())
    upper.matrix = Matrix.Translation(hip) @ upper_rotation.to_matrix().to_4x4() @ old_upper.to_3x3().to_4x4()
    bpy.context.view_layer.update()
    lower.matrix = Matrix.Translation(knee) @ lower_rotation.to_matrix().to_4x4() @ old_lower.to_3x3().to_4x4()
    bpy.context.view_layer.update()
    foot.matrix = Matrix.LocRotScale(ankle, foot_rotation, Vector((1,1,1)))
    return max(0., length - distance)

action = bpy.data.actions.new('Run_User_Strides')
action.use_fake_user = True
rig.animation_data.action = action
for track in rig.animation_data.nla_tracks:
    track.mute = True
reach_errors = []
for frame in range(61):
    scene.frame_set(frame)
    phase = frame / 60.
    weight = .5 - .5 * math.cos(phase * math.tau)
    for bone in rig.pose.bones:
        first, second = anchors[0][bone.name], anchors[1][bone.name]
        bone.rotation_mode = 'QUATERNION'
        bone.location = first['location'].lerp(second['location'], weight)
        bone.rotation_quaternion = first['rotation'].slerp(second['rotation'], weight)
        bone.scale = first['scale'].lerp(second['scale'], weight)
    # Two slight rises per complete stride. The actual user anchors stay exact.
    bpy.context.view_layer.update()
    root_matrix = rig.pose.bones['Root'].matrix.copy()
    root_matrix.translation.z += .080 * math.sin(phase * math.tau)**2
    rig.pose.bones['Root'].matrix = root_matrix
    bpy.context.view_layer.update()
    if frame not in (0, 30, 60):
        for side in ('L', 'R'):
            goal, rotation, _ = foot_path(side, phase)
            reach_errors.append(solve_leg(side, goal, rotation, phase))
            bpy.context.view_layer.update()
    for bone in rig.pose.bones:
        for prop in ('location', 'rotation_quaternion', 'scale'):
            bone.keyframe_insert(data_path=prop, frame=frame, group=bone.name)

for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:
                    key.interpolation = 'LINEAR'
                curve.modifiers.new('CYCLES')
action.use_frame_range = True
action.frame_start = 0
action.frame_end = 60
scene.render.fps = 90
scene.frame_start = 0
scene.frame_end = 59  # Frame 60 duplicates 0; don't pause on it during playback.
for marker in list(scene.timeline_markers):
    scene.timeline_markers.remove(marker)
for frame, label in [(0, 'RIGHT STRIDE - YOUR POSE'), (15, 'PASSING'),
                     (30, 'LEFT STRIDE - YOUR POSE'), (45, 'PASSING'), (60, 'LOOP')]:
    scene.timeline_markers.new(label, frame=frame)

# Verify anchor preservation, actual shoe clearance, motion, and loop continuity.
frames = [snapshot(frame) for frame in range(61)]
anchor_error = max(abs(frames[f][name]['matrix'][i][j] - anchors[k][name]['matrix'][i][j])
                   for f,k in ((0,0),(30,1),(60,0)) for name in anchors[0]
                   for i in range(4) for j in range(4))
loop_error = max(abs(frames[0][name]['matrix'][i][j] - frames[60][name]['matrix'][i][j])
                 for name in anchors[0] for i in range(4) for j in range(4))
lowest_shoe = min(shoe_low(pose['Foot_' + side]['matrix'], side)
                  for pose in frames for side in ('L','R'))
max_head_step = max((frames[f][name]['head'] - frames[f-1][name]['head']).length
                    for f in range(1,61) for name in anchors[0])
report = {'action': action.name, 'baked_frames': 61, 'fps': scene.render.fps,
          'loop_seconds': 60 / scene.render.fps, 'anchor_error': anchor_error,
          'loop_error': loop_error, 'source_ground': ground,
          'lowest_shoe': lowest_shoe, 'max_head_step': max_head_step,
          'max_unreachable_distance': max(reach_errors),
          'source_action': source_action.name}
diagnostics = {'steps': sorted([(round((frames[f][name]['head'] - frames[f-1][name]['head']).length,5),f,name) for f in range(1,61) for name in anchors[0]], reverse=True)[:25],
               'feet': [{'f': f, 'L': list(p['Foot_L']['head']), 'R': list(p['Foot_R']['head']), 'lowL': shoe_low(p['Foot_L']['matrix'],'L'), 'lowR': shoe_low(p['Foot_R']['matrix'],'R')} for f,p in enumerate(frames)]}
(OUT / 'run_diagnostics.json').write_text(json.dumps(diagnostics, indent=2))
assert anchor_error < .0001, report
assert loop_error < .0001, report
assert lowest_shoe > ground - .025, report
assert max_head_step < .22, report
(OUT / 'run_animation_verification.json').write_text(json.dumps(report, indent=2))

# Show clean side and front three-quarter views, retaining editable rig overlays.
for screen in bpy.data.screens:
    views = [area for area in screen.areas if area.type == 'VIEW_3D']
    for index, area in enumerate(views):
        space = area.spaces.active
        space.shading.type = 'SOLID'
        space.shading.color_type = 'TEXTURE'
        space.region_3d.view_location = Vector((0,.15,.95))
        space.region_3d.view_distance = 4.3
        space.region_3d.view_perspective = 'ORTHO'
        eye = Vector((1,0,0)) if index == 0 else Vector((3,5,1.5))
        space.region_3d.view_rotation = (-eye).to_track_quat('-Z','Y')
        space.overlay.show_overlays = index != 0
    for area in screen.areas:
        if area.type == 'CONSOLE':
            area.type = 'DOPESHEET_EDITOR'
        if area.type == 'DOPESHEET_EDITOR':
            for space in area.spaces:
                if space.type == 'DOPESHEET_EDITOR':
                    space.mode = 'ACTION'
                    space.dopesheet.show_only_selected = False
for bone in rig.pose.bones:
    bone.select = False
scene.frame_set(0)
bpy.context.view_layer.update()
note = bpy.data.texts.new('RUN ANIMATION - user stride design')
note.write('Run_User_Strides is a 60-frame loop built from your exact poses at 0 and 30.\n'
           'Frame 60 matches 0. Playback ends at 59 to avoid showing the duplicate twice.\n'
           'Every frame is editable. Passing phases are around 15 and 45.\n'
           'Run retains the original two held pose designs.\n'
           'This is a separate practice asset; no live gameplay animation has changed.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'Goemon_Run_Animated.blend'))
print('RUN_ANIMATION_VERIFIED', json.dumps(report))
