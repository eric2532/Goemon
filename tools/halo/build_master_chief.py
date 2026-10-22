"""Rebuild the user's Halo CE disc assets as posed, animated glTF assets.
Run with Blender --background --python tools/halo/build_master_chief.py.
Source JMS/JMA coordinates are centimeters-of-Halo-units (100 units = 3.048m),
X forward, Y left, Z up. glTF output is meters, X right, Y up, -Z forward.
No game-engine source code is incorporated in this converter or its outputs.
"""
import bpy,json,math,sys,shutil,struct
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'assets/blender/master_chief'
OUT=ROOT/'assets/characters/master_chief'
DATA=SRC/'source_data'
D=json.loads((SRC/'decoded_assets.json').read_text())
bpy.context.preferences.filepaths.save_version=0
SCALE=.03048
TINT=np.array([.341176,.403922,.145098],dtype=np.float32)

def local(n):
 q=n['rotation'];quat=Quaternion((q[3],q[0],q[1],q[2])).conjugated()
 return Matrix.Translation(Vector(n['position'])) @ quat.to_matrix().to_4x4() @ Matrix.Scale(n.get('scale',1),4)
def worlds(nodes,states=None):
 result={};byname={n['name']:i for i,n in enumerate(nodes)}
 def one(i):
  if i in result:return result[i]
  p=nodes[i]['parent'];v=local((states or nodes)[i]);result[i]=one(p)@v if p>=0 else v;return result[i]
 for i in range(len(nodes)):one(i)
 return {n['name']:result[i] for i,n in enumerate(nodes)}
def ensure_parents(nodes):
 for n in nodes:n['parent']=-1
 for i,n in enumerate(nodes):
  c=n['child']
  while c>=0:nodes[c]['parent']=i;c=nodes[c]['sibling']
for group in ('fp_animations','body_animations'):
 for anim in D[group].values():ensure_parents(anim['nodes'])
for key in ('body','arms','rifle','rifle_fp','rocket'):ensure_parents(D[key]['nodes'])
for w in D['weapons'].values():
 ensure_parents(w['model']['nodes'])
 for a in w['animations'].values():ensure_parents(a['nodes'])

TEXTURES={
 'rocket launcher grip':('weapons/rocket launcher/bitmaps/rocket launcher.png',None),
 'rocket launcher body':('weapons/rocket launcher/bitmaps/rocket launcher.png',None),
 'rocket launcher tubes':('weapons/rocket launcher/bitmaps/rocket launcher.png',None),
 'rocket launcher decal':('weapons/rocket launcher/bitmaps/rocket launcher decal.png',None),
 'rocket launcher hull':('weapons/rocket launcher/projectile/bitmaps/rocket.png',None),
 'silver':('weapons/pistol/fp/bitmaps/pistol.png',None),
 'black':('weapons/pistol/fp/bitmaps/pistol.png',None),
 'bullet':('weapons/pistol/fp/bitmaps/bullet.png',None),
 'shotgun gun':('weapons/shotgun/bitmaps/shotgun.png',None),
 'shotgun primary':('weapons/shotgun/bitmaps/shotgun bolt.png',None),
 'shotgun shell':('weapons/shotgun/bitmaps/shotshell.png',None),
 'armor':('characters/cyborg/bitmaps/cyborg.png','characters/cyborg/bitmaps/cyborg multipurpose.png'),
 'armor hands':('characters/cyborg/fp/bitmaps/cyborg hands.png','characters/cyborg/fp/bitmaps/cyborg hands multipurpose.png'),
 'rubber hands':('characters/cyborg/fp/bitmaps/cyborg hands.png',None),
 'grip':('weapons/assault rifle/fp/bitmaps/assault rifle_fp.png',None),
 'gun':('weapons/assault rifle/fp/bitmaps/assault rifle_fp.png',None),
 'ar lod':('weapons/assault rifle/bitmaps/assault rifle_card.png',None),
 'display':('weapons/assault rifle/fp/bitmaps/display_fp.png',None),
 'compass':('weapons/assault rifle/fp/bitmaps/compass_plate__0.png',None),
 'numbers':('weapons/assault rifle/fp/bitmaps/numbers_plate__6.png',None),
 'ar data':('weapons/assault rifle/fp/bitmaps/display_fp.png',None),
 'icons':('weapons/assault rifle/fp/bitmaps/display_fp.png',None),
 'bolt':('weapons/assault rifle/bitmaps/bolt.png',None),
 'light shield':('characters/cyborg/bitmaps/cyborg.png',None),
 'light shield generator':('characters/cyborg/bitmaps/cyborg.png',None),
}

