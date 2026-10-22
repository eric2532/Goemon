"""Install approved Pirate equipment, retaining exact shared body, UVs and rig.
Blender -b --python tools/build_pirate_design.py
Use --prepare-kit to bake the workbench's editable procedural weapon art first.
"""
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1]
KIT=ROOT/'assets/blender/weapons/pirate/approved-game-kit.blend'
QA=ROOT/'build/Other Files/Pirate Weapons/Runtime';QA.mkdir(parents=True,exist_ok=True)

def protected():
 return {n:hashlib.sha256(repr(([tuple(v.co) for v in bpy.data.objects[n].data.vertices],
  [tuple(u.uv) for u in bpy.data.objects[n].data.uv_layers.active.data],
  [[(g.group,g.weight) for g in v.groups] for v in bpy.data.objects[n].data.vertices])).encode()).hexdigest() for n in ['Skin','Hair_Normal']}

def prepare_kit():
 source=ROOT/'docs/pirate-motion-workbench/Pirate_Animation_Workbench.blend'
 bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.data.scenes['01 — Idle'];bpy.context.window.scene=scene
 scene.frame_set(0);bpy.context.view_layer.update()
 deps=bpy.context.evaluated_depsgraph_get();parts={};materials={}
 # Evaluate each object before joining to retain its authored bevels and curves.
 for name,prefix in [('Weapon_Cutlass','Cutlass |'),('Weapon_Pistol','Flintlock |')]:
  root=bpy.data.objects[name];parts[name]=[]
  inverse=root.matrix_world.inverted()
  for ob in root.children_recursive:
   if ob.type not in ['MESH','CURVE'] or not ob.name.startswith(prefix):continue
   mesh=bpy.data.meshes.new_from_object(ob.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
   mesh.transform(inverse@ob.matrix_world)
   parts[name].append(mesh)
   for mat in mesh.materials:materials[mat.name]=mat
 # Keep the material datablocks while discarding the four review scenes/rigs.
 for ob in list(bpy.data.objects):bpy.data.objects.remove(ob,do_unlink=True)
 scene.render.engine='CYCLES';scene.cycles.samples=1
 scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
 scene.render.bake.margin=8
 report={}
 for name,meshes in parts.items():
  root=bpy.data.objects.new(name,None);scene.collection.objects.link(root)
  objects=[]
  for mesh in meshes:
   ob=bpy.data.objects.new('Runtime part',mesh);scene.collection.objects.link(ob);objects.append(ob)
  bpy.ops.object.select_all(action='DESELECT')
  for ob in objects:ob.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();ob=bpy.context.object
  ob.name=name+'_Geometry';ob.parent=root;ob.matrix_basis=Matrix.Identity(4)
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.006);bpy.ops.object.mode_set(mode='OBJECT')
  for i,mat in enumerate(list(ob.data.materials)):ob.data.materials[i]=mat.copy()
  image=bpy.data.images.new(name+'_Approved_BaseColor',width=1024,height=1024,alpha=False)
  for mat in ob.data.materials:
   mat.use_nodes=True
   node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.nodes.active=node
   shader=mat.node_tree.nodes.get('Principled BSDF');emission=mat.node_tree.nodes.new('ShaderNodeEmission')
   color=shader.inputs['Base Color'];emission.inputs['Color'].default_value=color.default_value
   if color.links:mat.node_tree.links.new(color.links[0].from_socket,emission.inputs['Color'])
   mat.node_tree.links.new(emission.outputs[0],mat.node_tree.nodes.get('Material Output').inputs['Surface'])
  bpy.ops.object.bake(type='EMIT')
  image.filepath_raw=str(KIT.parent/(name.lower()+'_basecolor.png'));image.file_format='PNG';image.save();image.pack()
  for mat in ob.data.materials:
   shader=mat.node_tree.nodes.get('Principled BSDF')
   tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image==image)
   mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
   mat.node_tree.links.new(shader.outputs[0],mat.node_tree.nodes.get('Material Output').inputs['Surface'])
   for link in list(shader.inputs['Normal'].links):mat.node_tree.links.remove(link)
  # Blender uses vertex normals for the final bevel shading; glTF emits triangles.
  report[name]={'vertices':len(ob.data.vertices),'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons),'materials':len(ob.data.materials)}
 scene['pirate_kit']='Approved sword 2.2x, gun 1.8x; physical sizes baked once around native grips.'
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(KIT))
 (QA/'kit.json').write_text(json.dumps(report,indent=2)+'\n');print('PIRATE_KIT_READY',report)

def apply_design():
 before=protected();rig=bpy.data.objects['Reference_Rig'];native={}
 for name in ['Weapon_Cutlass','Weapon_Pistol']:
  root=bpy.data.objects[name];native[name]=root.matrix_world.copy()
  for child in list(root.children_recursive):bpy.data.objects.remove(child,do_unlink=True)
  bpy.data.objects.remove(root,do_unlink=True)
 with bpy.data.libraries.load(str(KIT),link=False) as (src,dst):
  dst.objects=[n for n in src.objects if n in ['Weapon_Cutlass','Weapon_Pistol','Weapon_Cutlass_Geometry','Weapon_Pistol_Geometry']]
 for ob in dst.objects:
  bpy.context.scene.collection.objects.link(ob)
  if ob.name in native:
   ob.parent=bpy.data.objects['Driver_Arm_'+('R' if ob.name=='Weapon_Cutlass' else 'L')]
   ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_world=native[ob.name]
   ob.scale*=1/1.15 # Actor applies the common readability multiplier once.
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 rig.animation_data_clear();bpy.context.view_layer.update()
 assert protected()==before,'Shared body geometry, weights or UVs changed'
 assert len(rig.data.bones)==22,'Native skeleton changed'
 bpy.context.scene['pirate_design']='Approved octopus cutlass + walnut/brass flintlock; authored poses in pirate_approved.json'
 return before

if __name__=='__main__':
 if '--prepare-kit' in sys.argv:prepare_kit()
 live=ROOT/'assets/blender/characters/goemon_cosplay/pirate.blend'
 bpy.ops.wm.open_mainfile(filepath=str(live));before=apply_design()
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(live))
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/characters/goemon_cosplay/pirate.glb'),export_format='GLB',use_selection=True,export_animations=False,export_yup=True,export_skins=True,export_materials='EXPORT',export_extras=True)
 (QA/'preservation.json').write_text(json.dumps({'shared_geometry_uv_weights':before,'rig_bones':22,'approved_sizes':{'sword':2.2,'gun':1.8}},indent=2)+'\n')
 print('PIRATE_APPROVED_DESIGN_EXPORTED')
