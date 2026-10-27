"""One-time editable workbenches for recovered rigid enemies; never overwrites."""
from pathlib import Path
import bpy,sys

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/blender/enemies/recovered_monsters'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'tools'))
from recovered_enemy_blender import fingerprint, morph_fingerprint
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for recovered in sorted((ROOT/'assets/characters/recovered_monsters').glob('*.glb')):
    name=recovered.stem
    if selected and name not in selected:continue
    target=OUT/(name+'.blend')
    if target.exists():
        print('Preserving existing editable master:',target)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps=30
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/recovered_monsters'/(name+'.glb')))
    scene=bpy.context.scene;scene.render.fps=30
    scene['source_motion_manifest']='res://assets/characters/recovered_monsters/'+name+'_motion.json'
    scene['export_tool']='tools/export_recovered_monster.py'
    for ob in scene.objects:
        if ob.type=='MESH':
            ob['rom_part']=ob.name;ob['rom_geometry_fingerprint']=fingerprint(ob)
            if ob.data.shape_keys:ob['rom_morph_fingerprint']=morph_fingerprint(ob)
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(target))
