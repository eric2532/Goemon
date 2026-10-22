"""Build four editable Blender-only pirate motion review scenes."""
import bpy
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/pirate-motion-workbench'
QA=ROOT/'build/Other Files/Pirate Weapons/Motion'
SOURCE=ROOT/'assets/blender/weapons/pirate/pirate_equipped_preview.blend'
TARGET=OUT/'Pirate_Animation_Workbench.blend'
OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
if TARGET.exists() and '--rebuild-generated' not in sys.argv:
    raise RuntimeError('Preserve the existing editable workbench; do not overwrite user edits.')
(OUT/'.gdignore').write_text('\n')
protected=[SOURCE,ROOT/'assets/blender/characters/goemon_cosplay/pirate.blend',
           ROOT/'assets/models/characters/goemon_cosplay/pirate.glb',
           ROOT/'docs/explorer-motion-workbench/Explorer_Animation_Workbench.blend']
hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
data=json.loads((QA.parent/'game-motion-samples.json').read_text())
explorer=json.loads((ROOT/'assets/animations/explorer_approved.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig']
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
names=data['bones'];rest={n:rig.data.bones[n].matrix_local.copy() for n in names}
base={n:rig.pose.bones[n].matrix_basis.copy() for n in names}
arms=[n+'_'+s for s in ['L','R'] for n in ['Clavicle','Arm','Forearm','Hand']]
weapons={s:bpy.data.objects[n] for s,n in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]}
bpy.context.view_layer.update()
idle_grips={s:(rig.matrix_world@rig.pose.bones['Hand_'+s].matrix).inverted()@ob.matrix_world for s,ob in weapons.items()}
c=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));ci=c.inverted()

def unpack(v):
    return Matrix.LocRotScale(Vector(v[:3]),Quaternion((v[6],v[3],v[4],v[5])),Vector(v[7:10]))

def globals_to_basis(poses):
    result={}
    for n in names:
        parent=rig.data.bones[n].parent
        result[n]=rest[n].inverted()@rest[parent.name]@poses[parent.name].inverted()@poses[n] if parent else rest[n].inverted()@poses[n]
    return result

def explorer_basis(frame):
    poses={}
    for n,v in zip(explorer['bones'],explorer['clips']['idle']['frames'][frame]['bones']):
        m=ci@unpack(v)@c
        rotation=m.to_3x3()@rest[n].to_3x3()
        translation=m.translation.copy();m=rotation.to_4x4();m.translation=translation
        poses[n]=m
    return globals_to_basis(poses)

explorer_neutral=explorer_basis(0)

def idle_basis(frame):
    sampled=explorer_basis(frame)
    result={n:base[n].copy() for n in names}
    for n in arms:result[n]=sampled[n]
    for n in ['Spine','SpineMid','Chest','Neck','Head']:
        result[n]=sampled[n]@explorer_neutral[n].inverted()@base[n]
    return result

def game_pose(sample):
    poses={}
    for n,v in zip(names,sample['bones']):
        m=(ci@Matrix(v['delta'])@c)@rest[n]
        m.translation=(ci@Vector((*v['position'],1))).xyz
        poses[n]=m
    grips={s:poses['Hand_'+s].inverted()@(ci@Matrix(sample[key])@c) for s,key in [('R','right'),('L','left')]}
    return globals_to_basis(poses),grips

def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)

# Independent non-deforming weapon controls keep both grips editable.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
controls={'R':'Sword_Control','L':'Gun_Control'}
for s,n in controls.items():
    bone=rig.data.edit_bones.new(n);bone.head=(0,0,0);bone.tail=(0,.24,0);bone.use_deform=False
bpy.ops.object.mode_set(mode='OBJECT')
for s,ob in weapons.items():
    ob.parent=None;ob.parent_type='OBJECT';ob.parent_bone=''
    ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
    follow=ob.constraints.new('COPY_TRANSFORMS');follow.name='Follow editable '+controls[s]
    follow.target=rig;follow.subtarget=controls[s]
rig.show_in_front=True;rig.data.display_type='STICK'
rig.animation_data_create()
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'

