"""Validate supplied gold hair triangles/UVs, packed atlas and head attachment in Blender."""
import bpy, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'assets/references/goemon_sudden_impact/SI_Goe'
vertices=[];uv=[];faces=[]
for line in (source/'SI_goe.obj').read_text().splitlines():
 t=line.split()
 if not t:continue
 if t[0]=='v':vertices.append(tuple(map(float,t[1:4])))
 elif t[0]=='vt':uv.append(tuple(map(float,t[1:3])))
 elif t[0]=='f':faces.append([tuple(int(n) for n in part.split('/')[:2]) for part in t[1:]])
# Source's first 240 vertices are the unchanged body. The final three islands
# are all above y=120; selecting connected islands excludes face polygons.
adj=[set() for _ in vertices]
for f in faces:
 ids={vi-1 for vi,ti in f}
 for vi in ids:adj[vi].update(ids)
seen=set();ids=set()
for i in range(len(vertices)):
 if i in seen:continue
 q=[i];seen.add(i);island=[]
 while q:
  j=q.pop();island.append(j)
  for k in adj[j]-seen:seen.add(k);q.append(k)
 if min(vertices[j][1] for j in island)>120:ids.update(island)
s=3.3/194.7548
def point(v):return (-v[0]*s,v[2]*s,(v[1]+.2312)*s)
expected=[[(point(vertices[vi-1]),uv[ti-1]) for vi,ti in f] for f in faces if all(vi-1 in ids for vi,ti in f)]
gold=bpy.data.objects['Hair_Gold'];mesh=gold.data
actual=[[(tuple(mesh.vertices[mesh.loops[i].vertex_index].co),tuple(mesh.uv_layers.active.data[i].uv)) for i in f.loop_indices] for f in mesh.polygons]
assert len(expected)==len(actual)==190
for f in expected:
 found=next((i for i,g in enumerate(actual) if len(f)==len(g) and all(any(max(abs(a-b) for a,b in zip(p+u,q+v))<.00001 for q,v in g) for p,u in f)),None)
 assert found is not None,'Supplied hair shape or UV changed'
 actual.pop(found)
assert all(len(v.groups)==1 and gold.vertex_groups[v.groups[0].group].name=='Head' and v.groups[0].weight==1 for v in mesh.vertices)
original=(source/'si_goe128.png').read_bytes()
assert (ROOT/'assets/textures/characters/goemon_sudden_impact.png').read_bytes()==original
assert any(n.type=='TEX_IMAGE' and n.image.packed_file and n.image.packed_file.data==original for n in mesh.materials[0].node_tree.nodes)
print('SUPPLIED_HAIR_PASS: all 190 source triangles/UVs and original packed atlas preserved; 110 vertices rigidly attached to existing Head bone')
