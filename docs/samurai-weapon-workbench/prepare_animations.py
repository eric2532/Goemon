"""Editable Blender-only Samurai idle/run/five-hit animation draft.

Adds non-deforming controls and IK without changing original rest bones or meshes.
The script refuses to replace an animation workbench that already has actions.
"""
from pathlib import Path
import bpy, math, json, shutil, sys
from mathutils import Matrix, Vector, Quaternion

OUT=Path(__file__).resolve().parent
TARGET=OUT/'Samurai_Weapon_Workbench.blend'
ARTIFACTS=OUT.parents[1]/'build/Other Files/Samurai weapon workbench'
ARTIFACTS.mkdir(parents=True,exist_ok=True)
backup=ARTIFACTS/'Before animation preparation.blend'
if not backup.exists():shutil.copy2(TARGET,backup)
bpy.ops.wm.open_mainfile(filepath=str(backup if '--from-backup' in sys.argv else TARGET))
if bpy.data.actions:raise RuntimeError('Preserve authored animation work; do not regenerate over existing actions.')
bpy.context.preferences.filepaths.save_version=0
scene=bpy.data.scenes['01 — Samurai with maroon katana']
bpy.context.window.scene=scene
rig=bpy.data.objects['Reference_Rig']
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
rig.hide_set(False);rig.hide_viewport=False;rig.hide_render=False
for ob in bpy.context.selected_objects:ob.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
rest_json={n:[list(row) for row in m] for n,m in rest.items()}
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()

# Archive both scabbard displays; none remains in the active character or detail view.
archive=bpy.data.collections['Archive — original katana (unchanged)']
archive.name='Archive — unused original weapon and scabbard'
archive.hide_render=True;archive.hide_viewport=True
scabbard_collection=bpy.data.collections.get('Sheath — fitted to enlarged katana')
if scabbard_collection:
    for c in list(scene.collection.children):
        if c==scabbard_collection:scene.collection.children.unlink(c)
    archive.children.link(scabbard_collection)
detail=bpy.data.scenes['02 — Katana and fitted scabbard']
detail.name='04 — Katana detail'
for ob in list(detail.objects):
    if 'Sheath' in ob.name:
        for c in list(ob.users_collection):c.objects.unlink(ob)
        archive.objects.link(ob)

# All new controls are pose bones in the same armature, so a clip is one action.
bpy.ops.object.mode_set(mode='EDIT')
def control(name,head,tail,parent='Root',matrix=None):
    b=rig.data.edit_bones.new(name);b.head=head;b.tail=tail
    if matrix is not None:b.matrix=matrix
    b.parent=rig.data.edit_bones[parent];b.use_deform=False;b.use_connect=False
    return b
control('Katana_Control',(0,0,0),(0,.34,0))
for side,z in [('R',.04*1.15),('L',-.20*1.15)]:
    control('Hand_IK_'+side,(0,-.115,z),(0,.035,z),parent='Katana_Control')
    sign=1 if side=='R' else -1
    control('Elbow_Pole_'+side,(sign*.95,-.15,.65),(sign*.95,-.15,.85))
    original=rig.data.edit_bones['Foot_'+side]
    control('Foot_IK_'+side,original.head.copy(),original.tail.copy(),matrix=original.matrix.copy())
    control('Knee_Pole_'+side,(sign*.32,1,.48),(sign*.32,1,.68))
bpy.ops.object.mode_set(mode='OBJECT')
controls=[b.name for b in rig.data.bones if b.name not in rest]
control_collection=rig.data.collections.new('Animation controls — katana, feet and poles')
for name in controls:
    b=rig.data.bones[name];control_collection.assign(b);b.color.palette='THEME04'
rig.data.bones['Katana_Control'].color.palette='THEME09'
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'

