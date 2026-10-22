"""Normalize the merged glTF clip to t=0 without changing geometry or output tracks."""
import json,struct,pathlib
p=pathlib.Path('/workspace/scratch/23f1a29e8f92/tower_assets_v1/exports/tower_build_recoil_reverse.glb')
raw=p.read_bytes();magic,version,total=struct.unpack_from('<4sII',raw,0);assert magic==b'glTF' and version==2
n,t=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+n]);pos=20+n;bn,bt=struct.unpack_from('<II',raw,pos);binary=bytearray(raw[pos+8:pos+8+bn])
ids={sampler['input'] for animation in g.get('animations',[]) for sampler in animation['samplers']}
minimum=min(g['accessors'][i]['min'][0] for i in ids)
for i in ids:
 a=g['accessors'][i];assert a['componentType']==5126 and a['type']=='SCALAR';view=g['bufferViews'][a['bufferView']];offset=view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',4)
 values=[]
 for j in range(a['count']):
  value=struct.unpack_from('<f',binary,offset+j*stride)[0]-minimum
  if abs(value)<1e-6:value=0.
  struct.pack_into('<f',binary,offset+j*stride,value);values.append(struct.unpack_from('<f',binary,offset+j*stride)[0])
 a['min']=[min(values)];a['max']=[max(values)]
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);binary+=b'\0'*((-len(binary))%4)
p.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(binary))+struct.pack('<II',len(j),0x4E4F534A)+j+struct.pack('<II',len(binary),0x004E4942)+binary)
print('TIMING_NORMALIZED',minimum,'-> 0; duration',max(g['accessors'][i]['max'][0] for i in ids))
