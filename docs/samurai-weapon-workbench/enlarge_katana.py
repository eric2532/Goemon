"""Increase the existing animated katana by 20%, preserving authored clips."""
from pathlib import Path
from datetime import datetime
import bpy, math, json, shutil, hashlib
from mathutils import Vector

OUT=Path(__file__).resolve().parent
TARGET=OUT/'Samurai_Weapon_Workbench.blend'
ARTIFACTS=OUT.parents[1]/'build/Other Files/Samurai weapon workbench'
source_hash=hashlib.sha256(TARGET.read_bytes()).hexdigest()
backup=ARTIFACTS/('Before 20 percent sword increase '+datetime.now().strftime('%Y%m%d-%H%M%S')+'.blend')
shutil.copy2(TARGET,backup)
bpy.ops.wm.open_mainfile(filepath=str(TARGET))
bpy.context.preferences.filepaths.save_version=0
assert set(['01_Idle','02_Run','03_Five_Hit_Combo']) <= set(bpy.data.actions.keys())
assert not bpy.data.scenes['01 — Idle'].get('katana_plus_twenty_percent'), 'This size revision has already been applied'
timing={a.name:(a.frame_start,a.frame_end,[(m.name,m.frame) for m in a.pose_markers]) for a in bpy.data.actions}
designs=[o for o in bpy.data.objects if o.name.startswith('Katana_Design')]
assert len(designs)==3
before_scales={o.name:list(o.scale) for o in designs}
for ob in designs:
    ob.scale*=1.2
    ob['size_relative_to_approved_animation_draft']=1.2
bpy.data.objects['Katana detail root'].scale*=1.2

# Resize just the non-deforming grip targets; body/deform rest bones stay intact.
handled=set()
for name in ['01 — Idle','02 — Run','03 — Five-hit combo']:
    sc=bpy.data.scenes[name];bpy.context.window.scene=sc
    if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    rig=next(o for o in sc.objects if o.type=='ARMATURE')
    if rig.data.name in handled:continue
    handled.add(rig.data.name)
    for o in sc.objects:o.select_set(False)
    rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side in ['R','L']:
        b=rig.data.edit_bones['Hand_IK_'+side]
        b.head.z*=1.2;b.tail.z*=1.2
    bpy.ops.object.mode_set(mode='OBJECT')

report={'scale_multiplier':1.2,'all_three_animated_swords_scaled':True,'grip_targets_refitted':True,'clearance_adjustments':{}}
for name in ['01 — Idle','02 — Run','03 — Five-hit combo']:
    sc=bpy.data.scenes[name];bpy.context.window.scene=sc
    rig=next(o for o in sc.objects if o.type=='ARMATURE')
    pb=rig.pose.bones['Katana_Control']
    blade=next(o for o in sc.objects if o.type=='MESH' and o.data.name.startswith('Katana_Blade'))
    baseline={};minimum={}
    for f in range(sc.frame_start,sc.frame_end+1):
        sc.frame_set(f);bpy.context.view_layer.update()
        baseline[f]=pb.location.z
        minimum[f]=min((blade.matrix_world@v.co).z for v in blade.data.vertices)
    bad={f:.07-z for f,z in minimum.items() if z<.07}
    if bad:
        # A small smooth lift avoids floor contact from the longer blade while
        # retaining all rotations, strike markers, body motion and clip timing.
        lo=max(sc.frame_start,min(bad)-9);hi=min(sc.frame_end,max(bad)+9)
        corrections={f:max(amount*math.exp(-((f-j)/3)**2) for j,amount in bad.items()) for f in range(lo,hi+1)}
        corrections[lo]=0;corrections[hi]=0
        for f,delta in corrections.items():
            sc.frame_set(f);pb.location.z=baseline[f]+delta
            pb.keyframe_insert(data_path='location',index=2,frame=f,group=pb.name)
        action=rig.animation_data.action
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        if fc.data_path=='pose.bones["Katana_Control"].location' and fc.array_index==2:
                            for k in fc.keyframe_points:
                                if lo<=k.co.x<=hi:k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
        report['clearance_adjustments'][name]={'frames':[lo,hi],'maximum_lift':max(corrections.values())}
    sc['katana_plus_twenty_percent']=True
    sc.frame_set(1)
assert timing=={a.name:(a.frame_start,a.frame_end,[(m.name,m.frame) for m in a.pose_markers]) for a in bpy.data.actions}
assert all(abs(ob.scale[i]/before_scales[ob.name][i]-1.2)<1e-6 for ob in designs for i in range(3))
scene=bpy.data.scenes['01 — Idle'];bpy.context.window.scene=scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
for o in scene.objects:o.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
for b in rig.pose.bones:b.select=False
rig.pose.bones['Katana_Control'].select=True;rig.data.bones.active=rig.data.bones['Katana_Control']
bpy.ops.object.mode_set(mode='POSE');scene.frame_set(1)
guide=bpy.data.texts['START HERE — Samurai katana draft']
note='\nLatest size revision: the complete katana is 20% larger than the approved animation draft. Both grip targets are refitted. Clip timing and hit markers are unchanged.\n'
guide.write(note)
(OUT/'START_HERE.txt').write_text(guide.as_string())
assert hashlib.sha256(TARGET.read_bytes()).hexdigest()==source_hash,'Workbench changed on disk during resize; preserve the newer file'
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
(ARTIFACTS/'katana-size-increase.json').write_text(json.dumps(report,indent=2))
print('KATANA_ENLARGED',json.dumps(report),flush=True)
