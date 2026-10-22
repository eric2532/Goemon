"""Original enemy authoring recipe. Only writes original_set; never touches approved masters."""
import bpy, math, json, sys
from mathutils import Vector
from pathlib import Path
R=Path(__file__).resolve().parents[1]
OUT=R/'docs/original-enemies';OUT.mkdir(exist_ok=True)
IDS=['masked_foot_soldier','straw_hat_bandit','lantern_yokai','daruma_bruiser']
report=[]
if '--replace' not in sys.argv:
 existing=[str(R/'assets/blender/enemies/original_set'/f'{i}.blend') for i in IDS if (R/'assets/blender/enemies/original_set'/f'{i}.blend').exists()]
 if existing:raise RuntimeError('Existing editable masters protected; use -- --replace only to deliberately regenerate original_set')
def tileuv(o,tile):
 uv=o.data.uv_layers.new(name='UVMap') if not o.data.uv_layers else o.data.uv_layers.active
 for p in o.data.polygons:
  for k,li in enumerate(p.loop_indices):
   # rectilinear swatch regions keep fabric grain visible on simple faces
   co=[(.04,.04),(.96,.04),(.96,.96),(.04,.96)][k%4]
   uv.data[li].uv=((tile%4+co[0])/4,1-(tile//4+co[1])/4)
 o.data.materials.append(mat)
 col=o.data.color_attributes.new(name='Color',type='BYTE_COLOR',domain='CORNER')
 for c in col.data:c.color=(1,1,1,1)
 return o
def cube(name,loc,scale,t,rot=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.rotation_euler[1]=rot
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return tileuv(o,t)
def lathe(name,profile,t,n=10):
 verts=[]
 for z,r in profile:
  for j in range(n):
   a=2*math.pi*j/n;verts.append((r*math.sin(a),r*math.cos(a),z))
 faces=[]
 for k in range(len(profile)-1):
  for j in range(n):faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
 faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+j for j in range(n))])
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);return tileuv(o,t)
def limb(name,a,b,r,t,r2=None,n=6):
 o=lathe(name,[(0,r),((Vector(b)-Vector(a)).length,r if r2==None else r2)],t,n)
 o.location=a;o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler();return o
def panel(name,center,w,h,t):
 x,y,z=center;v=[(x-w/2,y,z+h/2),(x+w/2,y,z+h/2),(x+w/2,y,z-h/2),(x-w/2,y,z-h/2)]
 m=bpy.data.meshes.new(name);m.from_pydata(v,[],[(0,1,2,3)]);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);return tileuv(o,t)
