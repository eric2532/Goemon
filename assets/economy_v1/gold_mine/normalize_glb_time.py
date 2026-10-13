import os,json,struct
D=os.path.dirname(os.path.abspath(__file__));p=os.path.join(D,'goldmine_v1.glb');b=open(p,'rb').read();ln,typ=struct.unpack_from('<II',b,12);j=json.loads(b[20:20+ln]);bo=20+ln;bn,bt=struct.unpack_from('<II',b,bo);binary=bytearray(b[bo+8:bo+8+bn]);done=set()
for clip in j['animations']:
 target=4.0 if clip['name']=='work_loop' else 2.0
 for s in clip['samplers']:
  i=s['input']
  if i in done:continue
  a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',4);vals=[struct.unpack_from('<f',binary,offset+k*stride)[0] for k in range(a['count'])];start,end=vals[0],vals[-1]
  for k,x in enumerate(vals):struct.pack_into('<f',binary,offset+k*stride,(x-start)/(end-start)*target)
  a['min']=[0.0];a['max']=[target];done.add(i)
jb=json.dumps(j,separators=(',',':')).encode();jb+=b' '*((-len(jb))%4);total=12+8+len(jb)+8+len(binary)
open(p,'wb').write(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<II',len(jb),typ)+jb+struct.pack('<II',len(binary),bt)+binary)
print('NORMALIZED_TO_ZERO',len(done),'unique animation input buffers')
