"""Prepare editable Ninja clips from production game samples, in a work copy."""
import bpy, json, math
from pathlib import Path
from mathutils import Matrix, Vector

folder = Path(__file__).resolve().parent
if (folder/'Ninja_Animation_Workbench.blend').exists():
    raise RuntimeError('Workbench already exists; preserve the user poses and edit that file in place.')
bpy.ops.wm.open_mainfile(filepath=str(folder.parents[1]/'assets/blender/characters/goemon_cosplay/ninja.blend'))
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
for name, hand in [('Blade_Control','Hand_R'),('Offhand_Control','Hand_L')]:
    control = rig.data.edit_bones.new(name)
    control.head = rig.data.edit_bones[hand].head
    control.tail = control.head + Vector((0,-.25,0))
    control.parent = rig.data.edit_bones[hand]
    control.use_connect = False
    control.use_deform = False
bpy.ops.object.mode_set(mode='OBJECT')
for obj_name,control_name in [('Weapon_Cutlass','Blade_Control'),('Weapon_Pistol','Offhand_Control')]:
    weapon = bpy.data.objects[obj_name]
    weapon.parent = None
    weapon.matrix_parent_inverse = Matrix.Identity(4)
    weapon.matrix_basis = Matrix.Identity(4)
    constraint = weapon.constraints.new('COPY_TRANSFORMS')
    constraint.name = 'Follow editable blade control'
    constraint.target = rig
    constraint.subtarget = control_name
rig.show_in_front = True
rig.data.display_type = 'STICK'
for name in ['Blade_Control','Offhand_Control']:
    rig.data.bones[name].color.palette = 'THEME04'
rig.animation_data_create()
rest = {n: rig.data.bones[n].matrix_local.copy() for n in data['bones']}
for pb in rig.pose.bones:pb.rotation_mode = 'QUATERNION'
manifest = []
for clip in data['clips']:
    action = bpy.data.actions.new(clip['name'])
    action.use_fake_user = True
    rig.animation_data.action = action
    step = 18 if 'Idle' in clip['name'] else (5 if 'Run' in clip['name'] else 3)
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
        bpy.context.view_layer.update()
        rig.pose.bones['Blade_Control'].matrix = ci @ Matrix(sample['right_blade']) @ c
        rig.pose.bones['Offhand_Control'].matrix = ci @ Matrix(sample['left_blade']) @ c
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
    action['notes'] = 'Current Ninja game poses with the updated purple-handle blade, editable in place. RMB uses the current dash-cut with an editable recovery to idle. Game physics owns travel.'
    action.asset_mark()
    action.asset_data.description = action['notes']
    manifest.append({'action':action.name,'start':1,'end':len(clip['frames']),'keyframes':sorted(f+1 for f in keys),'markers':clip['markers']})

scene.render.fps = 60
scene.tool_settings.use_keyframe_insert_auto = False
guide = """NINJA — IDLE / RUN / RIGHT-CLICK POSE WORKBENCH

The updated curved silver blade with purple handle is attached to Ninja.
All three editable actions are in every file:
  01_Idle               frames 1–217 (loop)
  02_Run                frames 1–41  (loop)
  03_Cross_Slash_RMB     frames 1–37  (right click)

Ninja_Idle.blend, Ninja_Run.blend and Ninja_Cross_Slash_RMB.blend each open
on their action with the appropriate playback range. The main workbench
opens on Idle. Choose actions in the bottom Action Editor dropdown.

Select arm/forearm/hand/chest bones in Pose Mode. R rotates; G moves;
X/Y/Z constrains the axis. I records the pose; Space plays; Command-S saves.
Auto Key is off so playback cannot overwrite a pose accidentally.
Blade_Control is a child of Hand_R: the blade follows your arm and hand edits.
Offhand_Control follows Hand_L. Rotate those controls to adjust the grip.
Do not reshape Skin/Hair or edit rest bones in Edit Mode.

Useful run poses: frame 1 contact A, 11 passing A, 21 contact B,
31 passing B, 41 loop. Match the first and last frame for a seamless loop.
Right-click poses: ready 1, windup 6, cut 10, follow-through 18,
end of dash 26, recovery 37. The strike starts from the current Ninja
right-click dash-cut (0.42 seconds); the extra recovery is editable.
The character stays in place so the pose is easy to see. The game owns dash travel.

Save your edits and keep track of the important pose frames. These files
are independent work copies. Saving here does not publish animation changes
to the game; the live source, rig and body remain separate.
"""
bpy.data.texts.new('START_HERE — Ninja Pose Guide').write(guide)
(folder/'START_HERE.txt').write_text(guide)
(folder/'actions.json').write_text(json.dumps(manifest,indent=2)+'\n')
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        views = sorted([a for a in screen.areas if a.type=='VIEW_3D'],key=lambda a:a.x)
        for idx,area in enumerate(views):
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.shading.use_scene_world = False
            space.shading.use_scene_lights = False
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
for meta,filename in zip(manifest,['Ninja_Idle.blend','Ninja_Run.blend','Ninja_Cross_Slash_RMB.blend']):
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
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'Ninja_Animation_Workbench.blend'))
print('NINJA_WORKBENCH_OK',len(manifest))
