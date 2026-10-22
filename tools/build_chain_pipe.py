"""Derive a chain pipe from the current supplied pipe; preserve the original master."""
from pathlib import Path
import bpy,bmesh,math,json,hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'assets/blender/weapons/golden_pipe.blend'
original_hash=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
original=bpy.data.objects['Golden_Pipe']
def cut_part(name,cut,keep_front):
 obj=original.copy();obj.data=original.data.copy();bpy.context.collection.objects.link(obj);obj.name=name
 bm=bmesh.new();bm.from_mesh(obj.data)
 result=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,cut,0),plane_no=(0,1,0),clear_inner=keep_front,clear_outer=not keep_front)
 border=[e for e in result['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_boundary]
 if border:bmesh.ops.holes_fill(bm,edges=border,sides=0)
 bm.to_mesh(obj.data);bm.free();obj.data.update()
 if keep_front:
  for v in obj.data.vertices:v.co.y-=cut
 return obj
handle=cut_part('Chain_Handle',.30,False)
head=cut_part('Chain_Head',.80,True);head.location.y=1.48
bpy.data.objects.remove(original,do_unlink=True)
metal=bpy.data.materials.new('Chain - warm forged gold');metal.use_nodes=True
bs=metal.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.52,.26,.055,1);bs.inputs['Metallic'].default_value=.88;bs.inputs['Roughness'].default_value=.28
bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,major_radius=.052,minor_radius=.014)
link=bpy.context.object;link.name='Chain_Link_00';link.scale.y=1.65
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);link.data.materials.append(metal)
for f in link.data.polygons:f.use_smooth=True
for i in range(13):
 obj=link if i==0 else bpy.data.objects.new('Chain_Link_%02d'%i,link.data)
 if i:bpy.context.collection.objects.link(obj)
 obj.location=(0,.32+i*.095,0);obj.rotation_euler.y=(i%2)*math.pi/2
# Joint eyes make the flexible connection explicit at each cut end.
for name,y in [('Handle_Attachment',.30),('Head_Attachment',1.48)]:
 bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,major_radius=.052,minor_radius=.017,location=(0,y,0))
 obj=bpy.context.object;obj.name=name;obj.data.materials.append(metal)
scene=bpy.context.scene;scene['asset_id']='weapons/chain_pipe';scene['derived_from']='weapons/golden_pipe.blend'
scene['construction']='Original painted handle and bowl, separated shaft, 13 alternating forged links with end eyes.'
scene['runtime_parts']='Chain_Handle and Chain_Head mesh origins at grip / head base; Chain_Link_00 shared link mesh.'
cam=scene.camera;cam.location=(3,-1.8,2.6);cam.rotation_euler=(Vector((0,.68,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.7
scene.render.film_transparent=False;scene.render.resolution_x=1100;scene.render.resolution_y=750
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/weapons/chain_pipe.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in scene.objects:
 if obj.type=='MESH':obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/weapons/chain_pipe.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False)
scene.render.filepath=str(ROOT/'tests/chain-pipe/blender-chain-pipe.png');bpy.ops.render.render(write_still=True)
assert hashlib.sha256(source.read_bytes()).hexdigest()==original_hash
report={'original_unchanged':True,'source_sha256':original_hash,'handle_vertices':len(handle.data.vertices),'head_vertices':len(head.data.vertices),'links':13,'link_vertices':len(link.data.vertices)}
(ROOT/'tests/chain-pipe/blender-report.json').write_text(json.dumps(report,indent=2));print(report)
