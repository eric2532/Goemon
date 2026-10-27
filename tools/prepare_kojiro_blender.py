"""Create Kojiro's editable rigid-part workbench once; preserve existing edits."""
from pathlib import Path
import sys
import bpy

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from recovered_enemy_blender import fingerprint

target=ROOT/'assets/blender/characters/kojiro/kojiro.blend'
if target.exists():
    print('Preserving existing master:',target)
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.render.fps=30
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/recovered_kojiro/kojiro.glb'))
    scene.render.fps=30
    scene['source_motion_manifest']='res://assets/characters/recovered_kojiro/kojiro_motion.json'
    scene['export_tool']='tools/export_recovered_monster.py'
    for ob in scene.objects:
        if ob.type=='MESH':ob['rom_part']=ob.name;ob['rom_geometry_fingerprint']=fingerprint(ob)
    text=bpy.data.texts.new('START HERE')
    text.write((target.parent/'AGENTS.md').read_text())
    scene.frame_set(1)
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(target))
