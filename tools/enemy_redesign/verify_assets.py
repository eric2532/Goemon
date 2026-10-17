"""Verify actual exported GLBs, embedded face textures, scale and protected originals."""
from pathlib import Path
import struct,json,math,hashlib
R=Path(__file__).resolve().parents[2];D=R/'docs/enemy-concepts/3d-v01'
failures=[];checks=0;rows=[]
def check(ok,message):
 global checks
 checks+=1
 if not ok:failures.append(message);print('FAIL:',message)
def glb(path):
 raw=path.read_bytes();magic,version,total=struct.unpack_from('<4sII',raw)
 assert magic==b'glTF' and version==2 and total==len(raw)
 jl,jt=struct.unpack_from('<II',raw,12);assert jt==0x4e4f534a
 data=json.loads(raw[20:20+jl]);offset=20+jl;bl,bt=struct.unpack_from('<II',raw,offset);assert bt==0x004e4942
 return data,raw[offset+8:offset+8+bl]
def accessor(data,binary,index):
 a=data['accessors'][index];view=data['bufferViews'][a['bufferView']]
 n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']];size=struct.calcsize(fmt)*n
 offset=view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',size)
 return [struct.unpack_from('<'+fmt*n,binary,offset+i*stride) for i in range(a['count'])]
def local(node):
 if 'matrix' in node:return node['matrix']
 x,y,z,w=node.get('rotation',[0,0,0,1]);sx,sy,sz=node.get('scale',[1,1,1]);tx,ty,tz=node.get('translation',[0,0,0])
 return [(1-2*(y*y+z*z))*sx,2*(x*y+z*w)*sx,2*(x*z-y*w)*sx,0,2*(x*y-z*w)*sy,(1-2*(x*x+z*z))*sy,2*(y*z+x*w)*sy,0,2*(x*z+y*w)*sz,2*(y*z-x*w)*sz,(1-2*(x*x+y*y))*sz,0,tx,ty,tz,1]
def multiply(a,b):return [sum(a[k*4+i]*b[j*4+k] for k in range(4)) for j in range(4) for i in range(4)]
identity=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
for slug,ratio in [('masked_raider',1.40),('reed_archer',1.35),('daruma_breaker',1.75),('lantern_runner',1.55)]:
 path=R/'assets/models/enemies/forest_redesign_v01'/f'{slug}.glb';check(path.exists(),slug+' has a GLB export')
 if not path.exists():continue
 data,binary=glb(path);check(all('uri' not in b for b in data.get('buffers',[])),slug+' geometry is self-contained')
 check(data.get('images') and all('bufferView' in i for i in data['images']),slug+' face textures are embedded')
 report=json.loads((D/f'{slug}-report.json').read_text());face_names=set(report['face_meshes']);face_nodes=[n for n in data['nodes'] if n.get('name') in face_names and 'mesh' in n]
 check(bool(face_nodes),slug+' exports its painted curved face surface')
 for node in face_nodes:
  for p in data['meshes'][node['mesh']]['primitives']:
   check('TEXCOORD_0' in p['attributes'],slug+' face exports UV coordinates')
   check('NORMAL' in p['attributes'],slug+' face exports normals')
   mat=data['materials'][p['material']]
   check('baseColorTexture' in mat.get('pbrMetallicRoughness',{}),slug+' face uses its painted texture')
 points=[]
 def visit(i,parent):
  node=data['nodes'][i];transform=multiply(parent,local(node))
  if 'mesh' in node:
   for primitive in data['meshes'][node['mesh']]['primitives']:
    for x,y,z in accessor(data,binary,primitive['attributes']['POSITION']):
     points.append(tuple(transform[k]*x+transform[4+k]*y+transform[8+k]*z+transform[12+k] for k in range(3)))
  for child in node.get('children',[]):visit(child,transform)
 for i in data['scenes'][data.get('scene',0)]['nodes']:visit(i,identity)
 check(all(math.isfinite(v) for p in points for v in p),slug+' has finite geometry')
 height=max(p[1] for p in points)-min(p[1] for p in points);reference=json.loads((D/'goemon-reference.json').read_text())['height']
 check(abs(height/reference-ratio)<.01,slug+' exported height agrees with its intended larger-than-Goemon scale')
 check(min(p[1] for p in points)>-.01,slug+' origin rests on ground')
 check((R/report['source']).exists(),slug+' has an editable Blender source')
 for view in ['front','side','back','three-quarter','face-detail']:check((D/f'{slug}-{view}.png').exists(),slug+' has '+view+' review')
 rows.append({'asset':slug,'height':height,'height_vs_goemon':height/reference,'triangles':report['triangles'],'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
for rel,digest in json.loads((D/'preserved-files-before.json').read_text()).items():check(hashlib.sha256((R/rel).read_bytes()).hexdigest()==digest,rel+' remains unchanged')
result={'checks':checks,'failures':failures,'assets':rows};(D/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('ENEMY_ASSET_VERIFICATION checks=%d failures=%d'%(checks,len(failures)))
raise SystemExit(1 if failures else 0)
