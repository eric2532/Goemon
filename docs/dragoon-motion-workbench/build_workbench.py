"""Build an isolated, editable pose workbook from captured production poses.
Blender --background --disable-autoexec Dragoon_Source_Snapshot.blend --python build_workbench.py
"""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion
folder = Path(__file__).resolve().parent
root = folder.parents[1]
data = json.loads((folder/'game_pose_samples.json').read_text())
rig = bpy.data.objects['Reference_Rig']
scene = bpy.context.scene
c = Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
ci = c.inverted()
# Restore only the lance object's canonical local transform in this work copy;
# the complete unsaved source, including its weapon adjustment, is the snapshot.
with bpy.data.libraries.load(str(root/'assets/blender/characters/goemon_cosplay/dragoon.blend')) as (src,dst):
    dst.objects=['Weapon_Cutlass_Geometry']
original=dst.objects[0]
geometry=bpy.data.objects['Weapon_Cutlass_Geometry']
geometry.matrix_basis=original.matrix_basis.copy()
geometry.matrix_parent_inverse=original.matrix_parent_inverse.copy()
bpy.data.objects.remove(original,do_unlink=True)
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
control=rig.data.edit_bones.new('Lance_Control')
control.head=(0,0,0);control.tail=(0,.35,0)
control.use_deform=False
bpy.ops.object.mode_set(mode='OBJECT')
weapon=bpy.data.objects['Weapon_Cutlass']
weapon.parent=None;weapon.matrix_parent_inverse=Matrix.Identity(4)
weapon.matrix_basis=Matrix.Identity(4)
constraint=weapon.constraints.new('COPY_TRANSFORMS');constraint.name='Follow editable lance control'
constraint.target=rig;constraint.subtarget='Lance_Control'
rig.show_in_front=True;rig.data.display_type='STICK'
rig.animation_data_create()
rest={n:rig.data.bones[n].matrix_local.copy() for n in data['bones']}
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
manifest=[]
for clip in data['clips']:
    action=bpy.data.actions.new(clip['name']);action.use_fake_user=True
    rig.animation_data.action=action
    step=18 if 'Idle' in clip['name'] else (2 if 'Thrust' in clip['name'] else 3)
    keys=set(range(0,len(clip['frames']),step))|{len(clip['frames'])-1}
    keys|={int(v)-1 for v in clip['markers'].values()}
    previous={}
    for f in sorted(keys):
        scene.frame_set(f+1)
        sample=clip['frames'][f]
        desired={}
        for name, pose in zip(data['bones'],sample['bones']):
            mat=(ci @ Matrix(pose['delta']) @ c) @ rest[name]
            mat.translation=(ci @ Vector((*pose['position'],1))).xyz
            desired[name]=mat
            bone=rig.data.bones[name]
            parent=bone.parent
            rig.pose.bones[name].matrix_basis=(rest[name].inverted() @ rest[parent.name] @ desired[parent.name].inverted() @ mat) if parent else rest[name].inverted() @ mat
        rig.pose.bones['Lance_Control'].matrix=ci @ Matrix(sample['lance']) @ c
        # Bone matrices are assigned parent first; update evaluation before keys.
        bpy.context.view_layer.update()
        for pb in rig.pose.bones:
            q=pb.rotation_quaternion.copy()
            if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
            pb.rotation_quaternion=q;previous[pb.name]=q.copy()
            for prop in ('location','rotation_quaternion','scale'):
                pb.keyframe_insert(data_path=prop,frame=f+1,group=pb.name)
    action.use_frame_range=True;action.frame_start=1;action.frame_end=len(clip['frames'])
    for label,frame in clip['markers'].items():action.pose_markers.new(label).frame=frame
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:key.interpolation='LINEAR'
    action['notes']='Editable key poses captured from current Dragoon game animation; in place. Jump uses a preview velocity sequence.'
    action.asset_mark()
    action.asset_data.description=action['notes']
    manifest.append({'action':action.name,'start':1,'end':len(clip['frames']),'keyframes':sorted(f+1 for f in keys),'markers':clip['markers']})
rig.animation_data.action=bpy.data.actions['01_Idle']
rig.animation_data.action_slot=rig.animation_data.action.slots[0]
scene.render.fps=60;scene.frame_start=1;scene.frame_end=217
scene.frame_set(1)
scene.tool_settings.use_keyframe_insert_auto=False
scene['animation_guide']='Choose an action in the bottom Action Editor. Space plays. Pose Mode: select a bone, R to rotate, I to key. Lance_Control moves the lance. Set End to the chosen action end. Full instructions: START_HERE text.'
scene.timeline_markers.clear()
for label,frame in data['clips'][0]['markers'].items():scene.timeline_markers.new(label,frame=frame)
text=bpy.data.texts.new('START_HERE — Dragoon Animation Guide')
text.write('DRAGOON EDITABLE ANIMATIONS\n\n'+scene['animation_guide']+'\n\nACTIONS\n'+'\n'.join(f"{m['action']}: frames 1–{m['end']}" for m in manifest)+'\n\nStart with 01_Idle at frame 55. Select Chest, press R then X, move slightly, Enter, then I to store the pose. Space previews. Ctrl+Z undoes. Ctrl+S saves this work copy.\n\nEdit the rig bones, not Skin or Costume geometry. The dedicated Lance_Control bone carries the weapon and is keyed in each action. Arm and hand poses have FK controls, not IK: rotate the upper arm and forearm as needed. All clips are in place; the game controller owns jump travel and collision. Jump uses a representative takeoff/apex/landing velocity preview.\n\nThe source snapshot preserves your earlier unsaved weapon-object adjustment. Only this work copy aligns the weapon object to its game transform for the captured poses. Existing meshes, UVs, original bone lengths and game assets are preserved. No game integration has been performed.\n')
(folder/'START_HERE.txt').write_text(text.as_string())
(folder/'actions.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Configure every saved animation screen so loading the file is ready to edit.
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        views=sorted([a for a in screen.areas if a.type=='VIEW_3D'],key=lambda a:a.x)
        for idx,area in enumerate(views):
            space=area.spaces.active
            space.shading.type='SOLID';space.shading.color_type='TEXTURE'
            space.overlay.show_extras=False
            space.overlay.show_floor=False
            space.overlay.show_axis_x=False;space.overlay.show_axis_y=False
            space.show_region_ui=False
            space.region_3d.view_perspective='ORTHO'
            space.region_3d.view_location=Vector((0,0,1.3))
            space.region_3d.view_distance=5.5 if idx==0 else 5.2
            # Character's saved rig faces -Y; view from -Y/front, slightly above.
            direction=Vector((0,1,-.12)) if idx==0 else Vector((-1,1,-.25))
            space.region_3d.view_rotation=direction.to_track_quat('-Z','Y')
        if workspace.name=='Animation':
            for area in screen.areas:
                if area.type=='CONSOLE':
                    area.type='DOPESHEET_EDITOR';area.spaces.active.mode='ACTION'
                    area.spaces.active.dopesheet.show_only_selected=True
                    area.spaces.active.show_pose_markers=True
                if area.type=='PROPERTIES':area.spaces.active.context='OBJECT'
for bone in rig.pose.bones:bone.select=False
rig.pose.bones['Chest'].select=True;rig.data.bones.active=rig.data.bones['Chest']
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='POSE')
# Pack texture images so this isolated file opens without broken relative paths.
bpy.ops.file.pack_all()
output=folder/'Dragoon_Animation_Workbench.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('DRAGOON_WORKBENCH_OK',str(output),'actions',len(manifest))
