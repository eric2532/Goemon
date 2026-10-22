"""Build a non-destructive skinned game derivative from the locked visual master."""
import bpy, math, os, hashlib, json
from mathutils import Vector, Matrix
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER=ROOT+'/assets/blender/enemies/musashi/Final/Musashi_Final.blend'
OUT=ROOT+'/assets/characters/musashi'
bpy.ops.wm.open_mainfile(filepath=MASTER)
sha=hashlib.sha256(open(MASTER,'rb').read()).hexdigest()
meshes=[o for o in bpy.data.objects if o.type=='MESH']
# Bake the authored paint rather than replacing it with approximate flat colors.
for mat in list(bpy.data.materials):
 if not mat.use_nodes: continue
 ns=mat.node_tree.nodes; links=mat.node_tree.links
 out=next((n for n in ns if n.type=='OUTPUT_MATERIAL' and n.is_active_output),None)
 if not out or not out.inputs['Surface'].is_linked: continue
 shader=out.inputs['Surface'].links[0].from_node
 if shader.type=='BSDF_PRINCIPLED':
  emit=ns.new('ShaderNodeEmission'); source=shader.inputs['Base Color']
  if source.is_linked: links.new(source.links[0].from_socket,emit.inputs['Color'])
  else: emit.inputs['Color'].default_value=source.default_value
  links.new(emit.outputs[0],out.inputs['Surface'])
# Skeleton uses the existing assembly's actual asymmetric joint positions.
joints={'Root':((0,0,0),None),'Hips':((0,.22,3.25),'Root'),'Chest':((.08,.20,4.50),'Hips'),'Head':((.14,.12,5.48),'Chest')}
for side,x,ank in [('L',-.52,(-1.07,1.25,1.02)),('R',.60,(.49,-.02,1.02))]:
 joints.update({f'Arm_{side}':((x,.12,4.9),'Chest'),f'Forearm_{side}':((-.87 if side=='L' else .95,.08,3.92),f'Arm_{side}'),f'Hand_{side}':((-.94 if side=='L' else .97,-.04,2.95),f'Forearm_{side}'),f'Leg_{side}':((-.48 if side=='L' else .38,.25,3.18),'Hips'),f'Shin_{side}':((-.83 if side=='L' else .46,.7 if side=='L' else .02,2.15),f'Leg_{side}'),f'Foot_{side}':(ank,f'Shin_{side}')})
def blend(a,b,t): return {a:1-t,b:t}
def weights(name,p):
 z=p.z; side=name[:1]
 if any(k in name for k in ['Hair','Head','ear','eye','iris','pupil','lid','Mouth','Nose','under_eye']):return {'Head':1}
 if name=='Neck':return blend('Chest','Head',max(0,min(1,(z-5.1)/.4)))
 if side in 'LR' and any(k in name for k in ['sleeve','flame','hand']):
  if 'hand' in name:return {f'Hand_{side}':1}
  if z>=4.25:return {f'Arm_{side}':1}
  if z>=3.55:return blend(f'Forearm_{side}',f'Arm_{side}',(z-3.55)/.7)
  if z>=3.12:return {f'Forearm_{side}':1}
  return blend(f'Hand_{side}',f'Forearm_{side}',max(0,min(1,(z-2.91)/.21)))
 if side in 'LR' and any(k in name for k in ['wrap','ankle','shoe']):return {f'Foot_{side}':1}
 if 'Trousers' in name:
  if z>=3.0:return {'Hips':1}
  side='L' if p.x<-.20 else 'R'
  if z>=2.6:return blend(f'Leg_{side}','Hips',(z-2.6)/.4)
  if z>=2.3:return {f'Leg_{side}':1}
  if z>=1.8:return blend(f'Shin_{side}',f'Leg_{side}',(z-1.8)/.5)
  return {f'Shin_{side}':1}
 return blend('Hips','Chest',max(0,min(1,(z-3.4)/.8)))
for o in meshes:
 groups={n:o.vertex_groups.new(name=n) for n in joints}
 for v in o.data.vertices:
  for n,w in weights(o.name,v.co).items():
   if w>0:groups[n].add([v.index],w,'REPLACE')
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.join(); obj=bpy.context.object;obj.name='Musashi_Approved_Surface'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003);bpy.ops.object.mode_set(mode='OBJECT')
img=bpy.data.images.new('Musashi_Painted_Atlas',width=4096,height=4096,alpha=False)
for mat in obj.data.materials:
 node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=img;mat.node_tree.nodes.active=node
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.bake.margin=12
bpy.ops.object.bake(type='EMIT')
img.filepath_raw=OUT+'/materials/musashi_painted.png';img.file_format='PNG';img.save()
mat=bpy.data.materials.new('Musashi_Approved_Paint');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1;bs.inputs['Specular IOR Level'].default_value=.025
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
obj.data.materials.clear();obj.data.materials.append(mat)
for p in obj.data.polygons:p.material_index=0
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='Musashi_Rig'
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for n,(co,parent) in joints.items():
 b=rig.data.edit_bones.new(n);b.head=co;b.tail=Vector(co)+Vector((0,0,.3))
 if parent:b.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
mod=obj.modifiers.new('Approved_Surface_Skin','ARMATURE');mod.object=rig;obj.parent=rig
# Orient forward to Godot -Z; uniform conversion preserves the complete design.
conversion=Matrix.Rotation(math.pi,4,'Z')@Matrix.Scale(.30,4)
obj.parent=None
obj.data.transform(conversion);rig.data.transform(conversion);obj.parent=rig
for o in list(bpy.data.objects):
 if o not in [obj,rig]:bpy.data.objects.remove(o,do_unlink=True)
# Fully editable neutral clip; gameplay owns layered procedural choreography.
rig.animation_data_create();action=bpy.data.actions.new('Approved_Rest');rig.animation_data.action=action
for b in rig.pose.bones:
 b.rotation_mode='XYZ';b.keyframe_insert('rotation_euler',frame=1);b.keyframe_insert('rotation_euler',frame=30)
scene.frame_start=1;scene.frame_end=30;scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
# Convert reference-view side names to anatomical game-side names.
for b in rig.data.bones:
 if b.name.endswith(('_L','_R')):b.name=b.name[:-2]+('_TEMP_R' if b.name.endswith('_L') else '_TEMP_L')
for b in rig.data.bones:
 if '_TEMP_' in b.name:b.name=b.name.replace('_TEMP_','_')
img.pack();bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/blender/enemies/musashi/Musashi_Playable.blend')
bpy.ops.export_scene.gltf(filepath=OUT+'/model/musashi.glb',export_format='GLB',use_selection=True,export_animations=True,export_skins=True,export_yup=True)
json.dump({'master_sha256':sha,'master_unchanged':sha==hashlib.sha256(open(MASTER,'rb').read()).hexdigest(),'vertices':len(obj.data.vertices),'bones':len(joints),'paint':'4096x4096 emission bake of approved shader colors','scale':.30},open(ROOT+'/tests/musashi/asset-build.json','w'),indent=2)
