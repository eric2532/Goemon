"""Blender verification of the exported roster's preservation/mesh contracts.
Blender -b --python tools/verify_rogue_roster_art.py -- BASELINE_DIR OUTPUT_JSON
"""
import bpy,bmesh,json,hashlib,sys,struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from sculpt_rogue_roster import HEROES
from sculpt_rogue_pilot import validate_export_face_uv
args=sys.argv[sys.argv.index('--')+1:];baseline=Path(args[0]);output=Path(args[1]);report={'heroes':{},'preserved':{},'failures':[]}
def check(ok,label):
 if not ok:report['failures'].append(label)
def inspect(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update();data={}
 for o in bpy.data.objects:
  if o.type not in ['MESH','EMPTY']:continue
  item={'type':o.type,'parent':o.parent.name if o.parent else None,'transform':list(v for row in o.matrix_world for v in row)}
  if o.type=='MESH':
   item['vertices']=[list(o.matrix_world@v.co) for v in o.data.vertices]
   item['uv_layers']=[uv.name for uv in o.data.uv_layers]
   item['face']=bool(o.get('painted_face'))
   if o.name.startswith('Roster ') or item['face']:
    bm=bmesh.new();bm.from_mesh(o.data);item['nonmanifold']=sum(not e.is_manifold for e in bm.edges);item['degenerate']=sum(f.calc_area()<1e-10 for f in bm.faces);item['volume']=bm.calc_volume(signed=True);bm.free()
  data[o.name]=item
 return data
for hero in HEROES:
 before=inspect(baseline/'assets/blender/rogue'/(hero+'.blend'));after=inspect(ROOT/'assets/blender/rogue'/(hero+'.blend'))
 art=json.loads((ROOT/'assets/rogue/styled'/(hero+'-build.json')).read_text());adjusted=art['adjusted_accessories'];counts={'pivots':0,'unchanged_components':0,'new_or_sculpted_components':0,'body_and_weapons':0}
 for name,old in before.items():
  if old['type']=='EMPTY':
   check(name in after and old==after[name],hero+' pivot '+name);counts['pivots']+=1
  elif name in after and not old['face'] and name not in adjusted:
   check(old==after[name],hero+' unchanged component '+name);counts['unchanged_components']+=1
  if old['type']=='MESH' and old['parent']!='Head':
   check(name in after and old==after[name],hero+' body/weapon '+name);counts['body_and_weapons']+=1
 for name,new in after.items():
  if 'nonmanifold' in new:
   check(new['nonmanifold']==0 and new['degenerate']==0 and new['volume']>0,hero+' closed manifold '+name);counts['new_or_sculpted_components']+=1
  if new['type']=='MESH':check(new['uv_layers']==['Painted palette'],hero+' source UV0 '+name)
 uv=validate_export_face_uv(hero) if hero!='knight' else {'face_method':'enclosed helmet'}
 raw=(ROOT/'assets/rogue/styled/models'/(hero+'.glb')).read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);check(all('TEXCOORD_1' not in p['attributes'] and 'TEXCOORD_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives']),hero+' exported single UV0')
 report['heroes'][hero]={**counts,'export_uv':uv,'triangles':art['triangles'],'mesh_batches':art['mesh_batches']}
# Preserve complete accepted pilot outputs, the approved Goemon source, and face atlas.
hashes=json.loads((baseline/'sha256.json').read_text())
for path,old_hash in hashes.items():
 if any(t in path for t in ['magic-swordsman','explorer','characters/kai.blend','faces/painted-faces.png']):
  new_hash=hashlib.sha256((ROOT/path).read_bytes()).hexdigest();report['preserved'][path]=new_hash==old_hash;check(new_hash==old_hash,'preserved '+path)
report['success']=not report['failures'];output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n');print('ROGUE_ART_VERIFY',json.dumps(report,indent=2));assert report['success'],report['failures']
