"""Prepare editable Ranger clips from production game samples, in a work copy."""
import bpy, json, math
from pathlib import Path
from mathutils import Matrix, Vector

folder = Path(__file__).resolve().parent
data = json.loads((folder / 'game_pose_samples.json').read_text())
rig = bpy.data.objects['Reference_Rig']
scene = bpy.context.scene
c = Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
ci = c.inverted()
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
control = rig.data.edit_bones.new('Bow_Control')
control.head = (0,0,0)
control.tail = (0,.35,0)
control.use_deform = False
bpy.ops.object.mode_set(mode='OBJECT')
weapon = bpy.data.objects['Weapon_Cutlass']
weapon.parent = None
weapon.matrix_parent_inverse = Matrix.Identity(4)
weapon.matrix_basis = Matrix.Identity(4)
constraint = weapon.constraints.new('COPY_TRANSFORMS')
constraint.name = 'Follow editable bow control'
constraint.target = rig
constraint.subtarget = 'Bow_Control'
rig.show_in_front = True
rig.data.display_type = 'STICK'
rig.animation_data_create()
rest = {n: rig.data.bones[n].matrix_local.copy() for n in data['bones']}
for pb in rig.pose.bones:pb.rotation_mode = 'QUATERNION'
manifest = []
for clip in data['clips']:
    action = bpy.data.actions.new(clip['name'])
    action.use_fake_user = True
    rig.animation_data.action = action
    step = 18 if 'Idle' in clip['name'] else (2 if 'Run' in clip['name'] else 3)
    keys = set(range(0,len(clip['frames']),step)) | {len(clip['frames'])-1}
    keys |= {int(v)-1 for v in clip['markers'].values()}
    previous = {}
    for f in sorted(keys):
        scene.frame_set(f+1)
        sample = clip['frames'][f]
        desired = {}
        for name, pose in zip(data['bones'],sample['bones']):
            mat = (ci @ Matrix(pose['delta']) @ c) @ rest[name]
            mat.translation = (ci @ Vector((*pose['position'],1))).xyz
            desired[name] = mat
            parent = rig.data.bones[name].parent
            rig.pose.bones[name].matrix_basis = (rest[name].inverted() @ rest[parent.name] @ desired[parent.name].inverted() @ mat) if parent else rest[name].inverted() @ mat
        rig.pose.bones['Bow_Control'].matrix = ci @ Matrix(sample['bow']) @ c
        bpy.context.view_layer.update()
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in previous and q.dot(previous[pb.name]) < 0:q.negate()
            pb.rotation_quaternion = q
            previous[pb.name] = q.copy()
            for prop in ('location','rotation_quaternion','scale'):
                pb.keyframe_insert(data_path=prop,frame=f+1,group=pb.name)
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = len(clip['frames'])
    for label,frame in clip['markers'].items():action.pose_markers.new(label).frame = frame
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:key.interpolation = 'LINEAR'
    action['notes'] = 'Current Ranger game poses, editable in place. Jump is a representative velocity preview; game physics owns travel.'
    action.asset_mark()
    action.asset_data.description = action['notes']
    manifest.append({'action':action.name,'start':1,'end':len(clip['frames']),'keyframes':sorted(f+1 for f in keys),'markers':clip['markers']})

scene.render.fps = 60
scene.tool_settings.use_keyframe_insert_auto = False
guide = '''RANGER — KEY POSE WORKBENCH

Current game animations are already prepared: 01_Idle (1–217),
02_Run (1–41), and 03_Jump (1–91). All three actions are in every file.
The separate Idle/Run/Jump files open on that clip with its playback range.

Start with Idle, frame 1. Select bones in either character view.
R rotates; X/Y/Z chooses an axis; Return confirms. I records a pose.
Space plays/pauses; Command-S saves this work copy.
Bow_Control controls the bow. Arm and forearm bones use FK rotation.
Edit bones rather than Skin, Costume, or weapon geometry.

Provide your important poses and their frame numbers. Codex can preserve
those poses, connect the frames between them, match loop ends, and tune
timing. Existing intermediate keys may need replacing after your poses
are approved. Saving a Blender file alone does not change the game.

Run markers: 1 / 11 / 21 / 31 / 41.
Jump markers: ready 1, takeoff 10, rising 25, apex 43, falling 61,
landing 76, settle 91. Jump stays in place for editing; the game owns
the actual jump height and distance. This is a representative preview
of the current regular jump, not Ranger's special aerial attacks.
'''
bpy.data.texts.new('START_HERE — Ranger Pose Guide').write(guide)
(folder/'START_HERE.txt').write_text(guide)
(folder/'actions.json').write_text(json.dumps(manifest,indent=2)+'\n')
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        views = sorted([a for a in screen.areas if a.type=='VIEW_3D'],key=lambda a:a.x)
        for idx,area in enumerate(views):
            space = area.spaces.active
            space.shading.type = 'SOLID'
            space.shading.color_type = 'TEXTURE'
            space.overlay.show_extras = False
            space.overlay.show_floor = False
            space.overlay.show_axis_x = False
            space.overlay.show_axis_y = False
            space.show_region_ui = False
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_location = Vector((0,0,1.3))
            space.region_3d.view_distance = 5.5 if idx==0 else 5.2
            direction = Vector((0,1,-.12)) if idx==0 else Vector((-1,1,-.25))
            space.region_3d.view_rotation = direction.to_track_quat('-Z','Y')
        for area in screen.areas:
            if area.type=='DOPESHEET_EDITOR':
                area.spaces.active.mode = 'ACTION'
                area.spaces.active.dopesheet.show_only_selected = False
                area.spaces.active.show_pose_markers = True
            if area.type=='PROPERTIES':area.spaces.active.context = 'OBJECT'
for bone in rig.pose.bones:bone.select = False
rig.pose.bones['Chest'].select = True
rig.data.bones.active = rig.data.bones['Chest']
bpy.ops.object.mode_set(mode='POSE')
if bpy.context.window:bpy.context.window.workspace = bpy.data.workspaces['Animation']
bpy.ops.file.pack_all()
for meta,filename in zip(manifest,['Ranger_Idle.blend','Ranger_Run.blend','Ranger_Jump.blend']):
    action = bpy.data.actions[meta['action']]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    scene.frame_start = 1
    scene.frame_end = meta['end']
    scene.frame_set(1)
    scene.timeline_markers.clear()
    for label,frame in meta['markers'].items():scene.timeline_markers.new(label,frame=frame)
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/filename))
action = bpy.data.actions['01_Idle']
rig.animation_data.action = action
rig.animation_data.action_slot = action.slots[0]
scene.frame_end = 217
scene.frame_set(1)
scene.timeline_markers.clear()
for label,frame in manifest[0]['markers'].items():scene.timeline_markers.new(label,frame=frame)
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Ranger_Animation_Workbench.blend'))
print('RANGER_WORKBENCH_OK',len(manifest))
