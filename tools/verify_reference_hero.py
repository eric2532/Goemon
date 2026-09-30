"""Blender --background assets/blender/characters/kai.blend --python tools/verify_reference_hero.py"""
import bpy,hashlib
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
v=[];uv=[];faces=[]
for line in (ROOT/'assets/references/goemon_original/Goe/goe.obj').read_text().splitlines():
    t=line.split()
    if not t:continue
    if t[0]=='v':v.append(tuple(map(float,t[1:4])))
    elif t[0]=='vt':uv.append(tuple(map(float,t[1:3])))
    elif t[0]=='f':faces.append([tuple(int(a) for a in part.split('/')[:2]) for part in t[1:]])
scale=3.3/194.7548
def point(p):return (-p[0]*scale,p[2]*scale,(p[1]+.2312)*scale)
def key(corners):return tuple(sorted(tuple(round(a,4) for a in p+tex) for p,tex in corners))
expected=[[(point(v[vi-1]),uv[ti-1]) for vi,ti in f] for f in faces]
actual=[]
for name in ('Skin','Hair_Normal'):
    o=bpy.data.objects[name];mesh=o.data
    for f in mesh.polygons:
        actual.append([(tuple(mesh.vertices[mesh.loops[i].vertex_index].co),tuple(mesh.uv_layers.active.data[i].uv)) for i in f.loop_indices])
# Float32 OBJ import can straddle a rounding boundary, so compare with tolerance.
def same(a,b):
    return len(a)==len(b) and all(any(max(abs(x-y) for x,y in zip(p+uv,q+vt))<.00001 for q,vt in b) for p,uv in a)
for f in expected:
    found=next((i for i,g in enumerate(actual) if same(f,g)),None)
    assert found is not None,'Original triangle or UV corners changed beyond 0.00001 tolerance'
    actual.pop(found)
assert not actual,'Unexpected added triangles'
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for name in ('Skin','Hair_Normal','Hair_Gold'):
    o=bpy.data.objects[name]
    assert all(abs(sum(g.weight for g in v.groups)-1)<.001 for v in o.data.vertices),name+' unweighted vertices'
    assert any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)
assert len(rig.data.bones)==22
assert len(rig.animation_data.nla_tracks)==24
original=(ROOT/'assets/references/goemon_original/Goe/goe128_2.png').read_bytes()
assert hashlib.sha256(original).digest()==hashlib.sha256((ROOT/'assets/textures/characters/goemon_original.png').read_bytes()).digest(),'Original atlas changed'
packed=[i for i in bpy.data.images if i.packed_file and 'goe' in i.name.lower()]
assert packed and any(hashlib.sha256(i.packed_file.data).digest()==hashlib.sha256(original).digest() for i in packed),'Packed original atlas changed'
print('REFERENCE_TEXTURE_PASS: original PNG and packed Blender atlas are byte-identical')
print('REFERENCE_GEOMETRY_PASS: all',len(faces),'original triangles and UV corners preserved under uniform scale/orientation; all vertices weighted; twenty-two articulated bones; twenty-four clips.')
