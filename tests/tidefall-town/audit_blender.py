"""Read-only validation of the saved original Blender kit."""
import bpy
from pathlib import Path
root=Path(__file__).resolve().parents[2]
for path in sorted((root/'assets/blender/town').glob('*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert {o.name for o in meshes} == {'Body','Roof'}, path
    for o in meshes:
        assert all(abs(v-1)<1e-5 for v in o.scale), (path,o.name,'scale')
        assert o.data.uv_layers and o.data.materials, (path,o.name,'UV/material')
    images=[n.image for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert images and all(i.packed_file for i in images), (path,'packed textures')
    assert (root/'assets/models/town'/f'{path.stem}.glb').is_file()
    print('TOWN_BLEND_PASS',path.stem,'meshes',len(meshes),'packed_images',len(images))
