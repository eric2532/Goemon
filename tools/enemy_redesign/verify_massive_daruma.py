"""Check uniform scale and unchanged topology, face UVs, texture and protected files."""
import struct,json,hashlib,math
from pathlib import Path
R=Path(__file__).resolve().parents[2];D=R/'docs/enemy-concepts/3d-v02'
def read(path):
 raw=path.read_bytes();assert raw[:4]==b'glTF';length=struct.unpack_from('<I',raw,12)[0];data=json.loads(raw[20:20+length]);offset=20+length;return data,raw[offset+8:]
def values(data,blob,index):
 a=data['accessors'][index];b=data['bufferViews'][a['bufferView']];n={'VEC2':2,'VEC3':3,'SCALAR':1}[a['type']];f={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']];size=struct.calcsize(f)*n;start=b.get('byteOffset',0)+a.get('byteOffset',0);stride=b.get('byteStride',size)
 return [struct.unpack_from('<'+f*n,blob,start+i*stride) for i in range(a['count'])]
def primitives(data):return {n['name']:data['meshes'][n['mesh']]['primitives'] for n in data['nodes'] if 'mesh' in n}
old,ob=read(R/'assets/models/enemies/forest_redesign_v01/daruma_breaker.glb');new,nb=read(R/'assets/models/enemies/forest_redesign_v02/daruma_breaker.glb')
a,b=primitives(old),primitives(new);assert set(a)==set(b);checked=0
old_nodes={n['name']:n for n in old['nodes'] if 'mesh' in n};new_nodes={n['name']:n for n in new['nodes'] if 'mesh' in n}
def transformed(point,node):
 scale=node.get('scale',[1,1,1]);vx,vy,vz=[point[i]*scale[i] for i in range(3)]
 x,y,z,w=node.get('rotation',[0,0,0,1]);tx=2*(y*vz-z*vy);ty=2*(z*vx-x*vz);tz=2*(x*vy-y*vx)
 translation=node.get('translation',[0,0,0])
 return (vx+w*tx+y*tz-z*ty+translation[0],vy+w*ty+z*tx-x*tz+translation[1],vz+w*tz+x*ty-y*tx+translation[2])
for name in a:
 assert len(a[name])==len(b[name])
 for p,q in zip(a[name],b[name]):
  op=values(old,ob,p['attributes']['POSITION']);np=values(new,nb,q['attributes']['POSITION']);assert len(op)==len(np)
  assert all(abs(y-4*x)<1e-4 for ov,nv in zip(op,np) for x,y in zip(transformed(ov,old_nodes[name]),transformed(nv,new_nodes[name]))),name+' world geometry is not uniformly 4x'
  assert all(abs(x-1)<1e-5 for x in new_nodes[name].get('scale',[1,1,1])),name+' scale is not applied'
  assert values(old,ob,p['attributes']['TEXCOORD_0'])==values(new,nb,q['attributes']['TEXCOORD_0']),name+' UVs changed'
  if 'indices' in p:assert values(old,ob,p['indices'])==values(new,nb,q['indices']),name+' topology changed'
  checked+=1
# The painted body image stays byte-identical in the exported GLB.
def images(data,blob):
 result=[]
 for image in data['images']:
  view=data['bufferViews'][image['bufferView']];offset=view.get('byteOffset',0);result.append(hashlib.sha256(blob[offset:offset+view['byteLength']]).hexdigest())
 return result
assert images(old,ob)==images(new,nb),'Embedded face texture changed'
for p,digest in json.loads((D/'preserved-files-before.json').read_text()).items():assert hashlib.sha256((R/p).read_bytes()).hexdigest()==digest,p+' changed'
report=json.loads((D/'daruma_breaker-report.json').read_text())
assert abs(report['height_vs_goemon']-7)<1e-5
assert report['linear_scale_vs_v01']==4
result={'passed':True,'primitives_checked':checked,'scale_factor':4,'height_m':report['height'],'width_m':report['width'],'depth_m':report['depth'],'height_vs_goemon':report['height_vs_goemon'],'face_uvs_and_embedded_texture':'unchanged','topology':'unchanged','previous_asset_and_gameplay_files':'unchanged'}
(D/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('MASSIVE_DARUMA_VERIFICATION',json.dumps(result))
