import os,json,struct,copy
D=os.path.dirname(os.path.abspath(__file__));p=os.path.join(D,'goldmine_v1.glb');b=open(p,'rb').read();ln,ty=struct.unpack_from('<II',b,12);j=json.loads(b[20:20+ln]);bo=20+ln;bn,bt=struct.unpack_from('<II',b,bo);binary=bytearray(b[bo+8:bo+8+bn]);eps=1e-5;cache={};changed=0
for n in j['nodes']:
 if 'scale' in n:n['scale']=[eps if abs(x)<eps else x for x in n['scale']]
for clip in j['animations']:
 for ch in clip['channels']:
  if ch['target']['path']!='scale':continue
  sampler=clip['samplers'][ch['sampler']];ai=sampler['output']
  if ai not in cache:
   a=j['accessors'][ai];v=j['bufferViews'][a['bufferView']];off=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',12);vals=[list(struct.unpack_from('<fff',binary,off+k*stride)) for k in range(a['count'])]
   if not any(abs(x)<eps for row in vals for x in row):cache[ai]=ai;continue
   vals=[[eps if abs(x)<eps else x for x in row] for row in vals];payload=b''.join(struct.pack('<fff',*row) for row in vals)
   while len(binary)%4:binary+=b'\0'
   vi=len(j['bufferViews']);j['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload)});binary+=payload
   na=copy.deepcopy(a);na['bufferView']=vi;na.pop('byteOffset',None)
   if 'min' in na:na['min']=[min(row[k] for row in vals) for k in range(3)]
   if 'max' in na:na['max']=[max(row[k] for row in vals) for k in range(3)]
   cache[ai]=len(j['accessors']);j['accessors'].append(na);changed+=1
  if cache[ai]!=ai:
   ns=copy.deepcopy(sampler);ns['output']=cache[ai];ch['sampler']=len(clip['samplers']);clip['samplers'].append(ns)
j['buffers'][0]['byteLength']=len(binary);jb=json.dumps(j,separators=(',',':')).encode();jb+=b' '*((-len(jb))%4)
open(p,'wb').write(struct.pack('<4sII',b'glTF',2,28+len(jb)+len(binary))+struct.pack('<II',len(jb),ty)+jb+struct.pack('<II',len(binary),bt)+binary)
print('EPSILON_SCALE_ACCESSORS_REPAIRED',changed)