def texture(path,mask=None):
 image=bpy.data.images.load(str(DATA/path),check_existing=True)
 if not mask:return image
 name=Path(path).stem+'_chief_olive'
 if name in bpy.data.images:return bpy.data.images[name]
 # Original Xbox multipurpose blue is the authored player-color mask.
 # Bake its original Chief permutation into a portable base-color PNG.
 src=np.array(image.pixels[:],dtype=np.float32).reshape(-1,4)
 m=bpy.data.images.load(str(DATA/mask),check_existing=True)
 if tuple(m.size)!=tuple(image.size):
  m=m.copy();m.scale(image.size[0],image.size[1])
 p=np.array(m.pixels[:],dtype=np.float32).reshape(-1,4)
 strength=p[:,2:3]
 src[:,:3] *= (1-strength)+strength*TINT
 src[:,3]=1
 result=bpy.data.images.new(name,width=image.size[0],height=image.size[1],alpha=True)
 result.pixels.foreach_set(src.ravel());result.file_format='PNG';result.filepath_raw=str(SRC/(name+'.png'));result.save();result.pack()
 return result

def material(name,index=0):
 key=name+('_zero' if name=='numbers' and index>4 else '')
 if key in bpy.data.materials:return bpy.data.materials[key]
 mat=bpy.data.materials.new(key);mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.62
 bs.inputs['Metallic'].default_value=.15 if name in ('armor','armor hands','gun') else .05
 if name=='visor':
  bs.inputs['Base Color'].default_value=(.95,.48,.08,1);bs.inputs['Metallic'].default_value=.8;bs.inputs['Roughness'].default_value=.2
 elif name in TEXTURES:
  tex,mask=TEXTURES[name]
  if name=='numbers' and index>4:tex='weapons/assault rifle/fp/bitmaps/numbers_plate__0.png'
  if (DATA/tex).is_file():
   im=texture(tex,mask)
   if name in ('numbers','compass','ar data','icons'):
    pixels=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4);pixels[:,3]=np.max(pixels[:,:3],axis=1)
    overlay=bpy.data.images.new(key+'_additive',width=im.size[0],height=im.size[1],alpha=True)
    overlay.pixels.foreach_set(pixels.ravel());overlay.file_format='PNG';overlay.filepath_raw=str(SRC/(key.replace(' ','_')+'_additive.png'));overlay.save();overlay.pack();im=overlay
    mat.surface_render_method='DITHERED'
   node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
   if name in ('numbers','compass','ar data','icons'):mat.node_tree.links.new(node.outputs['Alpha'],bs.inputs['Alpha'])
   if name in ('display','numbers','compass','ar data','icons'):
    mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.7;bs.inputs['Roughness'].default_value=.38
 else:bs.inputs['Base Color'].default_value=(.05,.065,.08,1)
 return mat

def new_scene():
 bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode!='OBJECT' else None
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 bpy.context.scene.render.fps=30
 root=bpy.data.objects.new('HaloCoordinateBasis',None);bpy.context.collection.objects.link(root)
 root.rotation_euler[2]=math.pi/2;root.scale=(SCALE,)*3
 return root

def create_rig(root,nodes,rest,name):
 arm=bpy.data.armatures.new(name);rig=bpy.data.objects.new(name,arm);bpy.context.collection.objects.link(rig);rig.parent=root
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for n in nodes:
  b=arm.edit_bones.new(n['name']);b.head=(0,0,0);b.tail=(0,1,0);b.matrix=rest[n['name']];b.length=2
 for n in nodes:
  if n['parent']>=0:arm.edit_bones[n['name']].parent=arm.edit_bones[nodes[n['parent']]['name']]
 bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
 return rig

