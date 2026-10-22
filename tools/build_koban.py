"""Blender authoring for the reference's long rounded koban. Only replaces this asset."""
import bpy,bmesh,math,runpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
# Godot X/Y face, Z thickness; +Y Blender is the front of the exported coin.
N=64
outline=[]
for i in range(N):
 a=2*math.pi*i/N
 outline.append((.23*math.cos(a),.22*(1 if math.sin(a)>=0 else -1)+.23*math.sin(a)))
verts=[];faces=[];indices=[]
# Thin beveled metal body, shallow raised rim and inset face on both sides.
rings=[(.93,-.035),(.99,-.029),(1,-.014),(1,.014),(.99,.029),(.93,.035),(.90,.027)]
# Front face is also inset relative to its rim.
rings=[(.90,-.027)]+rings
for factor,z in rings:
 for x,y in outline:verts.append((x*factor,-z,y*factor))
for r in range(len(rings)-1):
 for i in range(N):
  faces.append((r*N+i,r*N+(i+1)%N,(r+1)*N+(i+1)%N,(r+1)*N+i));indices.append(1)
for r in (0,len(rings)-1):
 center=len(verts);verts.append((0,-rings[r][1],0))
 for i in range(N):faces.append((center,r*N+i,r*N+(i+1)%N));indices.append(0)
mesh=bpy.data.meshes.new('Koban_Beveled_Capsule');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Koban',mesh);scene.collection.objects.link(o)
for name,metal,rough in [('Engraved gold faces',.48,.44),('Rounded golden rim',.68,.30)]:
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 p.inputs['Base Color'].default_value=(.93,.55,.055,1)
 if len(mesh.materials)==0:
  for fname,socket in [('koban_color.png','Base Color'),('koban_normal.png','Normal')]:
   tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'assets/textures/weapons/koban'/fname));tex.image.pack()
   if socket=='Normal':
    tex.image.colorspace_settings.name='Non-Color';normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.7;m.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
   else:m.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
 mesh.materials.append(m)
for poly,idx in zip(mesh.polygons,indices):poly.material_index=idx;poly.use_smooth=idx==1
uv=mesh.uv_layers.new(name='Koban_Face_UV')
for poly in mesh.polygons:
 for li in poly.loop_indices:
  v=mesh.vertices[mesh.loops[li].vertex_index].co
  # Reverse face is readable rather than mirrored.
  uv.data[li].uv=(.5+v.x/.46*(1 if v.y>=0 else -1),.5+v.z/.90)
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
scene['asset_notes']='Reference-inspired thin oval koban: rounded ends, nearly straight sides, incised horizontal stripes, two rectangular stamps, rounded end seals. Gameplay origin/axes unchanged.'
bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/weapons/koban.blend'))
runpy.run_path(str(ROOT/'tools/export_blender.py'))
