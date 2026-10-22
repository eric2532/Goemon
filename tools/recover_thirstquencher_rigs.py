"""Blender companion: build ROM rigid-part rigs, held source actions, and verification."""
from pathlib import Path
import sys,json,math,struct,hashlib
import bpy
from mathutils import Matrix,Vector,Euler
OUT=Path(__file__).resolve().parent.parent/'assets/characters/thirstquencher'
C=Matrix(((1,0,0),(0,0,1),(0,-1,0)));S=.01

def transform(p):
 m=(C@Euler([a*math.tau/4096 for a in p['angles']],'XYZ').to_matrix()@C.transposed()).to_4x4();m.translation=C@Vector(p['position'])*S;return m

def curves(a):
 for layer in a.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:yield from bag.fcurves

def fix_times(path):
 data=path.read_bytes();n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n]);binary=bytearray(data[28+n:]);inputs={s['input'] for a in doc['animations'] for s in a['samplers']}
 for idx in inputs:
  ac=doc['accessors'][idx];v=doc['bufferViews'][ac['bufferView']];o=v.get('byteOffset',0)+ac.get('byteOffset',0);vs=list(struct.unpack_from('<'+'f'*ac['count'],binary,o));assert abs(vs[0]-1/30)<1e-6
  vs=[(round(x*30)-1)/30 for x in vs];struct.pack_into('<'+'f'*len(vs),binary,o,*vs);ac['min']=[min(vs)];ac['max']=[max(vs)]
 text=json.dumps(doc,separators=(',',':')).encode();text+=b' '*(-len(text)%4);path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(text)+len(binary))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(binary),0x004e4942)+binary)

manifest=json.loads((OUT/'manifest.json').read_text());bpy.context.preferences.filepaths.save_version=0
for var in manifest['variants']:
 ident=var['id'];M=json.loads((OUT/f'soldier_{ident}_motion.json').read_text());bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 sc=bpy.context.scene;sc.render.fps=30
 idle=next(c for c in M['clips'] if c['source_address']=='0x801aff18');rest=M['poses'][idle['frames'][0]['pose']];rests=[transform(p) for p in rest['parts']];meshes=[];original={}
 for i,part in enumerate(M['parts']):
  previous=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=part['glb'])
  bounds=[]
  for obj in set(bpy.data.objects)-previous:
   if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True);continue
   obj.name=f'Part_{i:02d}_Mesh';obj.data.transform(obj.matrix_world);obj.parent=None;obj.matrix_world=Matrix.Identity(4);obj.data.transform(Matrix.Scale(S,4));original[obj.name]=[v.co.copy() for v in obj.data.vertices];bounds.extend(original[obj.name]);obj.data.transform(rests[i]);obj['source_part_index']=i;obj['source_model']=part['source_model'];meshes.append(obj)
   for mat in obj.data.materials:
    if mat:mat.use_backface_culling=False
  part['local_bounds_min']=[min(p[a] for p in bounds) for a in range(3)];part['local_bounds_max']=[max(p[a] for p in bounds) for a in range(3)];part['bounds_space']='Blender Z-up, part-local meters; glTF Y-up is (x,z,-y)'
 armdata=bpy.data.armatures.new(f'Soldier_{ident}_Rigid_Parts');arm=bpy.data.objects.new(f'Soldier_{ident}',armdata);sc.collection.objects.link(arm);bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT');root=armdata.edit_bones.new('Root');root.head=(0,0,0);root.tail=(0,.1,0)
 for i in range(11):
  bone=armdata.edit_bones.new(f'Part_{i:02d}');bone.head=(0,0,0);bone.tail=(0,.05,0);bone.matrix=rests[i];bone.length=.05;bone.parent=root
 bpy.ops.object.mode_set(mode='OBJECT');arm.animation_data_create()
 for ob in meshes:
  i=ob['source_part_index'];g=ob.vertex_groups.new(name=f'Part_{i:02d}');g.add(list(range(len(ob.data.vertices))),1,'REPLACE');mod=ob.modifiers.new('ROM rigid part','ARMATURE');mod.object=arm;ob.parent=arm
 actions=[];matrix_error=0;checks=0
 for clip in M['clips']:
  a=bpy.data.actions.new(clip['name']);a.use_fake_user=True;arm.animation_data.action=a;a['source_address']=clip['source_address'];a['ticks']=clip['ticks'];a['terminal']=clip['terminal'];actions.append(a)
  for f in clip['frames']+[dict(clip['frames'][0],tick=clip['ticks'])]:
   for i,p in enumerate(M['poses'][f['pose']]['parts']):
    bone=arm.pose.bones[f'Part_{i:02d}'];bone.rotation_mode='QUATERNION';basis=armdata.bones[bone.name].matrix_local.inverted()@transform(p);bone.location,bone.rotation_quaternion,bone.scale=basis.decompose()
    for attr in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=attr,frame=f['tick']+1,group=bone.name)
  for c in curves(a):
   for k in c.keyframe_points:k.interpolation='CONSTANT'
  a.use_frame_range=True;a.frame_start=1;a.frame_end=clip['ticks']+1
  for f in clip['frames']:
   sc.frame_set(f['tick']+1)
   for i,p in enumerate(M['poses'][f['pose']]['parts']):
    actual=arm.pose.bones[f'Part_{i:02d}'].matrix;expect=transform(p);matrix_error=max(matrix_error,max(abs(actual[x][y]-expect[x][y]) for x in range(4) for y in range(4)));checks+=1
 assert matrix_error<1e-5,matrix_error
 arm.animation_data.action=next(a for a in actions if a.name==idle['name']);sc.frame_set(1)
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'soldier_{ident}.blend'))
 bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
 for ob in meshes:ob.parent=None;ob.select_set(True)
 path=OUT/f'soldier_{ident}.glb';bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=False,export_anim_single_armature=True,export_anim_slide_to_zero=True,export_all_influences=False,export_skins=True,export_yup=True,export_extras=True,export_optimize_animation_size=False);fix_times(path)
 var['parts']=M['parts'];var['glb_sha256']=hashlib.sha256(path.read_bytes()).hexdigest();var['verification']={'matrix_checks':checks,'max_matrix_error':matrix_error,'parts':11,'bones':12,'animations':len(actions)}
 M['parts']=var['parts'];(OUT/f'soldier_{ident}_motion.json').write_text(json.dumps(M,indent=2));print('SOLDIER_VERIFIED',ident,var['verification'],flush=True)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
