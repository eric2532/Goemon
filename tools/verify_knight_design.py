"""Independent Blender-source preservation and cloth pin validation."""
from pathlib import Path
import bpy
import hashlib
import json
ROOT=Path(__file__).resolve().parents[1]
def fingerprint(ob):
    payload={'vertices':[list(v.co) for v in ob.data.vertices],
             'faces':[list(p.vertices) for p in ob.data.polygons],
             'uv':[[list(v.uv) for v in layer.data] for layer in ob.data.uv_layers],
             'weights':[[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices]}
    return hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()
def read(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    return {n:fingerprint(bpy.data.objects[n]) for n in ['Skin','Hair_Normal']}, {
        b.name:[list(b.head_local),list(b.tail_local)] for b in bpy.data.objects['Reference_Rig'].data.bones}
before=ROOT/'build/Other Files/knight-integration/before/assets/blender/characters/goemon_cosplay/knight.blend'
old_meshes,old_bones=read(before)
meshes,bones=read(ROOT/'assets/blender/characters/goemon_cosplay/knight.blend')
assert meshes==old_meshes,'Shared Goemon geometry/UV/weights changed'
assert bones==old_bones,'Bone lengths/rest positions changed'
cape=bpy.data.objects['Knight_Long_Dark_Navy_Cape']
keys=cape.data.shape_keys.key_blocks
assert len(keys)==5
top=[i for i,v in enumerate(keys[0].data) if v.co.z>1.49]
assert len(top)==14
for key in list(keys)[1:]:
    assert all((key.data[i].co-keys[0].data[i].co).length<1e-7 for i in top),'Shoulders move with cloth'
assert not any(ob.type in ['LIGHT','CAMERA'] or ob.name=='Preview_Ground' for ob in bpy.data.objects)
texture=bpy.data.images.get('Knight flat lion shield paint')
packed=[im.name for im in bpy.data.images if im.packed_file]
result={'shared_geometry_uv_weights_preserved':meshes==old_meshes,'bone_rest_positions_preserved':bones==old_bones,
        'cloth_morphs':[k.name for k in list(keys)[1:]],'pinned_shoulder_vertices':len(top),'packed_images':packed}
out=ROOT/'docs/knight-integration/asset-verification.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(result,indent=2))
print('KNIGHT_ASSET_VERIFIED',json.dumps(result))
