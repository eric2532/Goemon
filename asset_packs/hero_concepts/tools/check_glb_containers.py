"""Check GLB framing and embedded resources without an external viewer."""
import json,struct,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[1];out=[]
for p in sorted((R/'glb').glob('*.glb')):
 b=p.read_bytes();magic,version,length=struct.unpack_from('<4sII',b);assert magic==b'glTF' and version==2 and length==len(b)
 n,kind=struct.unpack_from('<I4s',b,12);assert kind==b'JSON';d=json.loads(b[20:20+n]);off=20+n;bn,bk=struct.unpack_from('<I4s',b,off);assert bk==b'BIN\x00';data=b[off+8:off+8+bn]
 assert not d.get('animations') and not d.get('skins') and not d.get('cameras')
 assert all('uri' not in buf for buf in d.get('buffers',[]))
 assert all('bufferView' in im and 'uri' not in im for im in d.get('images',[]))
 assert not any('Ground' in x.get('name','') or 'STUDIO' in x.get('name','') for x in d.get('nodes',[]))
 for view in d.get('bufferViews',[]):assert view.get('byteOffset',0)+view['byteLength']<=len(data)
 for nd in d.get('nodes',[]):
  if 'mesh' in nd:assert 0<=nd['mesh']<len(d['meshes'])
 out.append(dict(name=p.stem,status='PASS',sha256=hashlib.sha256(b).hexdigest(),mesh_count=len(d['meshes']),node_count=len(d['nodes']),embedded_images=len(d.get('images',[])),external_resources=0,animations=0,skins=0))
assert len(out)==10
(R/'validation'/'glb_portability.json').write_text(json.dumps(out,indent=2))
print('PASS: 10 GLB containers, embedded textures, no external resources, rigs, animations, cameras or studio objects.')
