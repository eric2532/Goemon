"""Blender: recover original soldier bullet loop and casing, source traceable."""
from pathlib import Path
import bpy,json,struct,hashlib,math,sys
from mathutils import Matrix,Vector,Euler
ROOT=Path(__file__).resolve().parent.parent;REC=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery');OUT=ROOT/'assets/characters/thirstquencher/projectiles';OUT.mkdir(exist_ok=True)
SOURCE='raw/SC01.CD.dir/FILE_077.dir/0.4.dec';BASE=0x80128158;D=(REC/SOURCE).read_bytes();v=json.loads((REC/'visual_manifest.json').read_text());models={m['id']:m for m in v['models']};occ={BASE+o['offset']:o for o in v['model_occurrences'] if o['source']==SOURCE};C=Matrix(((1,0,0),(0,0,1),(0,-1,0)));S=.01

def transform(p):
 m=(C@Euler([a*math.tau/4096 for a in p['angles']],'XYZ').to_matrix()@C.transposed()).to_4x4();m.translation=C@Vector(p['position'])*S;return m

def pose(addr):
 b0,b1,b2,x,y,z,rx=struct.unpack_from('<3B3bh',D,addr-BASE);return {'address':hex(addr),'position':[x,y,z],'angles':[rx&4095,b1|((b0&15)<<8),b2|((b0&240)<<4)],'sha256':hashlib.sha256(D[addr-BASE:addr-BASE+8]).hexdigest()}

def fix_times(path):
 d=path.read_bytes();n=struct.unpack_from('<I',d,12)[0];j=json.loads(d[20:20+n]);b=bytearray(d[28+n:]);inputs={s['input'] for a in j.get('animations',[]) for s in a['samplers']}
 for idx in inputs:
  a=j['accessors'][idx];v=j['bufferViews'][a['bufferView']];o=v.get('byteOffset',0)+a.get('byteOffset',0);vs=list(struct.unpack_from('<'+'f'*a['count'],b,o));assert abs(vs[0]-1/30)<1e-6;vs=[(round(t*30)-1)/30 for t in vs];struct.pack_into('<'+'f'*len(vs),b,o,*vs);a['min']=[min(vs)];a['max']=[max(vs)]
 text=json.dumps(j,separators=(',',':')).encode();text+=b' '*(-len(text)%4);path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(text)+len(b))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(b),0x004e4942)+b)

manifest={'schema_version':1,'source':SOURCE,'source_base':hex(BASE),'source_sha256':hashlib.sha256(D).hexdigest(),'source_units_to_meters':.01,'fps':30,'coordinate_note':'Source front-Z -> glTF/Godot+Z. Imported source geometry C=(x,z,-y) in Blender; glTF Y-up export yields source(x,-y,-z). Rotate rootY byPI for Godot-Z.','color_note':'Original untextured PSXdisplay RGB/255 preserved in COLOR_0; runtime should explicitly linearize for color-managed shading.','projectiles':[]}
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if selected and (OUT/'projectile_manifest.json').exists():
 old=json.loads((OUT/'projectile_manifest.json').read_text());manifest['projectiles']=[p for p in old['projectiles'] if p['id'] not in selected]
