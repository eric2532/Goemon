import bpy,os,json,math,struct
from mathutils import Vector
R='/workspace/scratch/23f1a29e8f92/tower_assets_v1'
m=json.load(open(R+'/asset_manifest.json'));results=[]
for filename in sorted(os.listdir(R+'/exports')):
 if not filename.endswith('.glb'):continue
 bpy.ops.wm.read_factory_settings(use_empty=True)
 path=R+'/exports/'+filename
 bpy.ops.import_scene.gltf(filepath=path)
 objs=list(bpy.context.scene.objects);meshes=[o for o in objs if o.type=='MESH']
 if 'build_recoil' in filename:bpy.context.scene.frame_set(72)
 bounds=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
 mi=[min(p[i] for p in bounds) for i in range(3)];ma=[max(p[i] for p in bounds) for i in range(3)]
 print('CHECK_BOUNDS',filename,mi,ma,flush=True)
 ids=[o.get('stable_id') for o in meshes]
 assert all(ids),(filename,'Missing stable ID')
 assert len(ids)==len(set(ids)),(filename,'Duplicate stable ID')
 assert all(math.isfinite(x) for x in mi+ma)
 with open(path,'rb') as f:
  magic,version,size=struct.unpack('<4sII',f.read(12));jsize,jtype=struct.unpack('<II',f.read(8));g=json.loads(f.read(jsize).decode('utf8'))
 assert magic==b'glTF' and version==2
 anim=g.get('animations',[])
 if 'stage_complete' in filename:
  assert len(meshes)==m['mesh_count'],(len(meshes),m['mesh_count'])
  for i in range(3):assert abs(mi[i]-m['bounds_complete_m']['min'][i])<.03 and abs(ma[i]-m['bounds_complete_m']['max'][i])<.03
 if 'build_recoil' in filename:
  assert len(anim)>0
  assert any('scale'==c['target']['path'] for a in anim for c in a['channels'])
  assert any('translation'==c['target']['path'] for a in anim for c in a['channels'])
  assert len(meshes)==m['mesh_count']
  sc=bpy.context.scene
  scale_counts={}
  for fr in (1,29,52,72,82,91,108,180):
   sc.frame_set(fr);scale_counts[str(fr)]=len([o for o in meshes if max(o.scale)>.01])
  assert scale_counts['1']==scale_counts['180']
  assert scale_counts['72']>scale_counts['1']
  projectile=bpy.data.objects.get('ARROW_PROJECTILE');recoil=bpy.data.objects.get('LAUNCHER_RECOIL')
  assert projectile and recoil
  sc.frame_set(78);a1=projectile.matrix_world.translation.copy();sc.frame_set(91);a2=projectile.matrix_world.translation.copy();assert (a2-a1).length>4.5
 else:scale_counts={}
 results.append({'file':filename,'bytes':os.path.getsize(path),'mesh_nodes':len(meshes),'stable_ids_unique':True,'bounds_blender_m':{'min':mi,'max':ma},'animations':[{'name':a.get('name'),'channel_count':len(a['channels'])} for a in anim],'visible_scale_mesh_counts_by_frame':scale_counts,'passed':True})
report={'status':'PASSED','method':'Import every supplied GLB into a fresh Blender 4.3.2 scene; verify geometry bounds, unique stable IDs, mesh counts, animation scale/translation channels and forward/reverse end states; parse binary glTF version/header.','files':results,'engine_integration_tested':False}
json.dump(report,open(R+'/verification_report.json','w'),indent=2)
print('VERIFICATION_PASSED',json.dumps(results))
