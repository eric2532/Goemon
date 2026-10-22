"""Verify authorized equipment scope, native pivots and actual exported cloth/UVs.
Blender -b --python tools/verify_rogue_equipment_art.py -- BASELINE_DIR OUTPUT_JSON
"""
import bpy,bmesh,json,hashlib,sys,struct,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from equip_rogue_roster import HEROES
from sculpt_rogue_pilot import validate_export_face_uv
args=sys.argv[sys.argv.index('--')+1:];baseline=Path(args[0]);output=Path(args[1]);report={'heroes':{},'preserved':{},'failures':[],'checks':0}
def check(ok,label):
 report['checks']+=1
 if not ok:report['failures'].append(label)
def inspect(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update();data={}
 for o in bpy.data.objects:
  if o.type not in ['MESH','EMPTY']:continue
  item={'type':o.type,'parent':o.parent.name if o.parent else None,'transform':[v for row in o.matrix_world for v in row]}
  if o.type=='MESH':
   item['vertices']=[list(o.matrix_world@v.co) for v in o.data.vertices];item['uv']=[[list(p.uv) for p in layer.data] for layer in o.data.uv_layers];item['uv_layers']=[uv.name for uv in o.data.uv_layers];item['face']=bool(o.get('painted_face'))
   if o.name.startswith('Equipment ') or o.get('painted_face') or o.name=='Roster fitted shinobi mask':
    bm=bmesh.new();bm.from_mesh(o.data);item['nonmanifold']=sum(not e.is_manifold for e in bm.edges);item['degenerate']=sum(f.calc_area()<1e-10 for f in bm.faces);item['volume']=bm.calc_volume(signed=True);bm.free()
  data[o.name]=item
 return data
for hero in HEROES:
 before=inspect(baseline/'assets/blender/rogue'/(hero+'.blend'));after=inspect(ROOT/'assets/blender/rogue'/(hero+'.blend'))
 art=json.loads((ROOT/'assets/rogue/styled'/(hero+'-build.json')).read_text());adjusted=art['equipment_adjusted'];removed=art['equipment_removed'];counts={'pivots':0,'unchanged_components':0,'new_or_adjusted_components':0,'body_and_weapons':0}
 for name,old in before.items():
  if old['type']=='EMPTY':check(name in after and old==after[name],hero+' pivot '+name);counts['pivots']+=1
  elif name not in removed and name not in adjusted:
   check(name in after and old==after[name],hero+' unchanged component '+name);counts['unchanged_components']+=1
  if old['type']=='MESH' and old['parent']!='Head':check(name in after and old==after[name],hero+' body/weapon '+name);counts['body_and_weapons']+=1
  if old.get('face'):check(name in after and old['uv']==after[name]['uv'],hero+' unchanged painted face UV '+name)
 for name,new in after.items():
  if 'nonmanifold' in new:check(new['nonmanifold']==0 and new['degenerate']==0 and new['volume']>0,hero+' closed positive manifold '+name);counts['new_or_adjusted_components']+=1
  if new['type']=='MESH':check(new['uv_layers']==['Painted palette'],hero+' source UV0 '+name)
 uv=validate_export_face_uv(hero)
 raw=(ROOT/'assets/rogue/styled/models'/(hero+'.glb')).read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);check(all('TEXCOORD_1' not in p['attributes'] and 'TEXCOORD_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives']),hero+' exported single UV0')
 if hero=='samurai':
  node=next(n for n in doc['nodes'] if n.get('name')=='ScarfTail_Geometry');root=next(n for n in doc['nodes'] if n.get('name')=='ScarfTail');head=next(n for n in doc['nodes'] if n.get('name')=='Head')
  check(doc['nodes'].index(node) in root['children'] and doc['nodes'].index(root) in head['children'],'separate scarf Head/ScarfTail hierarchy')
  check(not any(k in node for k in ['translation','rotation','scale','matrix']),'scarf geometry identity transform')
  pri=doc['meshes'][node['mesh']]['primitives'];check(len(pri)==1,'single cloth surface')
  a=doc['accessors'][pri[0]['attributes']['POSITION']];view=doc['bufferViews'][a['bufferView']];offset=20+size+8+view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',12)
  verts=[struct.unpack_from('<fff',raw,offset+i*stride) for i in range(a['count'])]
  stations=sorted(set(round(-v[2],5) for v in verts));check(len(stations)==25 and abs(stations[0])<1e-5 and abs(stations[-1]-1.4)<1e-5,'cloth 24 continuous length subdivisions')
  check('NORMAL' in pri[0]['attributes'],'cloth exported normals')
  report['scarf']={'vertices':len(verts),'length_stations':stations,'bounds_min':a['min'],'bounds_max':a['max'],'root_translation':root['translation'],'axis':'-Z','mesh_transform':'identity'}
 report['heroes'][hero]={**counts,'export_uv':uv,'triangles':art['triangles'],'mesh_batches':art['mesh_batches']}
hashes=json.loads((baseline/'sha256.json').read_text())
for path,old in hashes.items():
 if not any(('/'+h+'.') in path or ('/'+h+'-') in path for h in HEROES):
  same=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==old;report['preserved'][path]=same;check(same,'preserved '+path)
check('nose_v=.430' in (ROOT/'tools/sculpt_rogue_roster.py').read_text(),'Master Thief nose landmark .430 retained')
report['success']=not report['failures'];output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n');print('ROGUE_EQUIPMENT_VERIFY checks=%d failures=%d'%(report['checks'],len(report['failures'])));print(json.dumps(report['failures'],indent=2));assert report['success'],report['failures']
