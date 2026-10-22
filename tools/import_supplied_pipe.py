"""Extract only the supplied Goemon pipe, without importing the outfit into the project.
Blender --background --python tools/import_supplied_pipe.py
"""
import bpy,zipfile,tempfile,shutil,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
ARCHIVE=Path('/Users/eric/Downloads/Nintendo Switch - Super Smash Bros. Ultimate - Mii Costumes - Goemon Outfit (1).zip')
bpy.ops.wm.read_factory_settings(use_empty=True)
with tempfile.TemporaryDirectory(prefix='goemon-pipe-') as temp:
 temp=Path(temp)
 with zipfile.ZipFile(ARCHIVE) as z:
  (temp/'body.fbx').write_bytes(z.read('Goemon Outfit/b_goemon_m.fbx'))
  bpy.ops.import_scene.fbx(filepath=str(temp/'body.fbx'))
  weapon=bpy.data.objects['MiiS_Sword_VIS_O_OBJShape']
  assert len(weapon.data.polygons)==1368
  assert all(weapon.data.materials[p.material_index].name=='goemon_m_weapon_001' for p in weapon.data.polygons)
  # Bake the FBX bind transform, then rotate its shaft to Blender +Y (Godot -Z).
  # The open bowl points Blender +Z (Godot +Y). Origin lies on the thin hand grip.
  matrix=weapon.matrix_world.copy();scale=4.8;center=Vector((-.15806772,.24106937,0))
  imported_normals=[n.vector.copy() for n in weapon.data.corner_normals] if weapon.data.has_custom_normals else []
  normal_matrix=Matrix(((0,1,0),(0,0,1),(1,0,0)))@matrix.to_3x3().inverted().transposed()
  for v in weapon.data.vertices:
   p=matrix@v.co-center;v.co=Vector((p.y,p.z,p.x))*scale
  if imported_normals:weapon.data.normals_split_custom_set([(normal_matrix@n).normalized() for n in imported_normals])
  weapon.parent=None;weapon.matrix_world=Matrix.Identity(4);weapon.modifiers.clear();weapon.vertex_groups.clear()
  for o in list(bpy.data.objects):
   if o!=weapon:bpy.data.objects.remove(o,do_unlink=True)
  weapon.name='Golden_Pipe';weapon.data.name='Supplied_Goemon_Pipe'
  weapon.data.materials.clear()
  mat=bpy.data.materials.new('Supplied_Goemon_Pipe_Gold');mat.use_nodes=True
  weapon.data.materials.append(mat)
  for f in weapon.data.polygons:f.material_index=0
  nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes.get('Principled BSDF')
  textures=ROOT/'assets/textures/weapons/goemon_pipe';textures.mkdir(parents=True,exist_ok=True)
  for suffix,socket in [('col','Base Color'),('mtl','Metallic'),('rgh','Roughness'),('nor',None)]:
   filename='goemon_m_weapon_001_'+suffix+'.png';target=textures/filename;target.write_bytes(z.read('Goemon Outfit/images/'+filename))
   image=bpy.data.images.load(str(target),check_existing=False)
   if suffix!='col':image.colorspace_settings.name='Non-Color'
   image.pack();node=nodes.new('ShaderNodeTexImage');node.image=image;node.label=suffix
   if socket:links.new(node.outputs['Color'],bsdf.inputs[socket])
   else:
    normal=nodes.new('ShaderNodeNormalMap');links.new(node.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
# Remove unused outfit data as well as objects, including external image paths.
for _ in range(3):bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
scene['asset_id']='weapons/golden_pipe';scene['source_archive']=ARCHIVE.name
scene['source_mesh']='MiiS_Sword_VIS_O_OBJShape; 910 original vertices / 1368 triangles'
scene['geometry_policy']='Original topology/UVs; rigid reorientation and uniform scaling only. No outfit, body, head, or skeleton.'
scene['grip']='Origin in narrow lower shaft; +Y toward bowl; +Z bowl opening. Godot -Z forward, +Y up.'
# Editable camera/light setup for weapon inspection; normal exporter excludes it.
def studio(o):o['export_exclude']=True
bpy.ops.object.camera_add(location=(2.6,-1.7,2));cam=bpy.context.object;studio(cam);cam.rotation_euler=(Vector((0,.42,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.95;scene.camera=cam
for pos,power,size in [((2,-1,4),420,4),((-3,1,2),300,3)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;studio(o);o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,.4,0))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('Weapon_Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.7,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.view_settings.view_transform='Standard'
bpy.ops.object.select_all(action='DESELECT');weapon.select_set(True);bpy.context.view_layer.objects.active=weapon
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/weapons/golden_pipe.blend'))
scene.render.filepath=str(ROOT/'tests/supplied-pipe-source.png');bpy.ops.render.render(write_still=True)
print('SUPPLIED_PIPE_ONLY: 910 vertices, 1368 triangles, 1 material, 4 original 512px textures; no outfit objects or armature')
