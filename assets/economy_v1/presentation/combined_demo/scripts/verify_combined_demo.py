import bpy,json,hashlib,math
from pathlib import Path
OUT=Path('/workspace/scratch/23f1a29e8f92/construction_fx_v1/combined_demo');s=bpy.context.scene
manifest=json.loads((OUT/'qa/source_manifest.json').read_text())
for name,source in manifest['sources'].items():assert hashlib.sha256(Path(source['file']).read_bytes()).hexdigest()==source['sha256'],name+' source changed'
fills=[o for o in s.objects if 'ProgressFill' in o.name]
assert len(fills)==2
roots={n:bpy.data.objects['DEMO_'+n+'_Attachment'] for n in ['Tower','Mine']}
report={'status':'PASS','fps':s.render.fps,'sources_current':True,'states':[]}
for f,p in [(1,0),(49,.7),(73,.4),(121,1),(145,1)]:
 s.frame_set(f);counts={}
 for name,root in roots.items():
  meshes=[o for o in root.children_recursive if o.type=='MESH']
  counts[name]=sum(abs(o.matrix_world.determinant())>0.000001 for o in meshes)
 values=[o.scale.x for o in fills]
 assert all(abs(v-max(.00001,p))<.0001 for v in values),(f,values,p)
 report['states'].append({'frame':f,'progress':p,'fill_scales':values,'visible_mesh_counts':counts})
for name in roots:assert report['states'][0]['visible_mesh_counts'][name]<report['states'][-1]['visible_mesh_counts'][name]
ring=[o for o in s.objects if 'Completion_OuterRing' in o.name]
assert len(ring)==2
for f,target in [(121,1),(129,0),(145,1)]:
 s.frame_set(f)
 vals=[o.data.shape_keys.key_blocks[1].value for o in ring]
 assert all(abs(v-target)<1e-4 for v in vals),(f,vals)
report['completion_ring_playback']='PASS'
assert all(math.isfinite(v) for o in s.objects for row in o.matrix_world for v in row)
(OUT/'qa/combined_demo_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));print('COMBINED_DEMO_VERIFIED')
