"""Connect the user's pirate poses in the live Blender review workbench.

Original actions remain intact. Pass --dry-run for an in-memory render/check.
"""
import bpy
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path('/Users/eric/Desktop/Projects_Codex/Sonic')
FILE=ROOT/'docs/pirate-motion-workbench/Pirate_Animation_Workbench.blend'
QA=ROOT/'build/Other Files/Pirate Weapons/Motion/User Combo'
CONTROLS={'R':'Sword_Control','L':'Gun_Control'}

def signature(a):
    return [(fc.data_path,fc.array_index,[(list(p.co),list(p.handle_left),list(p.handle_right),p.interpolation) for p in fc.keyframe_points])
            for layer in a.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]

def matrix_error(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))

def root(scene,prefix):
    return next(ob for ob in scene.objects if ob.type=='EMPTY' and (ob.name==prefix or ob.name.startswith(prefix+'.')))

def smooth(t):
    t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))

def apply(live=True):
    assert Path(bpy.data.filepath)==FILE,'Unexpected Blender file'
    if live:assert not bpy.context.screen.is_animation_playing,'Stop playback first'
    QA.mkdir(parents=True,exist_ok=True)
    old_scene=bpy.context.scene;capture_rig=next(ob for ob in old_scene.objects if ob.type=='ARMATURE')
    pending={'action':capture_rig.animation_data.action.name,'frame':old_scene.frame_current,
             'basis':{p.name:p.matrix_basis.copy() for p in capture_rig.pose.bones}}
    if live:
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(FILE))
    originals={a.name:signature(a) for a in bpy.data.actions}
    for a in bpy.data.actions:a.use_fake_user=True
    sources={}
    for name,frames in [('01_Idle',[0]),('03_Gun_Shot',[0,1]),('04_Sword_Slash',[0,1,2])]:
        action=bpy.data.actions[name];capture_rig.animation_data.action=action
        capture_rig.animation_data.action_slot=action.slots[0]
        samples={}
        for f in frames:
            old_scene.frame_set(f)
            if pending['action']==name and pending['frame']==f:
                for pb in capture_rig.pose.bones:pb.matrix_basis=pending['basis'][pb.name]
            bpy.context.view_layer.update()
            samples[f]={'basis':{pb.name:pb.matrix_basis.copy() for pb in capture_rig.pose.bones},
                        'grips':{s:(capture_rig.matrix_world@capture_rig.pose.bones['Hand_'+s].matrix).inverted()@root(old_scene,prefix).matrix_world
                                 for s,prefix in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]}}
        sources[name]=samples
    serial={name:{str(f):{'basis':{n:[list(r) for r in m] for n,m in p['basis'].items()},
                           'grips':{s:[list(r) for r in m] for s,m in p['grips'].items()}} for f,p in samples.items()}
            for name,samples in sources.items()}
    (QA/('live-user-inputs.json' if live else 'draft-user-inputs.json')).write_text(json.dumps(serial,indent=2)+'\n')
    # Put the approved jump back on the Jump scene after Action Editor edits.
    idle_scene=bpy.data.scenes['01 — Idle'];jump_scene=bpy.data.scenes['02 — Jump']
    idle_rig=next(ob for ob in idle_scene.objects if ob.type=='ARMATURE')
    idle_rig.animation_data.action=bpy.data.actions['01_Idle'];idle_rig.animation_data.action_slot=idle_rig.animation_data.action.slots[0]
    jump_rig=next(ob for ob in jump_scene.objects if ob.type=='ARMATURE')
    jump_rig.animation_data.action=bpy.data.actions['02_Jump_Explorer'];jump_rig.animation_data.action_slot=jump_rig.animation_data.action.slots[0]
    jump_scene['approved_for_character']='pirate'
    jump_scene['approved_jump']='Exact Explorer jump approved by user; retained unchanged.'
    idle_scene.frame_set(0)
    slash_scene=bpy.data.scenes['04 — Sword Slash'];bpy.context.window.scene=slash_scene
    rig=next(ob for ob in slash_scene.objects if ob.type=='ARMATURE')
    body=[b.name for b in rig.data.bones if b.use_deform]
    for n in sources['04_Sword_Slash'][0]['basis']:
        if n not in CONTROLS.values() and n not in body:body.append(n)
    for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
    rest={n:rig.data.bones[n].matrix_local.copy() for n in body}

    def set_pose(pose):
        for n in body:rig.pose.bones[n].matrix_basis=pose['basis'][n]
        bpy.context.view_layer.update()

    def rotate_bone(name,axis,angle):
        pb=rig.pose.bones[name];m=pb.matrix.copy();pivot=m.translation.copy()
        pb.matrix=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-pivot)@m
        bpy.context.view_layer.update()

    def variant(source,twist,arm_pitch,nod=0,swap_legs=False,advance=0):
        set_pose(source)
        if swap_legs:
            pelvis=rig.pose.bones['Pelvis'].matrix.copy();pr=rest['Pelvis']
            reflection=Matrix.Diagonal((-1,1,1,1))
            snapshots={n:rig.pose.bones[n].matrix.copy() for n in body}
            desired={}
            for side,other in [('L','R'),('R','L')]:
                for prefix in ['Leg','Shin','Foot']:
                    n=prefix+'_'+side;opposite=prefix+'_'+other
                    delta=pelvis.inverted()@snapshots[opposite]@(pr.inverted()@rest[opposite]).inverted()
                    desired[n]=pelvis@reflection@delta@reflection@pr.inverted()@rest[n]
            for prefix in ['Leg','Shin','Foot']:
                for side in ['L','R']:
                    n=prefix+'_'+side;pb=rig.pose.bones[n];parent=pb.parent.name
                    parent_pose=desired.get(parent,snapshots[parent])
                    pb.matrix_basis=rest[n].inverted()@rest[parent]@parent_pose.inverted()@desired[n]
            bpy.context.view_layer.update()
        rotate_bone('Chest','Z',twist)
        rotate_bone('Arm_R','Y',arm_pitch)
        rotate_bone('Head','Z',-twist*.5)
        if nod:rotate_bone('Head','X',nod)
        rig.pose.bones['Root'].location.y+=advance
        bpy.context.view_layer.update()
        return {'basis':{n:rig.pose.bones[n].matrix_basis.copy() for n in body},
                'grips':{s:m.copy() for s,m in source['grips'].items()}}

    user=sources['04_Sword_Slash'];idle=sources['01_Idle'][0]
    # Preserve all authored body/head/leg poses in hit 1, at retimed anchors.
    anchors=[(0,user[0]),(8,user[1]),(16,user[2]),
             (24,variant(user[1],-.22,.25,swap_legs=True)),
             (32,variant(user[2],.18,-.05,.035,swap_legs=True)),
             (42,variant(user[1],-.32,-.08,advance=.035)),
             (52,variant(user[2],.32,.16,.08,advance=.10)),
             (56,variant(user[2],.32,.16,.08,advance=.10)),(72,idle)]
    # The user moved the free hand at pose 2; attach its pistol to that hand.
    for frame,p in anchors:
        p['grips']={s:m.copy() for s,m in p['grips'].items()}
        if frame!=72:p['grips']['L']=user[0]['grips']['L'].copy()

    def action_new(name,sk):
        action=bpy.data.actions.new(name);action.use_fake_user=True
        sk.animation_data_create();sk.animation_data.action=action
        return action

    def key_pose(sk,frame,basis,grips,previous):
        for n in body:sk.pose.bones[n].matrix_basis=basis[n]
        bpy.context.view_layer.update()
        for s,control in CONTROLS.items():sk.pose.bones[control].matrix=sk.pose.bones['Hand_'+s].matrix@grips[s]
        bpy.context.view_layer.update()
        for pb in sk.pose.bones:
            q=pb.rotation_quaternion.copy()
            if pb.name in previous and q.dot(previous[pb.name])<0:q.negate()
            pb.rotation_quaternion=q;previous[pb.name]=q.copy()
            for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)

    def connect(sk,sc,action,keys,end):
        previous={};targets={}
        for f in range(end+1):
            for (a,pa),(b,pb) in zip(keys,keys[1:]):
                if f<=b:break
            t=smooth((f-a)/(b-a))
            basis={n:pa['basis'][n].lerp(pb['basis'][n],t) for n in body}
            grips={s:pa['grips'][s].lerp(pb['grips'][s],t) for s in CONTROLS}
            sc.frame_set(f);key_pose(sk,f,basis,grips,previous)
            targets[f]={'basis':basis,'grips':grips}
        action.use_frame_range=True;action.frame_start=0;action.frame_end=end
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for p in fc.keyframe_points:p.interpolation='LINEAR'
        sc.frame_start=0;sc.frame_end=end;sc.render.fps=60
        return targets

    combo=action_new('04_Three_Hit_Slash',rig)
    combo_targets=connect(rig,slash_scene,combo,anchors,72)
    slash_scene['clip']='04_Three_Hit_Slash'
    markers={'User ready':0,'Hit 1 windup':8,'Hit 1 contact':13,'User follow through':16,
             'Hit 2 windup':24,'Hit 2 contact RIGHT':29,'Hit 2 follow through':32,
             'Finisher windup':42,'Hit 3 contact RIGHT':48,'Finisher follow through':52,'User idle':72}
    slash_scene.timeline_markers.clear()
    for label,f in markers.items():slash_scene.timeline_markers.new(label,frame=f);combo.pose_markers.new(label).frame=f
    combo['source_action']='04_Sword_Slash';combo['source_frames']='0 / 1 / 2 mapped exactly to 0 / 8 / 16'
    combo['new_slash_directions']='Hit 2 rightward; Hit 3 rightward in front view.'
    combo.asset_mark();combo.asset_data.description='Three-hit pirate slash derived from user head, leg and sword poses.'

    # Gun shot uses the two authored endpoint poses, with brief recoil between.
    gun_scene=bpy.data.scenes['03 — Gun Shot'];bpy.context.window.scene=gun_scene
    gun_rig=next(ob for ob in gun_scene.objects if ob.type=='ARMATURE')
    for pb in gun_rig.pose.bones:pb.rotation_mode='QUATERNION'
    gun_user=sources['03_Gun_Shot'];recoil={'basis':{n:m.copy() for n,m in gun_user[0]['basis'].items()},
                                          'grips':{s:m.copy() for s,m in gun_user[0]['grips'].items()}}
    recoil['basis']['Arm_L']=recoil['basis']['Arm_L']@Matrix.Rotation(math.radians(-5),4,'X')
    recoil['basis']['Head']=recoil['basis']['Head']@Matrix.Rotation(math.radians(2),4,'X')
    gun_action=action_new('03_Gun_Shot_User',gun_rig)
    gun_targets=connect(gun_rig,gun_scene,gun_action,[(0,gun_user[0]),(3,gun_user[0]),(6,recoil),(24,gun_user[1])],24)
    gun_markers={'User start pose':0,'Fire':4,'Recoil':6,'User end pose':24}
    gun_scene.timeline_markers.clear()
    for label,f in gun_markers.items():gun_scene.timeline_markers.new(label,frame=f);gun_action.pose_markers.new(label).frame=f
    gun_scene['clip']='03_Gun_Shot_User';gun_action['source_action']='03_Gun_Shot';gun_action['source_frames']='0 / 1 mapped exactly to 0 / 24'
    gun_action.asset_mark();gun_action.asset_data.description='User-authored aim and end poses, with a brief firing recoil.'
    flash=next((ob for ob in gun_scene.objects if ob.name.startswith('MuzzleFlash')),None)
    if flash:
        flash.animation_data_clear()
        for f,size in [(0,0),(3,0),(4,1),(5,.6),(6,0),(24,0)]:flash.scale=(size,)*3;flash.keyframe_insert(data_path='scale',frame=f)
        flash.animation_data.action.name='FX_User_Gun_Shot';flash.animation_data.action.use_fake_user=True

    max_pose_error=0;max_grip_error=0
    for sc,sk,targets in [(slash_scene,rig,combo_targets),(gun_scene,gun_rig,gun_targets)]:
        bpy.context.window.scene=sc
        for f,target in targets.items():
            sc.frame_set(f);bpy.context.view_layer.update()
            max_pose_error=max(max_pose_error,max(matrix_error(sk.pose.bones[n].matrix_basis,target['basis'][n]) for n in body))
            for side,prefix in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]:
                actual=(sk.matrix_world@sk.pose.bones['Hand_'+side].matrix).inverted()@root(sc,prefix).matrix_world
                max_grip_error=max(max_grip_error,matrix_error(actual,target['grips'][side]))
    assert max(max_pose_error,max_grip_error)<1e-4,(max_pose_error,max_grip_error)
    assert all(signature(bpy.data.actions[n])==sig for n,sig in originals.items()),'An authored source action changed'
    # Verify the exact source head/leg/body anchors in the new first hit.
    bpy.context.window.scene=slash_scene
    anchor_error=0
    for f,original in [(0,0),(8,1),(16,2)]:
        slash_scene.frame_set(f);bpy.context.view_layer.update()
        anchor_error=max(anchor_error,max(matrix_error(rig.pose.bones[n].matrix_basis,user[original]['basis'][n]) for n in body))
    assert anchor_error<1e-5,anchor_error
    # Exact blade tip from the swept blade mesh, including its size group.
    sword=root(slash_scene,'Weapon_Cutlass')
    blade=next(o for o in sword.children_recursive if o.name.startswith('Cutlass | swept forged blade'))
    bpy.context.view_layer.update()
    native=sword.matrix_world.inverted()@blade.matrix_world@blade.data.vertices[-1].co
    deltas=[]
    for start,end in [(24,32),(42,52)]:
        slash_scene.frame_set(start);bpy.context.view_layer.update();a=sword.matrix_world@native
        slash_scene.frame_set(end);bpy.context.view_layer.update();b=sword.matrix_world@native
        deltas.append(b.x-a.x)
    assert min(deltas)>.3,('Expected both extra swings to move right',deltas)

    spec=importlib.util.spec_from_file_location('pirate_sizes',ROOT/'tools/pirate_weapon_sizes.py')
    sizes=importlib.util.module_from_spec(spec);spec.loader.exec_module(sizes)
    framing={}
    for sc,frames in [(slash_scene,[0,8,13,16,24,29,32,42,48,52,72]),(gun_scene,[0,4,6,24])]:
        bpy.context.window.scene=sc;framing[sc.name]=sizes.fit_camera(sc,sorted(set(frames)|set(range(sc.frame_start,sc.frame_end+1,3))))
        for f in frames:
            sc.frame_set(f);sc.render.resolution_x=1000;sc.render.resolution_y=1000
            sc.render.filepath=str(QA/(sc['clip']+'-'+str(f)+'.png'));bpy.ops.render.render(write_still=True)
    report={'live_applied':live,'user_source_actions_unchanged':True,'approved_jump_unchanged':True,
            'jump_action':'02_Jump_Explorer','combo_action':combo.name,'gun_action':gun_action.name,
            'exact_first_hit_body_pose_error':anchor_error,'pose_error':max_pose_error,'grip_error':max_grip_error,
            'extra_swings_tip_delta_right_m':deltas,'contact_frames':[13,29,48],'combo_range':[0,72],
            'gun_authored_pose_frames':{'source_0':0,'source_1':24}}
    (QA/('live-verification.json' if live else 'draft-verification.json')).write_text(json.dumps(report,indent=2)+'\n')
    bpy.context.window.scene=slash_scene;slash_scene.frame_set(0)
    if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='POSE')
    if live:
        guide='''PIRATE — APPROVED POSES AND THREE-HIT COMBO / BLENDER REVIEW

Scene dropdown:
01 — Idle: your approved frame 0; original idle action retained.
02 — Jump: approved Explorer jump, now assigned to Pirate; frames 1–91.
03 — Gun Shot: your source frames 0 and 1 connected across 0–24, with recoil.
04 — Sword Slash: three hits over frames 0–72; contacts 13 / 29 / 48.

Hit 1 preserves your source slash poses 0 / 1 / 2 at frames 0 / 8 / 16,
including your head movement and leg lift. Hits 2 and 3 both swing right.
The second hit changes the lead leg; the last hit has a stronger body turn.
Your original 03_Gun_Shot and 04_Sword_Slash actions are retained unchanged.

Space plays. Sword_Control and Gun_Control move the weapons. Edit the arm,
forearm, hand, head and leg bones in Pose Mode, then I records the pose.
The sword remains 2.2x and pistol 1.8x their first review sizes.
This workbench is for Blender review; game integration is a separate step.
'''
        (FILE.parent/'START_HERE.txt').write_text(guide)
        text=bpy.data.texts.get('START_HERE — Pirate Animation Guide')
        if text:text.clear();text.write(guide)
        manifest=[{'scene':sc.name,'action':next(ob for ob in sc.objects if ob.type=='ARMATURE').animation_data.action.name,
                   'start':sc.frame_start,'end':sc.frame_end,'markers':{m.name:m.frame for m in sc.timeline_markers}}
                  for sc in bpy.data.scenes]
        (FILE.parent/'actions.json').write_text(json.dumps(manifest,indent=2)+'\n')
        (FILE.parent/'approved_motions.json').write_text(json.dumps({'character':'pirate','jump':'02_Jump_Explorer',
            'idle_source_frame':0,'gun_shot':gun_action.name,'three_hit_slash':combo.name,'review_only':True},indent=2)+'\n')
        center,scale=framing[slash_scene.name]
        for area in bpy.context.screen.areas:
            if area.type=='CONSOLE':
                if area.y<100:
                    area.type='DOPESHEET_EDITOR';area.spaces.active.mode='ACTION'
                    area.spaces.active.dopesheet.show_only_selected=False
                    area.spaces.active.show_pose_markers=True
                else:area.type='VIEW_3D'
            if area.type=='VIEW_3D':
                area.spaces.active.shading.type='MATERIAL'
                area.spaces.active.region_3d.view_location=center
                area.spaces.active.region_3d.view_distance=max(4.5,scale*.95)
        bpy.ops.wm.save_as_mainfile(filepath=str(FILE))
    print('PIRATE_USER_COMBO_VERIFIED',json.dumps(report))
    return report

if __name__=='__main__':
    if '--dry-run' in sys.argv:bpy.ops.wm.open_mainfile(filepath=str(FILE))
    apply(live='--dry-run' not in sys.argv)