specs=[
    {'name':'01_Idle','scene':'01 — Idle','end':217,'step':6,'markers':{'Start':1,'Inhale':55,'Neutral':109,'Exhale':163,'Loop':217},'review':55},
    {'name':'02_Jump','scene':'02 — Jump','end':91,'step':1,'markers':{'Ready':1,'Takeoff':10,'Rise':25,'Apex':43,'Fall':61,'Landing':76,'Settle':91},'review':43},
    {'name':'03_Gun_Shot','scene':'03 — Gun Shot','end':61,'step':1,'markers':{'Ready':1,'Aim':10,'Fire':13,'Recoil':18,'Lower gun':31,'Recover':61},'review':13},
    {'name':'04_Sword_Slash','scene':'04 — Sword Slash','end':49,'step':1,'markers':{'Ready':1,'Windup':11,'Contact':16,'Follow through':24,'Recover':38,'Settle':49},'review':16},
]
motion={clip['name']:clip['frames'] for clip in data['clips']}
maximum_grip_offset=0
for spec in specs:
    action=bpy.data.actions.new(spec['name']);action.use_fake_user=True
    rig.animation_data.action=action
    keys=set(range(0,spec['end'],spec['step']))|{spec['end']-1}|{v-1 for v in spec['markers'].values()}
    previous={}
    for f in sorted(keys):
        scene.frame_set(f+1)
        if spec['name']=='01_Idle':
            basis=idle_basis(f);grips={s:g.copy() for s,g in idle_grips.items()}
        else:
            clip=motion[spec['name']]
            if spec['name']=='02_Jump':index=f;weight=min(smooth(f/9),1-smooth((f-75)/15))
            elif spec['name']=='03_Gun_Shot':index=max(f,12);weight=min(smooth(f/12),1-smooth((f-28)/32))
            else:index=max(f,10);weight=min(smooth(f/10),1-smooth((f-28)/20))
            target,target_grips=game_pose(clip[index])
            basis={n:base[n].lerp(target[n],weight) for n in names}
            grips={s:idle_grips[s].lerp(target_grips[s],weight) for s in ['R','L']}
            if spec['name']=='02_Jump' and 9<f<75:
                # Review-only vertical trajectory; Root keys are fully editable.
                basis['Root'].translation.z+=1.1*math.sin(math.pi*(f-9)/66)
        for n in names:rig.pose.bones[n].matrix_basis=basis[n]
        bpy.context.view_layer.update()
        if spec['name']=='03_Gun_Shot':
            # The old driver pose pitches the barrel upward. Aim the draft
            # firearm forward and rotate its wrist with it, retaining the grip.
            hand=rig.pose.bones['Hand_L']
            gun_matrix=hand.matrix@grips['L']
            gun_rotation=gun_matrix.to_quaternion()
            aimed=rig.matrix_world.inverted().to_quaternion()
            aimed=gun_rotation.slerp(aimed,weight)
            wrist_rotation=aimed@gun_rotation.inverted()@hand.matrix.to_quaternion()
            hand.matrix=Matrix.LocRotScale(hand.matrix.translation,wrist_rotation,hand.matrix.to_scale())
            bpy.context.view_layer.update()
        for s,n in controls.items():
            rig.pose.bones[n].matrix=rig.pose.bones['Hand_'+s].matrix@grips[s]
            maximum_grip_offset=max(maximum_grip_offset,grips[s].translation.length)
        bpy.context.view_layer.update()
        for pb in rig.pose.bones:
            q=pb.rotation_quaternion.copy()
            if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
            pb.rotation_quaternion=q;previous[pb.name]=q.copy()
            for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(data_path=prop,frame=f+1,group=pb.name)
    action.use_frame_range=True;action.frame_start=1;action.frame_end=spec['end']
    for label,frame in spec['markers'].items():action.pose_markers.new(label).frame=frame
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:key.interpolation='LINEAR'
    action['description']='Blender review: new pirate weapons; Explorer idle arms; production motion adapted with idle transitions.'
    action.asset_mark();action.asset_data.description=action['description']
    spec['keyframes']=sorted(f+1 for f in keys)

# Brief editable muzzle flash, attached to the actual open barrel.
flash_vertices=[(0,0,0)]
for i in range(10):
    angle=i*math.tau/10;r=.065 if i%2==0 else .027
    flash_vertices.append((r*math.cos(angle),-.072,r*math.sin(angle)))
flash_vertices.append((0,-.19,0))
flash_faces=[]
for i in range(10):
    a=1+i;b=1+(i+1)%10
    flash_faces.extend([(0,b,a),(11,a,b)])
me=bpy.data.meshes.new('Muzzle flash | editable star');me.from_pydata(flash_vertices,[],flash_faces);me.update()
flash=bpy.data.objects.new('MuzzleFlash | review effect',me);scene.collection.objects.link(flash)
flash.parent=weapons['L'];flash.location=(0,-.645,.14664)
mat=bpy.data.materials.new('Muzzle flash | warm emission');mat.use_nodes=True
shader=mat.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=(1,.3,.025,1)
shader.inputs['Emission Color'].default_value=(1,.33,.025,1);shader.inputs['Emission Strength'].default_value=5
me.materials.append(mat)
for frame,size in [(1,0),(12,0),(13,1),(14,.65),(15,0),(61,0)]:
    flash.scale=(size,)*3;flash.keyframe_insert(data_path='scale',frame=frame)
flash.animation_data.action.name='FX_Gun_Muzzle_Flash'

