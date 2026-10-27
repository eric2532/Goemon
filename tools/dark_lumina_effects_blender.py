"""Prepare a missing effects master, or export its three named source meshes."""
import json
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from recovered_enemy_blender import fingerprint
SOURCE=ROOT/'assets/characters/recovered_monsters/dark_lumina_2_effects'
MASTER=ROOT/'assets/blender/enemies/recovered_monsters/dark_lumina_2_effects.blend'
OUT=ROOT/'assets/models/enemies/recovered_monsters/dark_lumina_2_effects'
NAMES=['shock_dome','shock_ring','fragment']
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if '--stomp' in args:
    MASTER=MASTER.with_name('dark_lumina_2_stomp.blend')
    NAMES=['stomp_wave']
if '--prepare' in args:
    if MASTER.exists():raise RuntimeError('Preserve existing effects master; open it to edit/export.')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name in NAMES:
        bpy.ops.import_scene.gltf(filepath=str(SOURCE/(name+'.glb')))
        mesh=next(o for o in bpy.context.selected_objects if o.type=='MESH');mesh.name=name
        mesh['rom_geometry_fingerprint']=fingerprint(mesh)
    bpy.context.scene.render.fps=30
    bpy.context.scene['source']='Retail SC07 FILE_002 actor 0x352; nineteen source sectors.' if '--stomp' in args else 'Retail SC07 FILE_003 module 0x72; raw source dimensions, runtime scale .018.'
    bpy.context.scene['sprite_source']=str(SOURCE)
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
else:
    if Path(bpy.data.filepath)!=MASTER:raise RuntimeError('Open the existing Dark Lumina 2 effects master first.')
    OUT.mkdir(parents=True,exist_ok=True);report={}
    for name in NAMES:
        ob=bpy.data.objects[name];unchanged=fingerprint(ob)==ob['rom_geometry_fingerprint'] and all(abs(ob.matrix_world[r][c]-Matrix.Identity(4)[r][c])<1e-7 for r in range(4) for c in range(4))
        if unchanged:shutil.copyfile(SOURCE/(name+'.glb'),OUT/(name+'.glb'))
        else:
            bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
            bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
        report[name]={'original_geometry':unchanged,'master':str(MASTER.relative_to(ROOT))}
    (OUT/('stomp_export.json' if '--stomp' in args else 'export.json')).write_text(json.dumps(report,indent=2)+'\n')
    print('DARK_LUMINA_EFFECTS_EXPORTED',report)
