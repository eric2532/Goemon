"""Keep the default arrow scene exactly; remove unreachable glTF data and binary slices."""
import json,struct,pathlib,copy
p=pathlib.Path('/workspace/scratch/23f1a29e8f92/tower_assets_v1/exports/arrow_projectile.glb');raw=p.read_bytes();n,t=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+n]);pos=20+n;bn,bt=struct.unpack_from('<II',raw,pos);binary=raw[pos+8:pos+8+bn]
scene=copy.deepcopy(g['scenes'][g.get('scene',0)]);reachable=set()
def visit(i):
 if i in reachable:return
 reachable.add(i)
 for j in g['nodes'][i].get('children',[]):visit(j)
for i in scene['nodes']:visit(i)
nodeids=sorted(reachable);nodemap={v:i for i,v in enumerate(nodeids)};nodes=[copy.deepcopy(g['nodes'][i]) for i in nodeids]
meshid=sorted({n['mesh'] for n in nodes if 'mesh' in n});meshmap={v:i for i,v in enumerate(meshid)};meshes=[copy.deepcopy(g['meshes'][i]) for i in meshid]
accessid=set();materialid=set()
for m in meshes:
 for prim in m['primitives']:
  accessid.update(prim.get('attributes',{}).values())
  if 'indices' in prim:accessid.add(prim['indices'])
  if 'material' in prim:materialid.add(prim['material'])
  assert 'targets' not in prim
accessid=sorted(accessid);accessmap={v:i for i,v in enumerate(accessid)};accessors=[copy.deepcopy(g['accessors'][i]) for i in accessid]
viewids=sorted({a['bufferView'] for a in accessors});viewmap={v:i for i,v in enumerate(viewids)};views=[];outbin=bytearray()
for i in viewids:
 v=copy.deepcopy(g['bufferViews'][i]);assert v.get('buffer',0)==0
 outbin+=b'\0'*((-len(outbin))%4);start=v.get('byteOffset',0);chunk=binary[start:start+v['byteLength']];v['buffer']=0;v['byteOffset']=len(outbin);outbin+=chunk;views.append(v)
for a in accessors:
 assert 'sparse' not in a;a['bufferView']=viewmap[a['bufferView']]
matids=sorted(materialid);matmap={v:i for i,v in enumerate(matids)};materials=[copy.deepcopy(g['materials'][i]) for i in matids]
assert not g.get('textures') and not g.get('skins')
for m in meshes:
 for prim in m['primitives']:
  prim['attributes']={k:accessmap[v] for k,v in prim['attributes'].items()}
  if 'indices' in prim:prim['indices']=accessmap[prim['indices']]
  if 'material' in prim:prim['material']=matmap[prim['material']]
for n in nodes:
 if 'children' in n:n['children']=[nodemap[i] for i in n['children']]
 if 'mesh' in n:n['mesh']=meshmap[n['mesh']]
 assert 'skin' not in n and 'camera' not in n
scene['nodes']=[nodemap[i] for i in scene['nodes']]
new={'asset':g['asset'],'scene':0,'scenes':[scene],'nodes':nodes,'meshes':meshes,'materials':materials,'accessors':accessors,'bufferViews':views,'buffers':[{'byteLength':len(outbin)}]}
for k in ('extensionsUsed','extensionsRequired'):
 if k in g:new[k]=g[k]
js=json.dumps(new,separators=(',',':')).encode();js+=b' '*((-len(js))%4);outbin+=b'\0'*((-len(outbin))%4)
p.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(outbin))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(outbin),0x004E4942)+outbin)
assert len(nodes)==7 and len(meshes)==5
print('PRUNED_ARROW',len(raw),'->',p.stat().st_size,'bytes; 1 scene / 7 nodes / 5 meshes')
