"""Export edited .blend sources without rebuilding any geometry.
Blender --background assets/blender/characters/kai.blend --python tools/export_blender.py
Blender --background --python tools/export_blender.py -- --all
"""
import bpy, sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def export_current():
    source=Path(bpy.data.filepath).resolve()
    relative=source.relative_to(ROOT/'assets/blender')
    if 'musashi' in relative.parts:
        if source.name!='Musashi_Playable.blend':
            print('SKIP_LOCKED_VISUAL_MASTER',relative)
            return
        output=ROOT/'assets/characters/musashi/model/musashi.glb'
    else:
        output=ROOT/'assets/models'/relative.with_suffix('.glb')
    assert bpy.context.scene.unit_settings.scale_length==1, 'Use metres, scale_length = 1'
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert meshes, 'No mesh objects in source'
    for o in meshes:
        assert all(abs(s-1)<.001 for s in o.scale), f'Apply mesh scale before export: {o.name}'
        assert o.data.uv_layers, f'Missing UVs: {o.name}'
        # UV-textured reference meshes and simple exported materials are valid too.
        assert o.data.materials, f'Missing game material: {o.name}'
    tracks=[];hidden=[]
    for o in bpy.context.scene.objects:
        hidden.append((o,o.hide_get()));o.hide_set(False)
        if o.type=='ARMATURE' and o.animation_data:
            for track in o.animation_data.nla_tracks:
                tracks.append((track,track.mute));track.mute=False
    output.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        if not o.get('export_exclude',False): o.select_set(True)
    bpy.ops.export_scene.gltf(use_selection=True,export_cameras=False,export_lights=False,filepath=str(output),export_format='GLB',export_yup=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,
        export_skins=True,export_apply=False)
    for track,muted in tracks:track.mute=muted
    for o,state in hidden:o.hide_set(state)
    entry={'asset':str(relative.with_suffix('')),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),
        'meshes':len(meshes),'surfaces':sum(len(o.data.materials) for o in meshes),'bytes':output.stat().st_size}
    manifest=ROOT/'assets/models/manifest.json'
    entries=json.loads(manifest.read_text()) if manifest.exists() else []
    entries=[e for e in entries if e['asset']!=entry['asset']]+[entry]
    manifest.write_text(json.dumps(sorted(entries,key=lambda e:e['asset']),indent=2))
    print('VERIFIED_EXPORT',relative,entry)
if '--all' in sys.argv:
    for source in sorted((ROOT/'assets/blender').rglob('*.blend')):
        bpy.ops.wm.open_mainfile(filepath=str(source))
        export_current()
else:
    export_current()
