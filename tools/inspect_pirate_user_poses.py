"""Read saved authored poses without modifying the workbench."""
import bpy
import hashlib
import importlib.util
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
FILE=ROOT/'docs/pirate-motion-workbench/Pirate_Animation_Workbench.blend'
QA=ROOT/'build/Other Files/Pirate Weapons/Motion/User Combo'
QA.mkdir(parents=True,exist_ok=True)
before=hashlib.sha256(FILE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(FILE))
sc=bpy.context.scene;rig=next(o for o in sc.objects if o.type=='ARMATURE')
spec=importlib.util.spec_from_file_location('sizes',ROOT/'tools/pirate_weapon_sizes.py')
sizes=importlib.util.module_from_spec(spec);spec.loader.exec_module(sizes)
def root(prefix):
    return next(o for o in sc.objects if o.type=='EMPTY' and (o.name==prefix or o.name.startswith(prefix+'.')))

result={'source_hash':before,'scene':sc.name,'rig':rig.name,'actions':{},'assignments':{s.name:next(o for o in s.objects if o.type=='ARMATURE').animation_data.action.name for s in bpy.data.scenes}}
for name,frames in [('01_Idle',[0]),('03_Gun_Shot',[0,1]),('04_Sword_Slash',[0,1,2])]:
    action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    poses={}
    center,scale=sizes.fit_camera(sc,frames)
    sc.render.resolution_x=1000;sc.render.resolution_y=1000
    for f in frames:
        sc.frame_set(f);bpy.context.view_layer.update()
        poses[str(f)]={'basis':{p.name:[list(r) for r in p.matrix_basis] for p in rig.pose.bones},
                       'matrices':{p.name:[list(r) for r in p.matrix] for p in rig.pose.bones},
                       'grips':{side:[list(r) for r in (rig.matrix_world@rig.pose.bones['Hand_'+side].matrix).inverted()@root(prefix).matrix_world]
                                for side,prefix in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]},
                       'weapons':{side:[list(r) for r in root(prefix).matrix_world] for side,prefix in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]}}
        sc.render.filepath=str(QA/(name+'-'+str(f)+'.png'));bpy.ops.render.render(write_still=True)
    result['actions'][name]=poses
(QA/'authored-poses.json').write_text(json.dumps(result,indent=2)+'\n')
assert hashlib.sha256(FILE.read_bytes()).hexdigest()==before
print('USER_POSES_CAPTURED',json.dumps({'assignments':result['assignments'],'actions':{n:list(p) for n,p in result['actions'].items()}}))
