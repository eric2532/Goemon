"""Compare the saved weapon-only Blender mesh and packed maps against supplied FBX."""
import bpy,zipfile,tempfile
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
archive=Path('/Users/eric/Downloads/Nintendo Switch - Super Smash Bros. Ultimate - Mii Costumes - Goemon Outfit (1).zip')
meshes=[o for o in bpy.data.objects if o.type=='MESH'];assert len(meshes)==1
assert not any(o.type=='ARMATURE' for o in bpy.data.objects)
weapon=meshes[0];assert weapon.name=='Golden_Pipe'
assert len(weapon.data.vertices)==910 and len(weapon.data.polygons)==1368
assert len(weapon.data.materials)==1 and weapon.scale==Vector((1,1,1))
with zipfile.ZipFile(archive) as z:
 for node in weapon.data.materials[0].node_tree.nodes:
  if node.type=='TEX_IMAGE':
   assert node.image.packed_file.data==z.read('Goemon Outfit/images/'+Path(node.image.filepath).name)
 with tempfile.TemporaryDirectory() as temp:
  f=Path(temp)/'body.fbx';f.write_bytes(z.read('Goemon Outfit/b_goemon_m.fbx'))
  before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(f));added=set(bpy.data.objects)-before
  source=next(o for o in added if o.name.startswith('MiiS_Sword_VIS_O_OBJShape'))
  center=Vector((-.15806772,.24106937,0))
  for v,w in zip(source.data.vertices,weapon.data.vertices):
   p=source.matrix_world@v.co-center;expected=Vector((p.y,p.z,p.x))*4.8
   assert (w.co-expected).length<.00001,'Source shape changed'
  assert [tuple(p.vertices) for p in source.data.polygons]==[tuple(p.vertices) for p in weapon.data.polygons]
  for a,b in zip(source.data.uv_layers.active.data,weapon.data.uv_layers.active.data):assert (a.uv-b.uv).length<.000001
  for o in added:bpy.data.objects.remove(o,do_unlink=True)
print('SUPPLIED_PIPE_PASS: original 910 vertices / 1368 triangles and UVs preserved; all four packed maps byte-identical; only one weapon mesh, no outfit or armature')