def create_mesh(root,rig,model,bind_rest,idle_rest,name,remap=None):
 nodes=model['nodes'];positions=[];normals=[]
 transforms={n['name']:idle_rest[(remap or {}).get(n['name'],n['name'])]@bind_rest[n['name']].inverted_safe() for n in nodes}
 for v in model['vertices']:
  p=Vector((0,0,0));normal=Vector((0,0,0));total=0
  for bi,w in zip(v['bones'],v['weights']):
   if bi>=0 and w>0:
    transform=transforms[nodes[bi]['name']];p+=transform@Vector(v['position'])*w;normal+=transform.to_3x3()@Vector(v['normal'])*w;total+=w
  positions.append(tuple(p if total else Vector(v['position'])))
  normals.append(tuple(normal.normalized() if total else Vector(v['normal'])))
 # Halo uses a transparent shield overlay as separate geometry. Keep its actual
 # suit surfaces and visor; the game handles the shield flash independently.
 triangles=[t for t in model['triangles'] if not model['materials'][t['material']].startswith('light shield')]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(positions,[],[t['indices'] for t in triangles]);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
 for i,mat in enumerate(model['materials']):mesh.materials.append(material(mat,i))
 uv=mesh.uv_layers.new(name='UVMap')
 for poly,t in zip(mesh.polygons,triangles):
  poly.material_index=t['material'];poly.use_smooth=True
  for li in poly.loop_indices:uv.data[li].uv=model['vertices'][mesh.loops[li].vertex_index]['uv']
 mesh.normals_split_custom_set_from_vertices(normals)
 groups={i:obj.vertex_groups.new(name=(remap or {}).get(n['name'],n['name'])) for i,n in enumerate(nodes)}
 for i,v in enumerate(model['vertices']):
  for bi,w in zip(v['bones'],v['weights']):
   if bi>=0 and w>0:groups[bi].add([i],w,'REPLACE')
 mod=obj.modifiers.new('Native Halo Skin','ARMATURE');mod.object=rig
 return obj

def animate(rig,nodes,animations,world_function):
 rig.animation_data_create()
 for key,anim in animations.items():
  action=bpy.data.actions.new(key);action.use_fake_user=True;rig.animation_data.action=action
  for frame_i,frame in enumerate(anim['frames']):
   desired=world_function(anim,frame)
   for n in nodes:
    pb=rig.pose.bones[n['name']];par=pb.parent
    relative=(desired[par.name].inverted_safe()@desired[pb.name]) if par else desired[pb.name]
    rest_relative=(par.bone.matrix_local.inverted_safe()@pb.bone.matrix_local) if par else pb.bone.matrix_local
    pb.matrix_basis=rest_relative.inverted_safe()@relative
    pb.rotation_mode='QUATERNION'
    pb.keyframe_insert('location',frame=frame_i+1,group=pb.name);pb.keyframe_insert('rotation_quaternion',frame=frame_i+1,group=pb.name);pb.keyframe_insert('scale',frame=frame_i+1,group=pb.name)
  action['native_halo_clip']=key
 rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(1)

def export(name,root,rig):
 bpy.context.view_layer.update()
 # Store an editable source with meshes, materials, rig, and native clips.
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True,export_apply=False,export_all_influences=False,export_force_sampling=True,export_frame_range=False,export_nla_strips=False,export_def_bones=True)
 points=[]
 deps=bpy.context.evaluated_depsgraph_get()
 for obj in bpy.context.scene.objects:
  if obj.type=='MESH':
   ev=obj.evaluated_get(deps);mesh=ev.to_mesh();points.extend(obj.matrix_world@v.co for v in mesh.vertices);ev.to_mesh_clear()
 bounds=[tuple(min(p[i] for p in points) for i in range(3)),tuple(max(p[i] for p in points) for i in range(3))]
 print('ASSET',name,'Blender XYZ bounds',bounds,'animations',[a.name for a in bpy.data.actions])
 (SRC/(name+'_metadata.json')).write_text(json.dumps({'unit':'meters','blender_bounds':bounds,'animations':[a.name for a in bpy.data.actions],'nodes':len(rig.data.bones)},indent=2))