# The sword follows a single editable control; both hands stay on its grip.
weapon=bpy.data.objects['Weapon_Cutlass']
weapon.parent=None;weapon.matrix_parent_inverse=Matrix.Identity(4);weapon.matrix_basis=Matrix.Identity(4)
for c in list(weapon.constraints):weapon.constraints.remove(c)
follow=weapon.constraints.new('COPY_TRANSFORMS');follow.name='Follow Katana_Control';follow.target=rig;follow.subtarget='Katana_Control'
design=bpy.data.objects['Katana_Design — grip origin + original blade axis']
design.matrix_basis=Matrix.Scale(1.15,4)
for side in ['R','L']:
    forearm=rig.pose.bones['Forearm_'+side]
    ik=forearm.constraints.new('IK');ik.name='Two-handed katana grip';ik.target=rig;ik.subtarget='Hand_IK_'+side
    ik.chain_count=2;ik.use_stretch=False;ik.pole_target=rig;ik.pole_subtarget='Elbow_Pole_'+side
    hand=rig.pose.bones['Hand_'+side]
    copy=hand.constraints.new('COPY_ROTATION');copy.name='Keep fist aligned to grip';copy.target=rig;copy.subtarget='Hand_IK_'+side
    shin=rig.pose.bones['Shin_'+side]
    ik=shin.constraints.new('IK');ik.name='Planted feet';ik.target=rig;ik.subtarget='Foot_IK_'+side
    ik.chain_count=2;ik.use_stretch=False;ik.pole_target=rig;ik.pole_subtarget='Knee_Pole_'+side
    foot=rig.pose.bones['Foot_'+side]
    copy=foot.constraints.new('COPY_ROTATION');copy.name='Foot orientation';copy.target=rig;copy.subtarget='Foot_IK_'+side
    # Remove stretch from the solver, preserving the approved limb lengths.
    for n in ['Arm_','Forearm_','Leg_','Shin_']:rig.pose.bones[n+side].ik_stretch=0
    # The source has perfectly straight arms; a small FK bend removes the IK
    # singularity without editing any rest bone or changing the solved grip.
    forearm.rotation_quaternion=Quaternion((1,0,0),.05)

# Follow the existing scarf geometry with the head during the new animation.
scarf=bpy.data.objects['ScarfTail'];scarf_world=scarf.matrix_world.copy()
scarf.parent=rig;scarf.parent_type='BONE';scarf.parent_bone='Head';scarf.matrix_world=scarf_world

R=lambda axis,degrees:Matrix.Rotation(math.radians(degrees),4,axis)
def sword_matrix(position,direction,roll=0):
    z=Vector(direction).normalized();y=Vector((0,1,0));y=(y-z*y.dot(z)).normalized();x=y.cross(z).normalized()
    m=Matrix((x,y,z)).transposed().to_4x4()
    return Matrix.Translation(Vector(position))@m@R('Z',roll)

keyed=['Pelvis','Spine','SpineMid','Chest','Neck','Head','Sash','Katana_Control','Foot_IK_R','Foot_IK_L']
def apply_pose(spec):
    lean,twist,bob=spec.get('body',(2,-7,-.05))
    pivot=Vector((0,0,.966))
    torso=Matrix.Translation((0,0,bob))@Matrix.Translation(pivot)@R('Z',twist)@R('X',-lean)@Matrix.Translation(-pivot)
    desired={}
    for n in ['Pelvis','Spine','SpineMid','Chest','Neck','Head','Sash','Clavicle_R','Clavicle_L']:
        desired[n]=torso@rest[n]
    # Keep his face looking ahead while his torso twists into the cuts.
    head=desired['Head'].translation.copy()
    desired['Head']=Matrix.Translation(head)@R('Z',-twist*.45)@Matrix.Translation(-head)@desired['Head']
    desired['Katana_Control']=sword_matrix(spec['sword'],spec['direction'],spec.get('roll',0))
    for side,sign in [('R',1),('L',-1)]:
        foot=spec.get('feet',{}).get(side,(sign*.32,.10 if side=='R' else -.12,.185,0))
        m=R('X',foot[3])@rest['Foot_'+side]
        m.translation=Vector(foot[:3]);desired['Foot_IK_'+side]=m
    # Assign parent-first in armature space; child IK grips keep their rest offsets.
    for pb in rig.pose.bones:
        if pb.name not in desired:continue
        rb=rig.data.bones[pb.name];parent=rb.parent
        parent_pose=desired.get(parent.name,parent.matrix_local) if parent else Matrix.Identity(4)
        pb.matrix_basis=(rb.matrix_local.inverted()@parent.matrix_local@parent_pose.inverted()@desired[pb.name]) if parent else rb.matrix_local.inverted()@desired[pb.name]
    bpy.context.view_layer.update()

