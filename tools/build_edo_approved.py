"""Skinned derivative of the user-approved study 04. Never modifies visual masters."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/blender/characters/edo_study_v04/Edo_Study_v04.blend'
protected=[SOURCE,ROOT/'assets/blender/characters/kai.blend',ROOT/'assets/blender/enemies/musashi/Final/Musashi_Final.blend',ROOT/'assets/models/characters/edo_anime.glb']
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));sc=bpy.context.scene
obs=[o for o in sc.objects if o.type=='MESH' and not o.hide_render]
for o in obs:
 bpy.context.view_layer.objects.active=o
 for m in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=m.name)
 world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
 o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4)
low=min(v.co.z for o in obs for v in o.data.vertices);high=max(v.co.z for o in obs for v in o.data.vertices)
scale=2.1/(high-low)
# Names retain the native Godot animation contract. Source-view left becomes anatomical right.
joints={'Root':((0,0,0),None),'Hips':((0,.16,2.80),'Root'),'Chest':((0,.16,4.02),'Hips'),'Head':((0,.10,4.805),'Chest')}
for side,sign in [('R',-1),('L',1)]:
 joints.update({f'Arm_{side}':((sign*.80,.10,4.30),'Chest'),f'Forearm_{side}':((sign*1.00,-.14,3.44),f'Arm_{side}'),f'Hand_{side}':((sign*1.01,-.31,2.64),f'Forearm_{side}'),f'Leg_{side}':((sign*.45,.12,2.68),'Hips'),f'Shin_{side}':((sign*.51,.10,1.86),f'Leg_{side}'),f'Foot_{side}':((sign*.50,0,.86),f'Shin_{side}')})
def mix(a,b,t):
 t=max(0,min(1,t));return {a:1-t,b:t}
def weights(name,p):
 z=p.z
 if name.startswith(('Hair_','Head_','L_ear','R_ear')):return {'Head':1}
 if name=='Neck':return mix('Chest','Head',(z-4.52)/.32)
 if name.startswith(('L_','R_')):
  side='R' if name.startswith('L_') else 'L'
  if 'hand' in name:return {f'Hand_{side}':1}
  if any(k in name for k in ['sleeve','flame']):
   if z>=3.74:return {f'Arm_{side}':1}
   if z>=3.14:return mix(f'Forearm_{side}',f'Arm_{side}',(z-3.14)/.60)
   if z>=2.79:return {f'Forearm_{side}':1}
   return mix(f'Hand_{side}',f'Forearm_{side}',(z-2.50)/.29)
  if any(k in name for k in ['wrap','ankle','shoe']):return {f'Foot_{side}':1}
 if name=='Trousers_Baggy_Garment':
  if z>=2.72:return {'Hips':1}
  side='R' if p.x<0 else 'L'
  if z>=2.38:return mix(f'Leg_{side}','Hips',(z-2.38)/.34)
  if z>=2.10:return {f'Leg_{side}':1}
  if z>=1.62:return mix(f'Shin_{side}',f'Leg_{side}',(z-1.62)/.48)
  return {f'Shin_{side}':1}
 return mix('Hips','Chest',(z-3.03)/.70)
for o in obs:
 o.vertex_groups.clear();groups={n:o.vertex_groups.new(name=n) for n in joints}
 for v in o.data.vertices:
  for n,w in weights(o.name,v.co).items():
   if w>0:groups[n].add([v.index],w,'REPLACE')
 assert all(abs(sum(g.weight for g in v.groups)-1)<.00001 for v in o.data.vertices),o.name
for mat in list({m for o in obs for m in o.data.materials if m}):
 if not mat.use_nodes:continue
 ns=mat.node_tree.nodes;links=mat.node_tree.links
 output=next((n for n in ns if n.type=='OUTPUT_MATERIAL' and n.is_active_output),None)
 if not output or not output.inputs['Surface'].is_linked:continue
 shader=output.inputs['Surface'].links[0].from_node
 if shader.type!='BSDF_PRINCIPLED':continue
 emit=ns.new('ShaderNodeEmission');source=shader.inputs['Base Color']
 if source.is_linked:links.new(source.links[0].from_socket,emit.inputs['Color'])
 else:emit.inputs['Color'].default_value=source.default_value
 links.new(emit.outputs[0],output.inputs['Surface'])
bpy.ops.object.select_all(action='DESELECT')
for o in obs:o.select_set(True)
bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obj=bpy.context.object;obj.name='Edo_Approved_Surface'
uv=obj.data.uv_layers.new(name='Game_Bake_Atlas');obj.data.uv_layers.active=uv;uv.active_render=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.004);bpy.ops.object.mode_set(mode='OBJECT')
img=bpy.data.images.new('Edo_Approved_Paint',width=2048,height=2048,alpha=False)
for mat in obj.data.materials:
 node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=img;mat.node_tree.nodes.active=node
sc.render.engine='CYCLES';sc.cycles.samples=4;sc.render.bake.margin=8;bpy.ops.object.bake(type='EMIT')
paint=ROOT/'assets/textures/characters/edo_approved';paint.mkdir(exist_ok=True)
img.filepath_raw=str(paint/'paint.png');img.file_format='PNG';img.save();img.pack()
mat=bpy.data.materials.new('Edo_Approved_Paint');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.95;bs.inputs['Specular IOR Level'].default_value=.06
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
coords=[tuple(item.uv) for item in obj.data.uv_layers['Game_Bake_Atlas'].data]
while len(obj.data.uv_layers):obj.data.uv_layers.remove(obj.data.uv_layers[0])
uv=obj.data.uv_layers.new(name='Edo_Paint_UV')
for d,co in zip(uv.data,coords):d.uv=co
obj.data.uv_layers.active=uv;uv.active_render=True
node=mat.node_tree.nodes.new('ShaderNodeUVMap');node.uv_map=uv.name;mat.node_tree.links.new(node.outputs['UV'],tex.inputs['Vector'])
obj.data.materials.clear();obj.data.materials.append(mat)
for p in obj.data.polygons:p.material_index=0
while len(obj.data.color_attributes):obj.data.color_attributes.remove(obj.data.color_attributes[0])
bpy.ops.object.select_all(action='DESELECT');bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='Edo_Approved_Rig'
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for n,(co,parent) in joints.items():
 b=rig.data.edit_bones.new(n);b.head=co;b.tail=Vector(co)+Vector((0,0,.25))
 if parent:b.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
conversion=Matrix.Rotation(math.pi,4,'Z')@Matrix.Scale(scale,4)@Matrix.Translation((0,0,-low))
obj.data.transform(conversion);rig.data.transform(conversion);obj.parent=rig
mod=obj.modifiers.new('Edo_Game_Skin','ARMATURE');mod.object=rig
for other in list(bpy.data.objects):
 if other not in [obj,rig]:bpy.data.objects.remove(other,do_unlink=True)
sc['source_approved_study']='04';sc['art_direction']='Approved red flame jacket, compact Rogue proportions and fuller temple hair. Gameplay-owned motion.'
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/edo_approved.blend'))
path=ROOT/'assets/models/characters/edo_approved.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_skins=True,export_animations=False,export_yup=True,export_cameras=False,export_lights=False)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
report={'source_approved_study':'04','protected_sha256':hashes,'protected_sources_unchanged':True,'height_m':2.1,'bones':list(joints),'normalized_weights':True,'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'vertices':len(obj.data.vertices),'materials':1,'atlas_resolution':2048,'raw_to_game_scale':scale,'glb_bytes':path.stat().st_size}
(ROOT/'docs/edo-integrated/asset-validation.json').write_text(json.dumps(report,indent=2))
print('EDO_APPROVED_SKIN_EXPORTED',json.dumps(report),flush=True)