def build_fp(key=None):
 model=D['weapons'][key]['model'] if key else D['rifle_fp']
 root=new_scene();animations=D['weapons'][key]['animations'] if key else D['fp_animations'];nodes=animations['idle']['nodes'];idle=worlds(nodes,animations['idle']['frames'][0])
 rig=create_rig(root,nodes,idle,'FirstPersonRig')
 for label,mesh in [('arms',D['arms']),('weapon',model)]:create_mesh(root,rig,mesh,worlds(mesh['nodes']),idle,label)
 animate(rig,nodes,animations,lambda a,f:worlds(a['nodes'],f))
 bpy.context.view_layer.update()
 marker=next(m for m in model['markers'] if m['name']=='primary trigger')
 muzzle=bpy.data.objects.new('Muzzle',None);bpy.context.collection.objects.link(muzzle)
 bone=model['nodes'][marker['parent']]['name']
 muzzle.parent=rig;muzzle.parent_type='BONE';muzzle.parent_bone=bone
 bpy.context.view_layer.update();muzzle.matrix_world=root.matrix_world@idle[bone]@local(marker)
 bpy.context.view_layer.update();print('MUZZLE BLENDER',tuple(muzzle.matrix_world.translation))
 export(key+'_fp' if key else 'assault_rifle_fp',root,rig)

def build_body():
 root=new_scene();animations=D['body_animations'];base=D['body'];nodes=[dict(n) for n in base['nodes']]
 weapon=D['rifle'];marker=next(m for m in base['markers'] if m['name']=='right hand');hand=base['nodes'][marker['parent']]['name'];marker_matrix=local(marker)
 weapon_nodes=weapon['nodes'];offset=len(nodes);remap={n['name']:'held '+n['name'] for n in weapon_nodes}
 for n in weapon_nodes:
  nn=dict(n);nn['name']=remap[n['name']];nn['parent']=offset+n['parent'] if n['parent']>=0 else marker['parent'];nodes.append(nn)
 weapon_bind=worlds(weapon_nodes)
 def posed(a,f):
  res=worlds(a['nodes'],f);attach=res[hand]@marker_matrix
  for n in weapon_nodes:res[remap[n['name']]]=attach@weapon_bind[n['name']]
  return res
 idle=posed(animations['idle'],animations['idle']['frames'][0]);rig=create_rig(root,nodes,idle,'MasterChiefRig')
 create_mesh(root,rig,base,worlds(base['nodes']),idle,'MasterChief')
 create_mesh(root,rig,weapon,weapon_bind,idle,'HeldAssaultRifle',remap)
 animate(rig,nodes,animations,posed);export('master_chief',root,rig)

if __name__=='__main__':
 OUT.mkdir(parents=True,exist_ok=True)
 if '--weapons-only' not in sys.argv:build_fp();build_body()
 for key in D['weapons']:build_fp(key)
 root=new_scene();model=D['rocket'];rest=worlds(model['nodes'])
 rig=create_rig(root,model['nodes'],rest,'RocketRig')
 create_mesh(root,rig,model,rest,rest,'Rocket')
 export('rocket_projectile',root,rig)
 for source,name in [('rocket launcher/fire/rocket16.wav','rocket_launcher_shot.wav'),('pistol/fire/handgun2.wav','pistol_shot.wav'),('shotgun/fire/shotgun6050.wav','shotgun_shot.wav'),('frag grenade/expl/frag_expl.wav','rocket_explosion.wav')]:
  path=DATA/'sound/sfx/weapons'/source
  if not path.is_file() and 'frag grenade' in source:path=next((DATA/'sound/sfx/weapons/frag grenade/expl').glob('*.wav'))
  shutil.copy2(path,OUT/name)
 for src,name in [('fire/brown2_1.wav','assault_rifle_shot.wav'),('dryfire/ARdryfire22.wav','assault_rifle_dryfire.wav')]:shutil.copy2(DATA/'sound/sfx/weapons/assault rifle'/src,OUT/name)
 shutil.copy2(DATA/'sound/sfx/weapons/weapon_anims/ar_reload/ar_reload.wav',OUT/'assault_rifle_reload.wav')
 for wav in OUT.glob('*.wav'):
  raw=bytearray(wav.read_bytes());struct.pack_into('<I',raw,4,len(raw)-8);wav.write_bytes(raw)
 print('Finished',OUT)
