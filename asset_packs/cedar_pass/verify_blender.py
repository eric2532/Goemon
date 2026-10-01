import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parent
m=json.loads((P/'manifest.json').read_text());results=[]
for a in m:
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f'{a["id"]}.blend'))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 assert tris==a['triangles'],a['id']
 pts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
 lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
 a['bounds_min']=lo;a['bounds_max']=hi;a['dimensions_xyz_blender_m']=[round(hi[i]-lo[i],3) for i in range(3)]
 assert bpy.context.scene['asset_id']==a['id']
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(P/'exports'/f'{a["id"]}.glb'))
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH']
 assert len(obs)==1,a['id']
 assert len(obs[0].data.materials)==1
 assert obs[0].location.length<.0001
 assert all(abs(v-1)<.0001 for v in obs[0].scale)
 assert obs[0].rotation_euler.to_quaternion().angle<.0001
 results.append({'id':a['id'],'source_reopened':True,'export_reimported':True,'triangles':tris,'ground_pivot':True,'surfaces':1})
(P/'manifest.json').write_text(json.dumps(m,indent=2))
for name in ['contact_sheet','showcase']:
 assert (P/'sources'/f'{name}.blend').exists(), name
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f'{name}.blend'))
 assert len(bpy.context.scene.objects)>10
(P/'verification/blender.json').write_text(json.dumps(results,indent=2))
print('PASS: 22 editable sources, 22 GLBs, contact sheet and showcase reopened')
