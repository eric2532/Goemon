"""Validate held GLB skin matrices against every recovered ROM part pose."""
from pathlib import Path
import struct,json,math,bisect
import numpy as np
R=Path(__file__).resolve().parent.parent/'assets/characters/thirstquencher'
D=np.diag([1.,-1.,-1.])
def source_matrix(p):
 x,y,z=[v*math.tau/4096 for v in p['angles']];cx,sx=math.cos(x),math.sin(x);cy,sy=math.cos(y),math.sin(y);cz,sz=math.cos(z),math.sin(z)
 rot=np.array([[cz*cy,cz*sy*sx-sz*cx,cz*sy*cx+sz*sx],[sz*cy,sz*sy*sx+cz*cx,sz*sy*cx-cz*sx],[-sy,cy*sx,cy*cx]]);m=np.eye(4);m[:3,:3]=D@rot@D;m[:3,3]=D@np.array(p['position'])*.01;return m

def run(ident):
 path=R/f'soldier_{ident}.glb';d=path.read_bytes();n=struct.unpack_from('<I',d,12)[0];j=json.loads(d[20:20+n]);b=d[28+n:];M=json.loads((R/f'soldier_{ident}_motion.json').read_text());parents={c:i for i,x in enumerate(j['nodes']) for c in x.get('children',[])}
 def ac(i):
  a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];k={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dtype={5126:'<f4',5123:'<u2',5121:'u1'}[a['componentType']];return np.frombuffer(b,dtype=dtype,count=a['count']*k,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(a['count'],k)
 def local(no,mods):
  nd=j['nodes'][no];t=mods.get((no,'translation'),nd.get('translation',[0,0,0]));q=mods.get((no,'rotation'),nd.get('rotation',[0,0,0,1]));s=mods.get((no,'scale'),nd.get('scale',[1,1,1]));x,y,z,w=q;r=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]]);m=np.eye(4);m[:3,:3]=r@np.diag(s);m[:3,3]=t;return m
 skin=j['skins'][0];ibs=ac(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1);joint_to_bind={no:ibs[k] for k,no in enumerate(skin['joints'])};bones=[next(k for k,x in enumerate(j['nodes']) if x.get('name')==f'Part_{i:02d}') for i in range(11)]
 idle=next(c for c in M['clips'] if c['source_address']=='0x801aff18');rest=M['poses'][idle['frames'][0]['pose']];invrests=[np.linalg.inv(source_matrix(p)) for p in rest['parts']];clips={c['name']:c for c in M['clips']};err=0.;checks=0
 for animation in j['animations']:
  tracks=[]
  for ch in animation['channels']:
   sm=animation['samplers'][ch['sampler']];assert sm.get('interpolation')=='STEP';tracks.append((ch['target']['node'],ch['target']['path'],ac(sm['input'])[:,0].tolist(),ac(sm['output'])));
  for frame in clips[animation['name']]['frames']:
   tm=frame['tick']/30;mods={(no,prop):values[max(0,bisect.bisect_right(times,tm+1e-6)-1)] for no,prop,times,values in tracks};cache={}
   def world(no):
    if no not in cache:cache[no]=(world(parents[no]) if no in parents else np.eye(4))@local(no,mods)
    return cache[no]
   for i,no in enumerate(bones):
    actual=world(no)@joint_to_bind[no];expected=source_matrix(M['poses'][frame['pose']]['parts'][i])@invrests[i];err=max(err,float(np.max(np.abs(actual-expected))));checks+=1
 assert err<1e-5,err
 return {'variant':ident,'glb_source_skin_matrix_checks':checks,'max_matrix_error':err,'all_clips_step':True}
report=[run(i) for i in [1,2,3]];print(json.dumps(report,indent=2));O=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Soldiers');(O/'source_glb_roundtrip.json').write_text(json.dumps(report,indent=2))
