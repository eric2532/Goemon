from pathlib import Path
import json,struct,hashlib
P=Path(__file__).resolve().parents[1];notes=json.loads((P/'reference_observations.json').read_text())['notes'];checks={r['id']:r for r in json.loads((P/'validation.json').read_text())['checks']};assets=[]
for r in notes:
 i,n=r['id'],r['name'];f=P/'exports'/f'{i}_{n}.glb';raw=f.read_bytes();size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size]);v=checks[i]
 assets.append({'id':i,'name':n,'source':f'sources/{i}_{n}.blend','export':f'exports/{i}_{n}.glb','reference':str(next((P/'references').glob(i+'-*.png')).relative_to(P)),'comparison':f'previews/{i}_comparison.jpg','views':f'previews/{i}_views.jpg','scope':'static sculpture','armature':False,'animations':[],'materials':len(g.get('materials',[])),'export_meshes':v['glb_meshes'],'export_triangles':sum(g['accessors'][p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives'] if 'indices' in p),'source_sha256':hashlib.sha256((P/f'sources/{i}_{n}.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(raw).hexdigest(),'bounds_m':v['glb_bounds_m']})
(P/'asset_manifest.json').write_text(json.dumps({'schema_version':1,'count':10,'blender_version':'4.3.2','units':'meters','assets':assets},indent=2));print('Asset manifest written')