idle=[]
for f in [1,16,31,46,61]:
    phase=(f-1)/60*math.tau
    idle.append((f,{'sword':(0,.53,1.06+.008*math.sin(phase)),'direction':(.45,.48,.75),'body':(2+.5*math.sin(phase),-7,-.05+.008*math.sin(phase))}))
run=[]
for f in range(1,26,3):
    a=(f-1)/24*math.tau;feet={}
    for side,sign,phase in [('R',1,a),('L',-1,a+math.pi)]:
        lift=max(0,-math.sin(phase))
        feet[side]=(sign*.30,.29*math.cos(phase),.185+.30*lift,12*lift)
    run.append((f,{'sword':(.04,.43,1.09+.016*math.cos(2*a)),'direction':(.62,.18+.035*math.sin(a),.76),'body':(10,3*math.sin(a),-.095+.025*math.cos(2*a)),'feet':feet}))
# Readable anticipation/contact/follow-through for five distinct sword strikes.
combo_data=[
 (1,(0,.53,1.06),(.45,.48,.75),(2,-7,-.05),'Ready'),
 (6,(.13,.37,1.41),(.77,.42,.48),(0,16,-.07),'Hit 1 — windup'),
 (12,(.03,.43,1.28),(0,.99,.05),(8,-3,-.09),'HIT 1 — downward diagonal'),
 (16,(-.05,.37,1.08),(-.90,.35,-.26),(10,-16,-.11),'Hit 1 — follow-through'),
 (23,(-.03,.34,1.03),(-.83,.45,-.27),(6,-15,-.10),'Hit 2 — windup'),
 (30,(0,.43,1.26),(0,.97,.24),(5,3,-.07),'HIT 2 — rising return'),
 (34,(.10,.40,1.40),(.70,.44,.56),(0,14,-.04),'Hit 2 — follow-through'),
 (41,(.05,.35,1.25),(.93,.35,.08),(4,17,-.07),'Hit 3 — windup'),
 (48,(0,.42,1.25),(0,1,.02),(7,0,-.09),'HIT 3 — horizontal sweep'),
 (52,(-.04,.33,1.22),(-.93,.35,.04),(7,-17,-.09),'Hit 3 — follow-through'),
 (59,(.03,.24,1.22),(0,.99,.12),(3,-8,-.10),'Hit 4 — thrust preparation'),
 (66,(0,.52,1.22),(0,.995,.10),(11,0,-.12),'HIT 4 — forward thrust'),
 (70,(0,.46,1.21),(0,.99,.12),(9,0,-.11),'Hit 4 — follow-through'),
 (78,(-.02,.50,1.40),(-.06,.70,.71),(0,12,-.06),'Hit 5 — raised windup'),
 (87,(0,.46,1.22),(0,.98,-.12),(14,-2,-.13),'HIT 5 — heavy finishing cut'),
 (92,(-.02,.43,1.05),(-.15,.94,-.30),(14,-7,-.14),'Hit 5 — follow-through'),
 (105,(0,.53,1.06),(.45,.48,.75),(2,-7,-.05),'Return to idle'),
]
combo=[(f,{'sword':p,'direction':d,'body':body}) for f,p,d,body,label in combo_data]

# Choose pole angles from the actual solved limbs, keeping knees forward and elbows low.
apply_pose(idle[0][1])
for side,sign in [('R',1),('L',-1)]:
    for bone_name,pole_name,joint_name,start_name,target_name in [
        ('Forearm_'+side,'Elbow_Pole_'+side,'Forearm_'+side,'Arm_'+side,'Hand_IK_'+side),
        ('Shin_'+side,'Knee_Pole_'+side,'Shin_'+side,'Leg_'+side,'Foot_IK_'+side)]:
        c=next(c for c in rig.pose.bones[bone_name].constraints if c.type=='IK')
        best=None
        for angle in [0,math.pi/2,-math.pi/2,math.pi]:
            c.pole_angle=angle;bpy.context.view_layer.update()
            start=rig.pose.bones[start_name].head;target=rig.pose.bones[target_name].head
            axis=(target-start).normalized();joint=rig.pose.bones[joint_name].head
            pole=rig.pose.bones[pole_name].head
            elbow=joint-start-axis*(joint-start).dot(axis)
            toward=pole-start-axis*(pole-start).dot(axis)
            score=elbow.normalized().dot(toward.normalized())
            if best is None or score>best[0]:best=(score,angle)
        c.pole_angle=best[1]
