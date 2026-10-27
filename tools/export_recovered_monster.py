"""Export the OPEN saved rigid enemy master; preserve the immutable disc recovery.

Blender --background path/to/enemy.blend --python tools/export_recovered_monster.py
Then refresh Godot imports and run tools/bake_recovered_monsters.gd.
"""
from pathlib import Path
import hashlib
import json
import math
import sys
import copy
import bpy

ROOT=Path(__file__).resolve().parents[1]
source=Path(bpy.data.filepath).resolve()
assert source.parent in [ROOT/'assets/blender/enemies/recovered_monsters',ROOT/'assets/blender/characters/kojiro'],'Open a saved recovered rigid master first'
name=source.stem
original=ROOT/('assets/characters/recovered_kojiro' if name=='kojiro' else 'assets/characters/recovered_monsters')/(name+'_motion.json')
metadata=json.loads(original.read_text())
parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert sorted(o.name for o in parts)==[f'Part_{i:02d}' for i in range(len(metadata['parts']))],'Preserve the rigid part names and count'
sys.path.insert(0,str(ROOT/'tools'))
from recovered_enemy_blender import fingerprint, morph_fingerprint
unchanged=all(ob.get('rom_geometry_fingerprint')==fingerprint(ob) and (not ob.get('rom_morph_fingerprint') or ob['rom_morph_fingerprint']==morph_fingerprint(ob)) for ob in parts)
out=ROOT/('assets/models/characters/kojiro' if name=='kojiro' else 'assets/models/enemies/recovered_monsters');out.mkdir(parents=True,exist_ok=True)
path=out/(name+'.glb')
bpy.ops.object.select_all(action='DESELECT')
for ob in bpy.context.scene.objects:
    if ob.type in ('MESH','EMPTY','ARMATURE'):ob.hide_set(False);ob.select_set(True)
bpy.context.scene.render.fps=30
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_cameras=False,
    export_lights=False,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=False,
    export_optimize_animation_size=False,export_vertex_color='NAME',export_vertex_color_name='Color',
    export_apply=False,export_yup=True,export_extras=True)
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
glb=GLB.read(path);by_name={c['name']:c for c in metadata['clips']};clips=[];times={}
for animation in glb.doc['animations']:
    for sampler in animation['samplers']:
        index=sampler['input']
        if index not in times:
            # Snap numerical roundoff at authored ticks before Godot's STEP import.
            values=[(round(t[0]*30)/30 if abs(t[0]*30-round(t[0]*30))<.001 else t[0],) for t in glb.accessor(index)]
            times[index]=glb.append_accessor(values,dict(type='SCALAR',componentType=5126))
            glb.doc['accessors'][times[index]].update(min=[values[0][0]],max=[values[-1][0]])
        sampler['input']=times[index]
glb.compact();glb.write(path)
if unchanged:
    # Blender quantizes custom normals/byte colors even on a pose-only export.
    # Retain exact recovered mesh/paint bytes when the artist did not edit them.
    exact=GLB.read(original.with_name(name+'.glb'))
    source_nodes={n['name']:i for i,n in enumerate(exact.doc['nodes'])}
    authored_nodes={n['name']:n for n in glb.doc['nodes']}
    for node in exact.doc['nodes']:
        for key in ['translation','rotation','scale']:
            node.pop(key,None)
            if key in authored_nodes[node['name']]:node[key]=authored_nodes[node['name']][key]
    exact.doc['animations']=copy.deepcopy(glb.doc['animations'])
    for animation in exact.doc['animations']:
        for channel in animation['channels']:
            channel['target']['node']=source_nodes[glb.doc['nodes'][channel['target']['node']]['name']]
        for sampler in animation['samplers']:
            for key in ['input','output']:
                index=sampler[key];sampler[key]=exact.append_accessor(glb.accessor(index),glb.doc['accessors'][index])
                for bound in ['min','max']:
                    if bound in glb.doc['accessors'][index]:exact.doc['accessors'][sampler[key]][bound]=glb.doc['accessors'][index][bound]
    exact.compact();exact.write(path);glb=exact
for animation in glb.doc['animations']:
    duration=max(t[0] for sampler in animation['samplers'] for t in glb.accessor(sampler['input']))
    if animation['name'] in by_name:
        clip=dict(by_name[animation['name']])
    else:
        action=bpy.data.actions[animation['name']]
        clip=dict(name=animation['name'],authored=True,source_action=action.get('source_action',''),notes=action.get('player_adaptation',''))
    clip['ticks']=max(1,math.ceil(duration*30-1e-5))
    clip['frames']=[dict(tick=t,hold=1,pose=f'{clip["name"]}:{t}') for t in range(clip['ticks'])]
    clips.append(clip)
assert set(by_name)<={c['name'] for c in clips},'An original action disappeared from the edited master'
metadata.update(clips=clips,authored_source=str(source.relative_to(ROOT)),authored_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                recovery_manifest=str(original.relative_to(ROOT)),visual_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),exact_recovered_geometry=unchanged)
(out/(name+'_motion.json')).write_text(json.dumps(metadata,indent=2)+'\n')
print('RIGID_ENEMY_EXPORTED',path,'clips',len(clips),'exact_recovered_geometry',unchanged)
