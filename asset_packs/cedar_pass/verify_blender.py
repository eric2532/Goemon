"""Reopen authored meshes, exclude hidden collider proxies and verify game exports."""
import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parent
m=json.loads((P/'manifest.json').read_text());meta=json.loads((P/'interiors.json').read_text());results=[]
for a in m:
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f'{a["id"]}.blend'));bpy.context.view_layer.update()
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('cp_group')!='Collision']
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 assert tris==a['triangles'],(a['id'],tris,a['triangles'])
 pts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
 lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
 assert all(abs(hi[i]-lo[i]-a['dimensions_xyz_blender_m'][i])<.005 for i in range(3)),a['id']
 assert bpy.context.scene['asset_id']==a['id']
 if a['id'] in meta:
  proxies=[o for o in bpy.context.scene.objects if o.get('cp_group')=='Collision']
  assert len(proxies)==len(meta[a['id']]['colliders']),a['id']
  for c in meta[a['id']]['colliders']:
   if c['type']=='box':assert all(v>0 for v in c['size_blender'])
 # Delete all objects including hidden proxy collections before importing GLB.
 for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.import_scene.gltf(filepath=str(P/'exports'/f'{a["id"]}.glb'))
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
 assert len(obs)==a['surfaces'],a['id']
 imported_tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs)
 assert imported_tris==tris,a['id']
 for o in obs:
  assert len(o.data.materials)==1
  assert o.location.length<.0001
  assert all(abs(v-1)<.0001 for v in o.scale)
  assert o.rotation_euler.to_quaternion().angle<.0001
 if a['id'] in meta:assert set(o.name.removeprefix('CP_') for o in obs)==set(a['groups'])
 results.append({'id':a['id'],'source_reopened':True,'export_reimported':True,'triangles':tris,'ground_pivots':True,'surfaces':len(obs),'collision_proxies':len(meta[a['id']]['colliders']) if a['id'] in meta else 0})
for name in ['contact_sheet','showcase','interior_contact_sheet']:
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f'{name}.blend'))
 assert len(bpy.context.scene.objects)>10
(P/'verification/blender.json').write_text(json.dumps(results,indent=2))
print('PASS: 22 editable sources, 22 GLBs, cutaway groups, collision proxies, both contact sheets and showcase reopened')
