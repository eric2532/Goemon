"""Update Blender gameplay documentation only; preserve all geometry and animation."""
import bpy,json,hashlib
from pathlib import Path
R=Path('/workspace/scratch/23f1a29e8f92/tower_assets_v1')
bpy.ops.wm.open_mainfile(filepath=str(R/'firesiege_arrow_tower_v1.blend'))
def signature():
 data={'meshes':{},'objects':{},'actions':{}}
 for m in bpy.data.meshes:
  data['meshes'][m.name]={'vertices':[list(v.co) for v in m.vertices],'edges':[list(e.vertices) for e in m.edges],'polygons':[list(p.vertices) for p in m.polygons]}
 for o in bpy.data.objects:
  data['objects'][o.name]={'type':o.type,'data':o.data.name if o.data else None,'parent':o.parent.name if o.parent else None,'location':list(o.location),'rotation':list(o.rotation_euler),'scale':list(o.scale),'parent_inverse':[list(v) for v in o.matrix_parent_inverse]}
 for a in bpy.data.actions:
  data['actions'][a.name]=[{'path':fc.data_path,'index':fc.array_index,'keys':[(list(k.co),k.interpolation,list(k.handle_left),list(k.handle_right)) for k in fc.keyframe_points]} for fc in a.fcurves]
 return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()
before=signature()
scene=bpy.data.scenes['02_BUILD_RECOIL_REVERSE_PREVIEW']
notes='Asset demo only. Initially no towers. 4 wall sites + 8 entrance sites. Hold B builds; release decays; resume remaining. Spend 5 gold at completion. Enemies 100 HP; level-1 arrow 50 damage. Confirmed gameplay: one shot every 0.5 seconds (2 shots per second). Time-based gold drain per built tower during combat is required; drain rate and zero-wallet behavior remain unresolved. Preview animation timing is illustrative and unchanged. No engine integration.'
scene['gameplay_notes']=notes
for target in [scene,bpy.data.objects['TOWER_ROOT']]:
 target['gameplay_fire_interval_seconds']=.5;target['gameplay_shots_per_second']=2.;target['gameplay_arrow_damage']=50;target['gameplay_combat_drain_required']=True;target['gameplay_combat_drain_scope']='time-based per built tower during combat';target['gameplay_combat_drain_rate']='unresolved';target['gameplay_zero_wallet_behavior']='unresolved'
after=signature();assert before==after
bpy.ops.wm.save_as_mainfile(filepath=str(R/'firesiege_arrow_tower_v1.blend'),compress=True)
report={'status':'PASS','operation':'Gameplay documentation metadata only','geometry_transform_animation_before_sha256':before,'geometry_transform_animation_after_sha256':after,'unchanged':before==after,'gameplay_fire_interval_seconds':.5,'gameplay_shots_per_second':2,'gameplay_arrow_damage':50,'combat_drain':{'required':True,'scope':'time-based per built tower during combat','rate':None,'zero_wallet_behavior':None}}
(R/'godot_validation/blender_metadata_report.json').write_text(json.dumps(report,indent=2))
print('BLEND_METADATA_ONLY_VERIFIED',before)