bpy.context.preferences.filepaths.save_version=0
for name,list_addr,addr in [('bullet',0x801b1430,0x801b12c0),('casing',0x801b1560,0x801b1438)]:
 if selected and name not in selected:continue
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 o=occ[addr];model=models[o['model']];tmd_scale=struct.unpack_from('<i',D,addr-BASE+36)[0];geometry_correction=2.**(-tmd_scale);bpy.ops.import_scene.gltf(filepath=str(REC/model['path']));meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];vertices=[]
 for ob in meshes:
  ob.data.transform(ob.matrix_world);ob.matrix_world=Matrix.Identity(4);ob.data.transform(Matrix.Scale(S*geometry_correction,4));vertices.extend([v.co.copy() for v in ob.data.vertices]);ob['source_part_index']=0;ob['source_tmd_address']=hex(addr);ob.name=name.title()+'_Part_00'
  for mat in ob.data.materials:
   if mat:mat.use_backface_culling=False
 item={'id':name,'glb':f'res://assets/characters/thirstquencher/projectiles/{name}.glb','model_list_address':hex(list_addr),'tmd_address':hex(addr),'source_model':model['id'],'source_tmd_sha256':model['sha256_tmd'],'source_vertices':model['vertices'],'source_polygons':model['polygons'],'tmd_scale_word':tmd_scale,'native_libgs_applies_tmd_scale':False,'prior_converter_geometry_correction':geometry_correction,'scale_evidence':'Native func_80056F18 does not read object+0x18scale; actorinit80185428 defaults Q12XYZ1000 via8001C214/8001C9D0. LIBGS ignores TMDscale word.','local_bounds_min_blender':[min(v[a] for v in vertices) for a in range(3)],'local_bounds_max_blender':[max(v[a] for v in vertices) for a in range(3)]}
 arm=None
 if name=='bullet':
  ar=bpy.data.armatures.new('Bullet_Source_Part');arm=bpy.data.objects.new('Bullet',ar);bpy.context.scene.collection.objects.link(arm);bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT');root=ar.edit_bones.new('Root');root.head=(0,0,0);root.tail=(0,.05,0);bone=ar.edit_bones.new('Part_00');bone.head=(0,0,0);bone.tail=(0,.05,0);bone.parent=root;bpy.ops.object.mode_set(mode='OBJECT')
  for ob in meshes:
   g=ob.vertex_groups.new(name='Part_00');g.add(list(range(len(ob.data.vertices))),1,'REPLACE');mod=ob.modifiers.new('Original rigid bullet part','ARMATURE');mod.object=arm;ob.parent=arm
  arm.animation_data_create();action=bpy.data.actions.new('Source__801b1208');action.use_fake_user=True;arm.animation_data.action=action;poses=[];checks=0;error=0
  for tick in range(17):
   p=pose(0x801b1188+(tick%16)*8);poses.append(p) if tick<16 else None;bone=arm.pose.bones['Part_00'];bone.rotation_mode='QUATERNION';bone.location,bone.rotation_quaternion,bone.scale=transform(p).decompose()
   for attr in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=attr,frame=1+tick)
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for curve in bag.fcurves:
      for key in curve.keyframe_points:key.interpolation='CONSTANT'
  action.use_frame_range=True;action.frame_start=1;action.frame_end=17;bpy.context.scene.render.fps=30
  for tick,p in enumerate(poses):
   bpy.context.scene.frame_set(tick+1);actual=arm.pose.bones['Part_00'].matrix;expected=transform(p);error=max(error,max(abs(actual[r][c]-expected[r][c]) for r in range(4) for c in range(4)));checks+=1
  assert error<1e-5;item.update({'part_bone':'Part_00','animation':{'name':action.name,'source_address':'0x801b1208','ticks':16,'terminal':'loop','stream_sha256':hashlib.sha256(D[0x801b1208-BASE:0x801b1290-BASE]).hexdigest(),'frames':[{'tick':i,'hold_ticks':1,'pose':p['address'],'command_address':hex(0x801b1208+i*8)} for i,p in enumerate(poses)],'poses':poses},'verification':{'matrix_checks':checks,'max_matrix_error':error},'source_speed_units_per_tick':16,'source_lifetime_ticks':100,'source_damage':25,'registry_type':'0x20','initializer':'0x80185428','update_callback':'0x801855a0'});bpy.context.scene.frame_set(1)
 else:item.update({'registry_type':'0xbc','source_velocity_units_per_tick':[-4.5,-8,0],'source_lifetime_ticks':90,'source_euler_step_per_tick':[-128,4,5],'motion_note':'Casing motion is runtime actor translation/rotation rather than a recovered pose stream; this GLB preserves original static geometry.'})
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{name}.blend'));bpy.ops.object.select_all(action='DESELECT')
 if arm:arm.select_set(True)
 for ob in meshes:ob.parent=None;ob.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_animations=arm is not None,export_animation_mode='ACTIONS',export_force_sampling=False,export_anim_single_armature=True,export_anim_slide_to_zero=True,export_all_influences=False,export_skins=True,export_yup=True,export_extras=True,export_optimize_animation_size=False)
 if arm:fix_times(OUT/f'{name}.glb')
 item['glb_sha256']=hashlib.sha256((OUT/f'{name}.glb').read_bytes()).hexdigest();manifest['projectiles'].append(item)
(OUT/'projectile_manifest.json').write_text(json.dumps(manifest,indent=2));print('RECOVERED_PROJECTILES',[(p['id'],p['source_vertices'],p['source_polygons']) for p in manifest['projectiles']],flush=True)
