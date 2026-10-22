"""Read-only saved Blender animation checks, including every played frame."""
from pathlib import Path
import bpy, math, json, hashlib
from mathutils import Vector

OUT=Path(__file__).resolve().parent
ARTIFACTS=OUT.parents[1]/'build/Other Files/Samurai weapon workbench'
backup=ARTIFACTS/'Before animation preparation.blend'
def digest(ob):
    values={'v':[list(v.co) for v in ob.data.vertices],
            'p':[list(p.vertices) for p in ob.data.polygons],
            'uv':[[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers],
            'weights':[[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices]}
    return hashlib.sha256(json.dumps(values).encode()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(backup))
before={o.name:digest(o) for o in bpy.data.objects if o.type=='MESH'}
rest={b.name:[list(r) for r in b.matrix_local] for b in bpy.data.objects['Reference_Rig'].data.bones}
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Samurai_Weapon_Workbench.blend'))
assert all(digest(bpy.data.objects[n])==d for n,d in before.items() if 'Katana_Blade' not in n)
manifest=json.loads((OUT/'actions.json').read_text())
report={'all_non_blade_meshes_uvs_weights_unchanged':True,'original_rest_bones_unchanged':True,'scabbard_removed_from_active_scenes':True,'clips':[]}
failures=[]
def rendered_objects(collection,hidden=False):
    if hidden or collection.hide_render:return []
    return list(collection.objects)+[o for c in collection.children for o in rendered_objects(c)]
for sc,meta in zip([bpy.data.scenes[n] for n in ['01 — Idle','02 — Run','03 — Five-hit combo']],manifest):
    bpy.context.window.scene=sc
    rig=next(o for o in sc.objects if o.type=='ARMATURE')
    assert rest=={n:[list(r) for r in rig.data.bones[n].matrix_local] for n in rest}
    assert rig.animation_data.action.name==meta['action']
    assert sc.frame_start==1 and sc.frame_end==meta['end']
    assert not any('Sheath' in o.name for o in rendered_objects(sc.collection))
    hand_error=0;foot_error=0;min_z=100;worst_hand=None;endpoints=[]
    design=next(o for o in sc.objects if o.name.startswith('Katana_Design'))
    grip_scale=design.scale.z
    for f in range(1,sc.frame_end+1):
        sc.frame_set(f);bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get();evaluated=rig.evaluated_get(dg)
        for side,z in [('R',.04*grip_scale),('L',-.20*grip_scale)]:
            actual=evaluated.pose.bones['Hand_'+side].matrix@Vector((0,.115,0))
            expected=evaluated.pose.bones['Katana_Control'].matrix@Vector((0,0,z))
            error=(actual-expected).length
            if error>hand_error:hand_error=error;worst_hand=(f,side)
            foot_error=max(foot_error,(evaluated.pose.bones['Foot_'+side].head-evaluated.pose.bones['Foot_IK_'+side].head).length)
        blade=next(o for o in sc.objects if o.type=='MESH' and o.data.name.startswith('Katana_Blade'))
        min_z=min(min_z,min((blade.matrix_world@v.co).z for v in blade.data.vertices))
        if f in [1,sc.frame_end]:
            endpoints.append({b.name:[list(r) for r in b.matrix] for b in evaluated.pose.bones})
        assert all(math.isfinite(v) for b in evaluated.pose.bones for r in b.matrix for v in r)
    loop_error=0
    if meta['loop']:
        loop_error=max(abs(a-b) for n in endpoints[0] for ra,rb in zip(endpoints[0][n],endpoints[1][n]) for a,b in zip(ra,rb))
    item={'scene':sc.name,'frames_checked':sc.frame_end,'max_hand_grip_error':hand_error,'worst_hand':worst_hand,'max_foot_target_error':foot_error,'minimum_blade_height':min_z,'loop_matrix_error':loop_error}
    report['clips'].append(item)
    print('CLIP_CHECK',json.dumps(item),flush=True)
    if hand_error>=.012:failures.append(sc.name+': hands leave the katana grip')
    if foot_error>=.012:failures.append(sc.name+': foot target unreachable')
    if min_z<=.02:failures.append(sc.name+': blade crosses floor')
    if loop_error>=.002:failures.append(sc.name+': loop endpoints differ')
assert len([m for m in manifest[2]['markers'] if m.startswith('HIT ')])==5
assert bpy.data.images['REFERENCE — user katana (maroon adaptation)'].packed_file
(ARTIFACTS/'animation-verification.json').write_text(json.dumps(report,indent=2))
assert not failures, failures
print('ANIMATION_WORKBENCH_VERIFIED',flush=True)
