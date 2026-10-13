import bpy,json,struct,math
from pathlib import Path
OUT=Path('/workspace/scratch/23f1a29e8f92/construction_fx_v1')
expected={
 'FS_FX_Hammer_BuildLoop.glb':('FX_HammerRoot',16,'Build_HammerLoop',1),
 'FS_FX_ProgressFrame.glb':('FX_ProgressRoot',6,None,0),
 'FS_FX_BPrompt.glb':('FX_BPromptRoot',3,None,0),
 'FS_FX_CompletionPulse.glb':('FX_CompletionRoot',12,'Complete_GoldPulse',34),
}
results=[]
for fn,(root,meshes,clip,channels) in expected.items():
 data=(OUT/'exports'/fn).read_bytes();magic,version,total=struct.unpack_from('<III',data,0)
 assert magic==0x46546c67 and version==2 and total==len(data)
 ln,typ=struct.unpack_from('<II',data,12);g=json.loads(data[20:20+ln]);anims=g.get('animations',[])
 assert len(g['scenes'])==1,'Unwanted scene leaked into export'
 assert len(g['meshes'])==meshes,(fn,len(g['meshes']))
 assert len(anims)==bool(clip)
 assert all('uri' not in b for b in g['buffers']),'External buffer'
 assert 'images' not in g,'Unexpected texture dependency'
 if clip:
  a=anims[0];assert a['name']==clip and len(a['channels'])==channels
  times=[g['accessors'][x['input']] for x in a['samplers']]
  assert min(x['min'][0] for x in times)==0 and abs(max(x['max'][0] for x in times)-1)<1e-6
 if 'Completion' in fn:
  assert sum(c['target']['path']=='weights' for c in anims[0]['channels'])==2
  assert sum(len(m['primitives'][0].get('targets',[])) for m in g['meshes'])==2
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=24
 bpy.ops.import_scene.gltf(filepath=str(OUT/'exports'/fn))
 obs=list(bpy.context.scene.objects);root_ob=bpy.data.objects.get(root)
 assert root_ob and root_ob.parent is None
 assert sum(o.type=='MESH' for o in obs)==meshes
 assert all(all(math.isfinite(v) for v in ob.matrix_world[0]) for ob in obs)
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs if o.type=='MESH')
 paths=sorted({c['target']['path'] for a in anims for c in a['channels']})
 r={'file':fn,'bytes':len(data),'meshes':meshes,'triangles':tris,'root':root,'animations':[a['name'] for a in anims], 'animation_paths':paths, 'roundtrip_import':'PASS'}
 if 'Progress' in fn:
  o=bpy.data.objects['ProgressFill'];assert abs(min(v.co.x for v in o.data.vertices))<1e-5
  assert abs(max(v.co.x for v in o.data.vertices)-1.95)<1e-5
  r['left_anchor_at_local_x_zero']='PASS'
 if 'Hammer' in fn:
  o=bpy.data.objects['FX_HammerSwingPivot'];samples=[]
  for f in [0,6,12,18,24]:bpy.context.scene.frame_set(f);samples.append(list(o.rotation_quaternion))
  assert any(sum(abs(a-b) for a,b in zip(samples[0],sm))>.1 for sm in samples[1:]),'Hammer did not move'
  assert sum(abs(a-b) for a,b in zip(samples[0],samples[-1]))<1e-4,'Loop seam'
  r['loop_motion_and_matching_endpoints']='PASS'
 if 'Completion' in fn:
  o=bpy.data.objects['Completion_OuterRing'];ks=o.data.shape_keys
  assert ks and len(ks.key_blocks)==2
  vals=[]
  for f in [0,4,12,24]:bpy.context.scene.frame_set(f);vals.append(ks.key_blocks[1].value)
  assert vals[0]>.99 and vals[-1]>.99 and min(vals)<.1,vals
  r['ring_morph_hidden_visible_hidden']='PASS';r['ring_weight_samples']=vals
 results.append(r)
(OUT/'qa'/'roundtrip_report.json').write_text(json.dumps({'status':'PASS','blender_version':bpy.app.version_string,'checks':results},indent=2))
print(json.dumps(results,indent=2));print('ALL_ROUNDTRIP_CHECKS_PASSED')
