"""Bake a single-surface crowd mesh; UV carries rigid limb IDs for GPU animation."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/enemies/ninja_far.glb'))
ids={'Leg_L':1,'Leg_R':2,'Arm_L':3,'Arm_R':4,'Head':5,'Sash':6}
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for o in meshes:
 bpy.context.view_layer.objects.active=o
 # Keep bind geometry, discard the rig after encoding the dominant bone.
 for modifier in list(o.modifiers):o.modifiers.remove(modifier)
 world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='Limb')
 for loop in o.data.loops:
  groups=o.data.vertices[loop.vertex_index].groups
  group=max(groups,key=lambda g:g.weight).group if groups else -1
  name=o.vertex_groups[group].name if group>=0 else 'Root'
  uv.data[loop.index].uv=(ids.get(name,0)/8,0)
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();o=bpy.context.object;o.name='CrowdNinja'
material=bpy.data.materials.new('CrowdColors');material.use_nodes=True
attribute=material.node_tree.nodes.new('ShaderNodeVertexColor');attribute.layer_name=o.data.color_attributes.active_color.name
material.node_tree.links.new(attribute.outputs['Color'],material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
o.data.materials.clear();o.data.materials.append(material)
for polygon in o.data.polygons:polygon.material_index=0
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/enemies/ninja_crowd.glb'),use_selection=True,export_format='GLB',export_skins=False,export_animations=False)
