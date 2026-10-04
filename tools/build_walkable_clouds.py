"""Flat-topped, soft-lobed cloud platforms, authored and exported in Blender."""
import bpy, math
from pathlib import Path
root=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
material=bpy.data.materials.new('Pearl cloud');material.diffuse_color=(.86,.94,1,1);material.use_nodes=True
bs=material.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.86,.94,1,1);bs.inputs['Roughness'].default_value=.95
for variant in range(2):
 n=64;vertices=[]
 for height,scale in [(0,1),(-.7,1.05),(-2.4,.85),(-3.5,.4)]:
  for i in range(n):
   a=i*math.tau/n;r=1+.07*math.cos(7*a+variant)+.035*math.sin(11*a)
   vertices.append((math.cos(a)*10*r*scale,math.sin(a)*4.6*r*scale,height))
 faces=[tuple(range(n))]
 for j in range(3):
  for i in range(n):faces.append((j*n+i,(j+1)*n+i,(j+1)*n+(i+1)%n,j*n+(i+1)%n))
 faces.append(tuple(reversed(range(3*n,4*n))))
 mesh=bpy.data.meshes.new('Cloud platform');mesh.from_pydata(vertices,[],faces);mesh.materials.append(material);mesh.update()
 obj=bpy.data.objects.new('Walkable billowing cloud',mesh);bpy.context.collection.objects.link(obj)
 for f in mesh.polygons:f.use_smooth=len(f.vertices)==4
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/sky_descent'/('cloud_platform_'+str(variant)+'.glb')),export_format='GLB',use_selection=True)
 obj.location.x=variant*26
bpy.ops.wm.save_as_mainfile(filepath=str(root/'assets/blender/sky_descent/Walkable_Clouds.blend'))