guide='''PIRATE — FOUR EDITABLE MOTION REVIEW SCENES

Switch scenes with the Scene dropdown at the top right:
01 — Idle: frames 1–217, Explorer idle arms with a gentle breathing loop.
02 — Jump: frames 1–91, takeoff / apex / landing, with editable Root lift.
03 — Gun Shot: frames 1–61, raise / fire / recoil / recover.
04 — Sword Slash: frames 1–49, windup / contact / follow through / recover.

Space plays and pauses. The bottom Action Editor shows editable keys.
Select arm, forearm or hand bones in Pose Mode; R rotates, I records a key.
Sword_Control and Gun_Control position the weapons independently of the arms.
Keep the handles seated in the hands when editing these controls.
Root keys contain the jump preview height; set its Z location to zero for an in-place jump.
Auto Key is OFF. Command-S saves this workbench.

All scenes use the new silver-and-brass octopus cutlass and walnut flintlock.
The original body geometry, painted UVs, bone rest lengths and live game files
remain unchanged. These clips are Blender review drafts, not game integration.
'''
text=bpy.data.texts.new('START_HERE — Pirate Animation Guide');text.write(guide)
(OUT/'START_HERE.txt').write_text(guide)
(OUT/'actions.json').write_text(json.dumps(specs,indent=2)+'\n')

def configure(sc,meta):
    sc.name=meta['scene'];sc.render.fps=60;sc.frame_start=1;sc.frame_end=meta['end']
    sc.tool_settings.use_keyframe_insert_auto=False
    sc.timeline_markers.clear()
    for label,frame in meta['markers'].items():sc.timeline_markers.new(label,frame=frame)
    sk=next(ob for ob in sc.objects if ob.type=='ARMATURE')
    sk.animation_data.action=bpy.data.actions[meta['name']]
    sk.animation_data.action_slot=sk.animation_data.action.slots[0]
    sc['clip']=meta['name'];sc['review_only']=True
    for ob in sc.objects:
        if ob.name.startswith('MuzzleFlash'):
            ob.hide_render=meta['name']!='03_Gun_Shot'
            ob.hide_viewport=meta['name']!='03_Gun_Shot'
    sc.camera.data=sc.camera.data.copy()
    target=Vector((0,0,2.05 if meta['name']=='02_Jump' else 1.65))
    sc.camera.location=(4,-7,3.6)
    sc.camera.rotation_euler=(target-sc.camera.location).to_track_quat('-Z','Y').to_euler()
    sc.camera.data.ortho_scale=5.5 if meta['name']=='02_Jump' else 4.4
    sc.render.resolution_x=1000;sc.render.resolution_y=1000
    sc.frame_set(1)
    return sk

base_scene=scene
configure(base_scene,specs[0])
scenes=[base_scene]
for meta in specs[1:]:
    bpy.context.window.scene=base_scene
    bpy.ops.scene.new(type='FULL_COPY')
    sc=bpy.context.scene;configure(sc,meta);scenes.append(sc)

# Ready-to-edit Animation workspace: front and three-quarter views plus actions.
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        views=sorted([area for area in screen.areas if area.type=='VIEW_3D'],key=lambda area:area.x)
        for i,area in enumerate(views):
            space=area.spaces.active
            space.shading.type='MATERIAL';space.overlay.show_extras=False
            space.overlay.show_floor=False;space.overlay.show_axis_x=False;space.overlay.show_axis_y=False
            space.show_region_ui=False
            space.region_3d.view_perspective='ORTHO'
            space.region_3d.view_location=Vector((0,0,1.7));space.region_3d.view_distance=6.5
            direction=Vector((0,1,-.12)) if i==0 else Vector((-1,1,-.25))
            space.region_3d.view_rotation=direction.to_track_quat('-Z','Y')
        for area in screen.areas:
            if area.type=='DOPESHEET_EDITOR':
                area.spaces.active.mode='ACTION';area.spaces.active.dopesheet.show_only_selected=False
                area.spaces.active.show_pose_markers=True
            if area.type=='PROPERTIES':area.spaces.active.context='OBJECT'

for sc,meta in zip(scenes,specs):
    bpy.context.window.scene=sc
    size_spec=importlib.util.spec_from_file_location('pirate_sizes',ROOT/'tools/pirate_weapon_sizes.py')
    size_module=importlib.util.module_from_spec(size_spec);size_spec.loader.exec_module(size_module)
    frames=sorted({1,meta['end'],*range(1,meta['end']+1,6),*meta['markers'].values()})
    center,scale=size_module.fit_camera(sc,frames)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_location=center
                area.spaces.active.region_3d.view_distance=max(7,scale*1.5)
    sc.frame_set(meta['review'])
    sc.render.filepath=str(QA/(meta['name']+'.png'))
    bpy.ops.render.render(write_still=True)
    sc.frame_set(1)
bpy.context.window.scene=base_scene
if 'Animation' in bpy.data.workspaces:bpy.context.window.workspace=bpy.data.workspaces['Animation']
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True);bpy.context.view_layer.objects.active=rig
for bone in rig.pose.bones:bone.select=False
rig.pose.bones['Arm_R'].select=True;rig.data.bones.active=rig.data.bones['Arm_R']
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in hashes.items()),'Source changed'
report={'file':str(TARGET),'scenes':[s.name for s in scenes],'actions':[s['name'] for s in specs],
        'file_sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest(),
        'fps':60,'source_hashes':hashes,'sources_unchanged':True,'maximum_grip_offset':maximum_grip_offset,
        'blender_review_only':True}
(QA/'build-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('PIRATE_MOTION_WORKBENCH_BUILT',json.dumps(report))