bpy.context.view_layer.update()

manifest=[]
for name,poses,markers,loop in [
 ('01_Idle',idle,{'Ready / loop start':1,'Breathe in':16,'Neutral':31,'Breathe out':46,'Loop end':61},True),
 ('02_Run',run,{'Right contact':1,'Passing A':7,'Left contact':13,'Passing B':19,'Loop end':25},True),
 ('03_Five_Hit_Combo',combo,{label:f for f,p,d,body,label in combo_data},False)]:
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data_create();rig.animation_data.action=action
    previous={}
    for f,spec in poses:
        scene.frame_set(f);apply_pose(spec)
        for n in keyed:
            pb=rig.pose.bones[n];q=pb.rotation_quaternion.copy()
            if n in previous and q.dot(previous[n])<0:q.negate()
            pb.rotation_quaternion=q;previous[n]=q.copy()
            for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(data_path=prop,frame=f,group=n)
    action.use_frame_range=True;action.frame_start=1;action.frame_end=poses[-1][0]
    for label,frame in markers.items():action.pose_markers.new(label).frame=frame
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    action['loop']=loop;action['blender_draft_only']=True
    action.asset_mark();action.asset_data.description='Editable Samurai katana animation draft; IK keeps both hands on the grip. Blender only.'
    manifest.append({'action':name,'start':1,'end':poses[-1][0],'loop':loop,'keys':[f for f,_ in poses],'markers':markers})

# Separate scenes choose the right action and playback range automatically.
scene.name='01 — Idle'
def select_action(sc,armature,meta):
    armature.animation_data_create();armature.animation_data.action=bpy.data.actions[meta['action']]
    armature.animation_data.action_slot=armature.animation_data.action.slots[0]
    sc.render.fps=30;sc.frame_start=meta['start'];sc.frame_end=meta['end'];sc.frame_set(1)
    sc.timeline_markers.clear()
    for label,f in meta['markers'].items():sc.timeline_markers.new(label,frame=f)
    sc.tool_settings.use_keyframe_insert_auto=False
    sc['animation_draft']='Blender-only. No scabbard. Katana_Control moves the blade and both hands. Foot_IK_L/R place the feet.'
select_action(scene,rig,manifest[0])
scene.camera.data.ortho_scale=5.9
scene.camera.location=(4.2,-8,4.1)
scene.camera.rotation_euler=(Vector((0,-.25,1.55))-scene.camera.location).to_track_quat('-Z','Y').to_euler()

def clone_scene(name,meta):
    sc=bpy.data.scenes.new(name);sc.world=scene.world
    mapping={}
    # Archive objects remain outside the animation scenes.
    for ob in scene.objects:
        if 'Sheath' in ob.name or ob==bpy.data.objects.get('Weapon_Cutlass_Geometry'):continue
        new=ob.copy();mapping[ob]=new;sc.collection.objects.link(new)
    for old,new in mapping.items():
        if old.parent in mapping:new.parent=mapping[old.parent]
        for c in new.constraints:
            if hasattr(c,'target') and c.target in mapping:c.target=mapping[c.target]
            if hasattr(c,'pole_target') and c.pole_target in mapping:c.pole_target=mapping[c.pole_target]
        for mod in new.modifiers:
            if mod.type=='ARMATURE' and mod.object in mapping:mod.object=mapping[mod.object]
        if new.type=='ARMATURE':
            for pb in new.pose.bones:
                for c in pb.constraints:
                    if hasattr(c,'target') and c.target in mapping:c.target=mapping[c.target]
                    if hasattr(c,'pole_target') and c.pole_target in mapping:c.pole_target=mapping[c.pole_target]
    sc.camera=mapping[scene.camera];sc.render.engine='CYCLES';sc.cycles.samples=20;sc.cycles.use_denoising=True
    sc.render.resolution_x=900;sc.render.resolution_y=1000;sc.render.resolution_percentage=100
    sc.view_settings.view_transform=scene.view_settings.view_transform;sc.view_settings.look=scene.view_settings.look
    new_rig=mapping[rig];new_rig.name='Samurai_Rig — '+meta['action']
    select_action(sc,new_rig,meta)
    sc.view_layers[0].objects.active=new_rig
    new_rig.select_set(True,view_layer=sc.view_layers[0])
    return sc,new_rig
