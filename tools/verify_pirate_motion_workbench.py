"""Read-only checks on all saved pirate review clips."""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/pirate-motion-workbench'
QA=ROOT/'build/Other Files/Pirate Weapons/Motion'
report=json.loads((QA/'build-verification.json').read_text())
specs=json.loads((OUT/'actions.json').read_text())

def digest(ob):
    data={'vertices':[list(v.co) for v in ob.data.vertices],
          'faces':[list(p.vertices) for p in ob.data.polygons],
          'uv':[[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers],
          'weights':[[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices]}
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()

bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/weapons/pirate/pirate_equipped_preview.blend'))
expected={n:digest(bpy.data.objects[n]) for n in ['Skin','Hair_Normal','Costume_pirate']}
rig=bpy.data.objects['Reference_Rig']
rests={b.name:[list(r) for r in b.matrix_local] for b in rig.data.bones}
bpy.ops.wm.open_mainfile(filepath=report['file'])
assert len(bpy.data.scenes)==4
checked=0;max_offset=0;max_return_error=0;neutral=None;maximum_jump=0;shot_forward_dot=0
for meta in specs:
    sc=bpy.data.scenes[meta['scene']];bpy.context.window.scene=sc
    sk=next(ob for ob in sc.objects if ob.type=='ARMATURE')
    assert sc.frame_end==meta['end'] and sc.render.fps==60
    assert sk.animation_data.action.name==meta['name']
    assert all([list(r) for r in sk.data.bones[n].matrix_local]==m for n,m in rests.items())
    for prefix,h in expected.items():
        ob=next(ob for ob in sc.objects if ob.name==prefix or ob.name.startswith(prefix+'.'))
        assert digest(ob)==h,prefix
    roots={s:next(ob for ob in sc.objects if ob.name==prefix or ob.name.startswith(prefix+'.'))
           for s,prefix in [('R','Weapon_Cutlass'),('L','Weapon_Pistol')]}
    for s,multiplier in [('R',report['weapon_scales']['sword']),('L',report['weapon_scales']['gun'])]:
        assert abs(roots[s]['review_weapon_scale']-multiplier)<1e-6
        group=next(ob for ob in roots[s].children if ob.get('size_multiplier')==multiplier)
        assert all(abs(v-multiplier)<1e-6 for v in group.scale)
    for f in range(1,meta['end']+1):
        sc.frame_set(f);bpy.context.view_layer.update()
        assert all(math.isfinite(v) for pb in sk.pose.bones for row in pb.matrix for v in row),(sc.name,f)
        for s,weapon in roots.items():
            hand=sk.matrix_world@sk.pose.bones['Hand_'+s].matrix
            offset=(hand.inverted()@weapon.matrix_world).translation.length
            max_offset=max(max_offset,offset)
            assert offset<report['maximum_grip_offset']+.04,(sc.name,f,s,offset)
        if meta['name']=='02_Jump':maximum_jump=max(maximum_jump,sk.pose.bones['Root'].location.z)
        if meta['name']=='03_Gun_Shot' and f==13:
            forward=(roots['L'].matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
            shot_forward_dot=forward.dot(Vector((0,-1,0)))
            assert shot_forward_dot>.98,forward
            flash=next(ob for ob in sc.objects if ob.name.startswith('MuzzleFlash'))
            assert not flash.hide_render and flash.scale.x>.9
        if f in [1,meta['end']]:
            current={n:sk.pose.bones[n].matrix_basis.copy() for n in rests}
            if neutral is None:neutral=current
            error=max(abs(current[n][i][j]-neutral[n][i][j]) for n in rests for i in range(4) for j in range(4))
            max_return_error=max(max_return_error,error)
            assert error<1e-4,(sc.name,f,error)
        checked+=1
assert maximum_jump>1
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in report['source_hashes'].items())
result={'saved_workbench_opens':True,'scenes':list(bpy.data.scenes.keys()),'frames_checked':checked,
        'body_geometry_uvs_weights_unchanged':True,'rest_bones_unchanged':True,'sources_unchanged':True,
        'maximum_grip_offset_m':max_offset,'idle_return_error':max_return_error,
        'jump_preview_height_m':maximum_jump,'gun_forward_alignment':shot_forward_dot}
(QA/'saved-file-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('PIRATE_SAVED_MOTIONS_VERIFIED',json.dumps(result))
