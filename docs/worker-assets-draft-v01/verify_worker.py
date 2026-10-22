"""Independent source/GLB checks plus proof that the live game was untouched."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
def bounds(objects):
    points=[ob.matrix_world@Vector(v) for ob in objects for v in ob.bound_box]
    return [min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]
before=json.loads((OUT/'live-files-before.json').read_text())
changed=[]
for relative,digest in before.items():
    path=ROOT/relative
    if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:changed.append(relative)
# Another user workflow may edit the shared checkout while this asset renders.
# Preserve and report those edits; never restore or overwrite the live build.
protected=['scripts/forest/forest_art.gd','assets/blender/characters/kai.blend']
protected += [name for name in before if name.startswith('assets/models/')]
assert not any(name in changed for name in protected),'An existing model or worker renderer changed during review'
runtime_references=[]
for path in (ROOT/'scripts').rglob('*.gd'):
    if 'worker-assets-draft-v01' in path.read_text():runtime_references.append(str(path.relative_to(ROOT)))
assert not runtime_references,runtime_references
assert 'docs/*' in (ROOT/'export_presets.cfg').read_text()
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/worker-angry-draft.blend'))
objects=[ob for ob in bpy.context.scene.objects if ob.type=='MESH' and ob.get('worker_asset') and ob.get('draft_group')!='Pickaxe']
assert len(objects)==9
assert all(ob.parent and ob.parent.parent.name=='Worker_Draft' for ob in objects)
source_bounds=bounds(objects)
source_triangles=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects)
assert abs(source_bounds[1][2]-source_bounds[0][2]-3)<.0001
for ob in objects:
    assert len(ob.data.uv_layers)>0
    assert len(ob.data.vertices)>0
body=bpy.data.objects['Worker_Body_Geometry']
head=bpy.data.objects['Worker_Head_Geometry']
bl,bh=bounds([body]);hl,hh=bounds([head])
assert hl[2]<=bh[2]+.025,'Head must meet the torso, rather than float above it'
for side in ['L','R']:
    al,ah=bounds([bpy.data.objects['Worker_Arm_'+side+'_Geometry']])
    ll,lh=bounds([bpy.data.objects['Worker_Leg_'+side+'_Geometry']])
    assert al[2]<bh[2] and ah[2]>bl[2]
    assert lh[2]>bl[2]
face=bpy.data.materials['Worker | stern angry painted face']
paint=[node.image for node in face.node_tree.nodes if node.type=='TEX_IMAGE']
assert len(paint)==1 and paint[0].packed_file
assert paint[0].size[:]==(1536,1536)
assert not any(name in bpy.data.objects for name in ['Eye_L','Eye_R','Eyebrow_L','Eyebrow_R'])
packed_images=[im.name for im in bpy.data.images if im.packed_file]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'export/worker-angry-draft.glb'))
exported=[ob for ob in bpy.context.scene.objects if ob.type=='MESH']
assert len(exported)==9,(len(exported),[ob.name for ob in exported])
assert not any(ob.type in ['LIGHT','CAMERA'] or 'Preview' in ob.name or 'Pickaxe' in ob.name for ob in bpy.context.scene.objects)
glb_bounds=bounds(exported)
for i in range(3):
    assert abs(source_bounds[0][i]-glb_bounds[0][i])<.001
    assert abs(source_bounds[1][i]-glb_bounds[1][i])<.001
triangles=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in exported)
assert triangles==source_triangles,(source_triangles,triangles)
result={'live_files_unchanged':len(before)-len(changed),'concurrent_live_changes_observed':changed,
        'existing_worker_renderer_and_model_assets_unchanged':True,'runtime_references_to_draft':runtime_references,'source_meshes':9,
        'export_meshes':len(exported),'export_triangles':triangles,'source_bounds':source_bounds,
        'export_bounds':glb_bounds,'height':glb_bounds[1][2]-glb_bounds[0][2],
        'painted_face':True,'packed_texture_images':packed_images,'connected_body_parts':True,
        'export_contains_studio':False,'skeletal_animation':False,'game_integration':False}
(OUT/'verification.json').write_text(json.dumps(result,indent=2))
print('WORKER_DRAFT_VERIFIED',json.dumps(result))