run_scene,run_rig=clone_scene('02 — Run',manifest[1])
combo_scene,combo_rig=clone_scene('03 — Five-hit combo',manifest[2])

guide='''SAMURAI — EDITABLE KATANA ANIMATIONS / BLENDER ONLY

Use the Scene dropdown at the top right:
  01 — Idle              1–61, looping two-handed low guard
  02 — Run               1–25, looping run with the katana drawn
  03 — Five-hit combo    1–105, five distinct editable strikes
  04 — Katana detail     weapon modeling view

The scabbard is removed from all active views. Its old geometry is archived.
The maroon katana and original character meshes stay unchanged.

Select Katana_Control in Pose Mode to move/rotate the katana; both hands follow.
Foot_IK_L / Foot_IK_R move the feet. Pelvis / Chest / Head adjust weight and posture.
Small Elbow_Pole and Knee_Pole bones choose the bend direction.
R rotates, G moves, I records a pose. Space plays. Command-S saves.
Auto Key is OFF. After edits, insert Location and Rotation keys on the changed controls.

Combo contact frames: 12 / 30 / 48 / 66 / 87.
Each has windup and follow-through markers. Frame 105 returns to the idle pose.
Run contacts: 1 / 13; passing poses: 7 / 19; loop: 25.
Actions 01_Idle, 02_Run and 03_Five_Hit_Combo are also in the Action Editor.

These are editable animation drafts, not game integration. Original body meshes,
painted UVs and deform-bone rest lengths are preserved. Only non-deforming
animation controls and IK constraints were added to this working copy.
'''
text=bpy.data.texts['START HERE — Samurai katana draft'];text.clear();text.write(guide)
(OUT/'START_HERE.txt').write_text(guide)
(OUT/'actions.json').write_text(json.dumps(manifest,indent=2))
assert rest_json=={n:[list(row) for row in rig.data.bones[n].matrix_local] for n in rest}

# Open ready for posing, with the action timeline beneath the character.
bpy.context.window.scene=scene
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                s=area.spaces.active;s.shading.type='MATERIAL';s.overlay.show_extras=False;s.overlay.show_relationship_lines=False
                s.region_3d.view_location=Vector((0,-.3,1.6));s.region_3d.view_distance=6.2
                s.region_3d.view_rotation=Vector((-.35,1,-.2)).to_track_quat('-Z','Y')
            if area.type=='DOPESHEET_EDITOR':
                s=area.spaces.active;s.mode='ACTION';s.show_pose_markers=True;s.dopesheet.show_only_selected=False
for pb in rig.pose.bones:pb.select=False
visible_controls={'Katana_Control','Foot_IK_R','Foot_IK_L','Pelvis','Chest','Head'}
for b in rig.data.bones:b.hide=b.name not in visible_controls
rig.pose.bones['Katana_Control'].select=True;rig.data.bones.active=rig.data.bones['Katana_Control']
rig.show_in_front=True;rig.data.display_type='STICK'
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='POSE')
if 'Animation' in bpy.data.workspaces:bpy.context.window.workspace=bpy.data.workspaces['Animation']
scene.frame_set(1)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print('SAMURAI_ANIMATIONS_SAVED',flush=True)
if '--skip-renders' in sys.argv:sys.exit(0)

# Small review renders, using identical lighting for the key poses.
for sc,frames,prefix in [(scene,[1],'idle'),(run_scene,[1,7,13,19],'run'),(combo_scene,[6,12,30,48,66,78,87,92],'combo')]:
    bpy.context.window.scene=sc
    sc.render.resolution_x=760;sc.render.resolution_y=840;sc.render.resolution_percentage=100
    sc.cycles.samples=12
    for f in frames:
        sc.frame_set(f);sc.render.filepath=str(ARTIFACTS/(prefix+'-%03d.png'%f))
        bpy.ops.render.render(write_still=True,scene=sc.name)
print('SAMURAI_ANIMATION_PREVIEWS_RENDERED',flush=True)