def curved_face(name,z0,z1,profile,angle,t):
 verts=[];faces=[];n=6;rows=4
 def radius(z):
  for (a,ra),(b,rb) in zip(profile,profile[1:]):
   if a<=z<=b:return ra+(rb-ra)*(z-a)/(b-a)+.022
  return profile[-1][1]+.022
 for row in range(rows+1):
  z=z1+(z0-z1)*row/rows;r=radius(z)
  for j in range(n+1):
   a=-angle+2*angle*j/n;verts.append((r*math.sin(a),r*math.cos(a),z))
 for row in range(rows):
  for j in range(n):
   a=row*(n+1)+j;faces.append((a,a+1,a+n+2,a+n+1))
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);tileuv(o,t)
 uv=m.uv_layers.active
 for loop in m.loops:
  row,j=divmod(loop.vertex_index,n+1);uv.data[loop.index].uv=((t%4+.04+.92*j/n)/4,1-(t//4+.04+.92*row/rows)/4)
 return o

def human(bandit=False):
 # broad, oversized sandals and angular cloth hems
 for s,bone in [(-1,'L'),(1,'R')]:
  cube('Leg_'+bone+'_sandal',(s*.28,.12,.10),(.43,.69,.20),4)
  cube('Leg_'+bone+'_strap',(s*.28,.18,.22),(.34,.13,.07),1 if not bandit else 5)
  limb('Leg_'+bone,(s*.28,0,.23),(s*.25,-.035,.91),.17,5 if bandit else 0,n=6)
  cube('Leg_'+bone+'_wrap',(s*.28,.01,.37),(.29,.29,.24),2)
 torso=lathe('Root_tunic',[(.78,.43),(1.03,.40),(1.42,.43),(1.57,.32)],6 if bandit else 0,8);torso.scale.y=.69
 cube('Root_sash',(0,0,1.02),(.86,.60,.17),7 if bandit else 1)
 for s,bone in [(-1,'L'),(1,'R')]:
  limb('Arm_'+bone+'_sleeve',(s*.34,0,1.43),(s*.58,.04,1.13),.24,6 if bandit else 0,r2=.18)
  limb('Arm_'+bone+'_wrap',(s*.58,.04,1.16),(s*.67,.15,.94),.125,2)
  cube('Arm_'+bone+'_hand',(s*.67,.16,.94),(.24,.25,.25),7)
 # angular hanging lapels
 for s in [-1,1]:cube('Root_lapel',(s*.17,.30,1.30),(.12,.05,.49),2 if bandit else 1,rot=s*.30)
 if bandit:
  head=lathe('Head_hood',[(1.53,.26),(1.87,.31),(2.04,.17)],5,8);head.location.y=.08
  panel('Head_eyes',(0,.37,1.82),.45,.20,8)
  hat=lathe('Head_straw_hat',[(1.91,.67),(1.99,.66),(2.23,.13),(2.27,.03)],2,10);hat.location.y=.12
  cube('Root_patch',(-.23,.307,1.19),(.22,.025,.20),9,rot=.15)
  cube('Leg_R_patch',(.29,.18,.68),(.20,.04,.21),7)
  limb('Arm_R_club',(.67,.16,.87),(.91,.30,1.91),.08,4,r2=.16,n=6)
 else:
  head=lathe('Head_hood',[(1.53,.26),(1.87,.35),(2.08,.28),(2.17,.08)],0,8)
  panel('Head_wooden_mask',(0,.335,1.86),.54,.52,8)
  cube('Head_band',(0,.0,2.04),(.61,.54,.095),1)
  cube('Head_knot',(.37,-.02,2.04),(.17,.16,.15),1)
  limb('Head_ribbon',(.36,-.10,2.05),(.57,-.23,1.76),.055,1,r2=.025,n=4)
  limb('Arm_R_club',(.67,.16,.87),(.87,.26,1.86),.075,4,r2=.155,n=6)
def lantern():
 # pleated paper silhouette with just 12 radial segments
 o=lathe('Root_paper',[(.62,.30),(.74,.46),(.91,.54),(1.48,.54),(1.68,.42),(1.74,.28)],13,12)
 # replace body tile with plain paper, face separate
 o.data.materials.clear();tileuv_existing(o,2)
 for z,r in [(.67,.35),(.85,.51),(1.05,.545),(1.25,.545),(1.46,.545),(1.67,.43)]:lathe('Root_hoop',[(z-.014,r),(z+.014,r)],4,12)
 lathe('Root_top',[(1.72,.31),(1.82,.31)],5,10);lathe('Root_base',[(.55,.31),(.65,.31)],5,10)
 curved_face('Root_face',.775,1.605,[(.74,.46),(.91,.54),(1.48,.54),(1.68,.42)],.94,13)
 limb('Leg_L',(.0,0,.57),(-.11,.05,.20),.09,4,r2=.08)
 cube('Leg_L_sandal',(-.08,.17,.105),(.45,.63,.21),4)
 # tongue breaks silhouette below the cheeky painted smile
 cube('Root_tongue',(.12,.61,.78),(.18,.24,.07),1,rot=-.2)
 limb('Root_handle_L',(-.2,0,1.82),(-.13,0,2.04),.027,4,n=4)
 limb('Root_handle_R',(.2,0,1.82),(.13,0,2.04),.027,4,n=4)
 limb('Root_handle_top',(-.13,0,2.04),(.13,0,2.04),.027,4,n=4)
def tileuv_existing(o,t):
 # assign swatch without adding duplicate UV/color attributes
 uv=o.data.uv_layers.active
 for p in o.data.polygons:
  for k,li in enumerate(p.loop_indices):
   a,b=[(.04,.04),(.96,.04),(.96,.96),(.04,.96)][k%4];uv.data[li].uv=((t%4+a)/4,1-(t//4+b)/4)
 o.data.materials.append(mat)
def daruma():
 lathe('Root_body',[(.08,.40),(.20,.62),(.62,.73),(1.02,.65),(1.39,.45),(1.51,.18)],1,12)
 curved_face('Head_face',.645,1.375,[(.62,.73),(1.02,.65),(1.39,.45)],.78,12)
 for s,b in [(-1,'L'),(1,'R')]:
  limb('Arm_'+b,(s*.55,0,.90),(s*.86,.14,.57),.22,1,r2=.24,n=6)
  cube('Arm_'+b+'_fist',(s*.86,.14,.53),(.37,.39,.35),5)
  cube('Leg_'+b+'_foot',(s*.33,.17,.09),(.37,.47,.18),5)
  cube('Root_gold_stroke',(s*.27,.68,.41),(.08,.035,.27),9,rot=s*.20)
 cube('Root_seal',(0,.721,.45),(.21,.035,.21),2)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def studio():
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=False
 scene.world=bpy.data.worlds.new('PreviewWorld');scene.world.color=(.22,.22,.22);scene.view_settings.view_transform='Standard'
 scene.render.resolution_x=560;scene.render.resolution_y=640;scene.render.resolution_percentage=100
 bpy.ops.object.camera_add(location=(3.3,6.5,3.2));cam=bpy.context.object;cam.name='Preview_Camera';cam.data.type='ORTHO';cam.data.ortho_scale=2.9;aim(cam,(0,0,1.08));scene.camera=cam
 for loc,power,size in [((3,4,6),450,5),((-4,2,3),250,4),((0,-4,4),300,3)]:
  bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;aim(l,(0,0,1))
 scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
for id in IDS:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 mat=bpy.data.materials.new('OriginalEnemy_PaintedAtlas');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1;bs.inputs['Specular IOR Level'].default_value=0
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(R/'assets/textures/enemies/original_set/enemy_atlas.png'));tex.image.pack();tex.interpolation='Closest';mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
 if id=='masked_foot_soldier':human()
 elif id=='straw_hat_bandit':
  human(True)
  for o in bpy.context.scene.objects:
   if o.type=='MESH' and o.name.startswith('Head'):
    o.location.y+=.16;o.location.z-=.13
   elif o.type=='MESH' and o.name.startswith('Root'):
    for v in o.data.vertices:
     if v.co.z+o.location.z>1.1:v.co.y+=.16*min(1,(v.co.z+o.location.z-1.1)/.45)

 elif id=='lantern_yokai':lantern()
 else:daruma()
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in meshes:
  bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 # expose atlas and stable names, meter units, ground origin
 bpy.context.scene.unit_settings.system='METRIC'
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(R/'assets/models/enemies/original_set'/f'{id}.glb'),use_selection=True,export_format='GLB',export_animations=False,export_skins=False)
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 report.append({'asset_id':'enemies/original_set/'+id,'triangles':tris,'materials':1,'source_meshes':len(meshes),'source':f'assets/blender/enemies/original_set/{id}.blend','export':f'assets/models/enemies/original_set/{id}.glb','thumbnail':f'docs/original-enemies/{id}.png','animation':'Named rigid parts; runtime UV2 limb ID batching; no skeletal rig','authorship':'Original geometry and original 256px painted atlas; no third-party meshes'})
 studio();bpy.ops.wm.save_as_mainfile(filepath=str(R/'assets/blender/enemies/original_set'/f'{id}.blend'))
 bpy.context.scene.render.filepath=str(OUT/f'{id}.png');bpy.ops.render.render(write_still=True)
(OUT/'asset-catalog.json').write_text(json.dumps({'baseline':'82b4e8307af1158dbec566cb67632eb5cdbbb6d2','assets':report},indent=2))
