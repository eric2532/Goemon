"""Add newly recovered morph keys to the existing finale FX master; preserve edits."""
import sys,json
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
from recovered_enemy_blender import fingerprint,morph_fingerprint
master=ROOT/'assets/blender/enemies/recovered_monsters/dark_lumina_3_effects.blend'
assert Path(bpy.data.filepath)==master
source=GLB.read(ROOT/'assets/characters/recovered_monsters/dark_lumina_3_effects.glb')
for node in source.doc['nodes']:
    if 'mesh' not in node:continue
    mesh=source.doc['meshes'][node['mesh']]
    if not mesh['primitives'][0].get('targets'):continue
    ob=bpy.data.objects[node['name']]
    if ob.data.shape_keys:
        print('Preserving existing morph edits',ob.name);continue
    assert fingerprint(ob)==ob['rom_geometry_fingerprint'],'Preserve edited geometry; add shape keys manually to this master'
    poses={};names=mesh['extras']['targetNames']
    for primitive in mesh['primitives']:
        points=source.accessor(primitive['attributes']['POSITION'])
        targets=[source.accessor(t['POSITION']) for t in primitive['targets']]
        for i,p in enumerate(points):
            poses[tuple(round(v,4) for v in (p[0],-p[2],p[1]))]=[(p[0]+t[i][0],-p[2]-t[i][2],p[1]+t[i][1]) for t in targets]
    ob.shape_key_add(name='Basis')
    for index,name in enumerate(names):
        key=ob.shape_key_add(name=name)
        for point,original in zip(key.data,ob.data.vertices):point.co=poses[tuple(round(v,4) for v in original.co)][index]
    ob['rom_morph_fingerprint']=morph_fingerprint(ob)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(master))
print('FINAL_MORPHS_PREPARED')
