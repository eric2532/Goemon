import bpy, math, json, os, argparse, sys
from mathutils import Vector, Euler
from pathlib import Path

OUT=Path('/workspace/scratch/23f1a29e8f92/construction_fx_v1')
for p in ('exports','previews','qa'): (OUT/p).mkdir(parents=True, exist_ok=True)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
RENDER='--render' in args
bpy.ops.wm.read_factory_settings(use_empty=True)
FPS=24

# Material colors are authored in linear space for GLB/PBR portability.
def mat(name, color, metallic=0, roughness=.65, emission=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Metallic'].default_value=metallic; p.inputs['Roughness'].default_value=roughness
 if emission: p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
 return m
M={
 'iron':mat('Iron • warm charcoal',(.072,.083,.091),.7,.36),
 'edge':mat('Iron • polished edges',(.18,.195,.20),.75,.30),
 'wood':mat('Walnut • handle',(.245,.093,.035),0,.72),
 'woodLight':mat('Oak • demo timber',(.37,.19,.075),0,.65),
 'leather':mat('Leather • grip',(.095,.041,.026),0,.8),
 'brass':mat('Brass • warm edge',(.55,.30,.065),.7,.35),
 'gold':mat('Gold • readable fill',(.98,.54,.055),.3,.29,.55),
 'pulse':mat('Gold • completion geometry',(.98,.60,.10),.1,.35,2.0),
 'dark':mat('Progress • recessed track',(.022,.017,.015),0,.8),
 'stone':mat('Demo • warm limestone',(.30,.295,.27),0,.82),
 'stoneLight':mat('Demo • lighter limestone',(.42,.39,.33),0,.85),
 'floor':mat('Studio • warm charcoal',(.036,.045,.052),0,.88),
 'text':mat('Labels • ivory',(.86,.84,.77),0,.8,.35),
 'muted':mat('Labels • muted',(.39,.43,.44),0,.8,.2),
 'red':mat('Labels • release',(.8,.23,.13),0,.8,.5),
}

def scene(name):
 s=bpy.data.scenes.new(name); bpy.context.window.scene=s; s.unit_settings.system='METRIC'; s.unit_settings.scale_length=1
 s.render.fps=FPS; s.frame_start=1; s.frame_end=25
 s.world=bpy.data.worlds.new(name+' World'); s.world.use_nodes=True
 s.world.node_tree.nodes['Background'].inputs[0].default_value=(.085,.1,.13,1)
 s.world.node_tree.nodes['Background'].inputs[1].default_value=.4
 return s

def empty(name, loc=(0,0,0), parent=None):
 o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=loc
 o.empty_display_type='PLAIN_AXES'; o.empty_display_size=.15
 if parent:o.parent=parent
 return o

def bevel(o,w=.03,segments=2):
 b=o.modifiers.new('Soft forged edges','BEVEL');b.width=w;b.segments=segments
 b.affect='EDGES'
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.modifier_apply(modifier=b.name);o.select_set(False)
 return o

def cube(name,loc,size,material,parent=None,b=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name
 o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(material)
 if b:bevel(o,b,2)
 if parent:o.parent=parent
 return o

def cyl(name,loc,radius,depth,material,parent=None,vertices=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
 o=bpy.context.object;o.name=name;o.data.materials.append(material)
 bevel(o,.008,1)
 if parent:o.parent=parent
 return o

def torus(name,loc,major,minor,material,parent=None,ms=32,ns=6):
 bpy.ops.mesh.primitive_torus_add(major_segments=ms,minor_segments=ns,location=loc,major_radius=major,minor_radius=minor)
 o=bpy.context.object;o.name=name;o.data.materials.append(material)
 if parent:o.parent=parent
 return o

def label(name,body,loc,size=.15,material=None,parent=None,align='CENTER'):
 cu=bpy.data.curves.new(name,'FONT');cu.body=body;cu.align_x=align;cu.size=size;cu.extrude=.001;cu.bevel_depth=.0003
 o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);o.location=loc
 o.rotation_euler=(math.pi/2,0,0)
 cu.materials.append(material or M['text'])
 if parent:o.parent=parent
 return o

def mesh_convert(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');return bpy.context.object

def key(o,path,frames,interp='BEZIER'):
 for f,value in frames:
  setattr(o,path,value);o.keyframe_insert(data_path=path,frame=f)
 if o.animation_data and o.animation_data.action:
  for fc in o.animation_data.action.fcurves:
   for k in fc.keyframe_points:k.interpolation=interp

def action_name(o,name):
 if o.animation_data and o.animation_data.action:o.animation_data.action.name=name

def export(s,filename,anim_name=None):
 bpy.context.window.scene=s;s.frame_set(s.frame_start)
 original_name=s.name
 if anim_name:s.name=anim_name
 bpy.ops.object.select_all(action='SELECT')
 kwargs=dict(filepath=str(OUT/'exports'/filename),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,
  export_apply=True,export_extras=True,export_animations=bool(anim_name),export_cameras=False,export_lights=False,
  export_materials='EXPORT',export_normals=True,export_texcoords=True,export_morph=True,export_morph_normal=True)
 if anim_name:kwargs.update(export_animation_mode='SCENE',export_nla_strips_merged_animation_name=anim_name,
  export_anim_scene_split_object=False,export_anim_slide_to_zero=True,export_frame_range=True,export_force_sampling=True,export_morph_animation=True,
  export_optimize_animation_size=True,export_bake_animation=True)
 bpy.ops.export_scene.gltf(**kwargs)
 s.name=original_name

s_hammer=scene('01_Hammer_Loop')
hroot=empty('FX_HammerRoot');hroot['role']='Attach near construction socket. Local meters, +Z up, front -Y.'
pivot=empty('FX_HammerSwingPivot',parent=hroot);pivot['pivot']='Grip center. Animate local Y rotation.'
# Grip lives at the root; hammer head sits above it and swings in XZ.
handle=cyl('Hammer_OakHandle',(0,0,.31),.058,.78,M['wood'],pivot)
head=cube('Hammer_IronHead',(0,0,.72),(.62,.255,.265),M['iron'],pivot,b=.035)
for x in (-.295,.295):cube('Hammer_StrikingFace_'+('L' if x<0 else 'R'),(x,0,.72),(.055,.27,.278),M['edge'],pivot,b=.013)
for x in (-.19,.19):cube('Hammer_BrassBand',(x,0,.72),(.022,.26,.271),M['brass'],pivot,b=.005)
cyl('Hammer_Grip',(0,0,-.008),.066,.29,M['leather'],pivot)
for z in (-.14,-.083,-.026,.031,.088,.145):torus('Hammer_GripWrap',(0,0,z),.066,.008,M['wood'],pivot,24,4)
for z in (-.16,.16):cyl('Hammer_GripCap',(0,0,z),.071,.025,M['brass'],pivot)
cube('Hammer_SocketCollar',(0,0,.55),(.155,.155,.055),M['brass'],pivot,b=.012)
key(pivot,'rotation_euler',[(1,(0,math.radians(-28),0)),(6,(0,math.radians(-36),0)),(12,(0,math.radians(45),0)),(14,(0,math.radians(45),0)),(25,(0,math.radians(-28),0))])
action_name(pivot,'Build_HammerLoop');export(s_hammer,'FS_FX_Hammer_BuildLoop.glb','Build_HammerLoop')

s_progress=scene('02_Progress_Frame')
proot=empty('FX_ProgressRoot');proot['role']='Billboard whole root toward camera. ProgressFill scale.x = clamped progress [0,1].';proot['full_width_m']=2.2
cube('Progress_Backplate',(0,0,0),(2.2,.10,.30),M['iron'],proot,b=.045)
cube('Progress_BrassInset',(0,-.056,0),(2.12,.024,.232),M['brass'],proot,b=.028)
cube('Progress_Track',(0,-.075,0),(2.015,.024,.156),M['dark'],proot,b=.013)
# Mesh has its origin at the left edge, so scale.x never slides the anchor.
fill=cube('ProgressFill',(0,0,0),(1.95,.023,.108),M['gold'],proot,b=.009)
for v in fill.data.vertices:v.co.x+=.975
fill.location=(-.975,-.093,0);fill['drive']='scale.x = max(epsilon, min(1, progress)); hide at exactly zero';fill['max_width_m']=1.95
for x in (-1.055,1.055):
 c=cyl('Progress_Rivet',(x,-.071,0),.025,.02,M['edge'],proot,10);c.rotation_euler.x=math.pi/2
export(s_progress,'FS_FX_ProgressFrame.glb')

s_prompt=scene('03_Optional_B_Prompt')
broot=empty('FX_BPromptRoot');broot['role']='Optional desktop prompt. Omit or replace for other input devices.'
cap=cyl('BPrompt_Keycap',(0,0,0),.205,.07,M['iron'],broot,32);cap.rotation_euler.x=math.pi/2
border=torus('BPrompt_BrassRim',(0,-.038,0),.185,.017,M['brass'],broot,48,6);border.rotation_euler.x=math.pi/2
text=label('BPrompt_Letter','B',(0,-.051,-.093),.275,M['gold'],broot);mesh_convert(text)
export(s_prompt,'FS_FX_BPrompt.glb')

s_completion=scene('04_Completion_Pulse');croot=empty('FX_CompletionRoot');croot['role']='Place ground-center; play Complete_GoldPulse once on successful completion. Default outer radius 1.5 m.'
def animated_ring(name,radius,minor,z,start=1):
 o=torus(name,(0,0,z),radius,minor,M['pulse'],croot,64,6)
 o.shape_key_add(name='Basis');sk=o.shape_key_add(name='ThinToZero')
 for i,v in enumerate(o.data.vertices):
  angle=math.atan2(v.co.y,v.co.x);sk.data[i].co=(radius*math.cos(angle),radius*math.sin(angle),0)
 for f,value in [(1,1),(start+2,0),(start+8,0),(start+17,.82),(25,1)]:
  sk.value=value;sk.keyframe_insert(data_path='value',frame=f)
 for fc in o.data.shape_keys.animation_data.action.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR'
 o.data.shape_keys.animation_data.action.name=name+'_ThinToZero'
 key(o,'scale',[(1,(.60,.60,.60)),(start+5,(.94,.94,.94)),(25,(1.46,1.46,1.46))], 'LINEAR')
 return o
animated_ring('Completion_OuterRing',1.5,.029,.075)
animated_ring('Completion_InnerRing',1.21,.013,.12,4)
# Faceted golden motes: visible without alpha, bloom, particles, or shader animation.
for i in range(10):
 a=math.tau*i/10+.13;radius=1.05+(.15 if i%2 else 0)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
 o=bpy.context.object;o.name=f'Completion_Spark_{i+1:02d}';o.parent=croot;o.data.materials.append(M['pulse'])
 for v in o.data.vertices:v.co.z*=1.7;v.co.x*=.55;v.co.y*=.55
 start=2+i%4
 xy=(math.cos(a)*radius,math.sin(a)*radius)
 key(o,'location',[(1,(*xy,.24)),(start,(*xy,.24)),(25,(xy[0]*1.15,xy[1]*1.15,1.0+.35*(i%3)))],'LINEAR')
 size=.073 if i%2 else .055
 key(o,'scale',[(1,(.00001,.00001,.00001)),(start,(.00001,.00001,.00001)),(start+3,(size,size,size)),(15,(size*.65,size*.65,size*.65)),(25,(.00001,.00001,.00001))],'LINEAR')
 key(o,'rotation_euler',[(1,(0,0,a)),(25,(.25,.1,a+1.2))],'LINEAR')
export(s_completion,'FS_FX_CompletionPulse.glb','Complete_GoldPulse')

# Preview-only demonstration. It deliberately contains no tower or mine gameplay asset.
s=scene('05_CONSTRUCTION_DEMO_illustrative');s.frame_end=193
s['NOTICE']='DEMO PEDESTAL ONLY. Preview timing is illustrative, not gameplay tuning. No game logic or currency handling is included.'

def clone_tree(root,prefix):
 mapping={}
 for ob in [root]+list(root.children_recursive):
  c=ob.copy()
  if ob.data:c.data=ob.data.copy()
  if c.animation_data:c.animation_data_clear()
  if c.data and hasattr(c.data,'shape_keys') and c.data.shape_keys:
   c.data.shape_keys.animation_data_clear()
   for sk in c.data.shape_keys.key_blocks:sk.value=0
  c.name=prefix+ob.name;bpy.context.collection.objects.link(c);mapping[ob]=c
 for ob,c in mapping.items():c.parent=mapping.get(ob.parent)
 return mapping[root],mapping

# Dark stage and modular stone/timber pedestal make the FX easy to judge.
cube('DEMO_StageFloor',(0,0,-.17),(200,200,.2),M['floor'],b=0)
for row in range(2):
 for ix in range(4):
  for iy in range(3):
   cube(f'DEMO_PedestalStone_{row}_{ix}_{iy}',(-.99+ix*.66,-.76+iy*.76,.17+row*.30),(.63,.725,.28),M['stoneLight'] if (row+ix+iy)%4==0 else M['stone'],b=.045)
for y in (-1.06,1.06):cube('DEMO_TimberRim',(0,y,.69),(2.95,.16,.21),M['woodLight'],b=.025)
for x in (-1.39,1.39):cube('DEMO_TimberRim',(x,0,.69),(.17,2.23,.21),M['woodLight'],b=.025)
for x in (-1.4,1.4):
 for y in (-1.07,1.07):cube('DEMO_IronCorner',(x,y,.71),(.28,.29,.23),M['iron'],b=.018)
# Small, deliberately incomplete frame indicates a neutral construction site.
for x,y in ((-1.12,.79),(1.12,.79)):
 cube('DEMO_UnfinishedPost',(x,y,1.07),(.14,.14,.64),M['woodLight'],b=.015)
cube('DEMO_LooseTimber',(.50,.23,.78),(1.08,.15,.14),M['woodLight'],b=.012).rotation_euler.z=.12
cube('DEMO_LooseTimber',(.50,.24,.91),(.84,.14,.13),M['wood'],b=.012).rotation_euler.z=-.07

h,mh=clone_tree(hroot,'DEMO_');h.location=(.76,-.55,1.25);h.scale=(.7,.7,.7)
hp=mh[pivot]
# 0–2.5 s build, 2.5–4 s release/decay, 4–6.5 s resume, 6.5–7.5 s completion.
for f in range(1,158):
 active=f<61 or f>=97
 if active:
  t=((f-1)%24)/24
  angle=math.radians(-28+73*(.5-.5*math.cos(math.tau*t)))
 else:angle=math.radians(-28)
 hp.rotation_euler=(0,angle,0);hp.keyframe_insert(data_path='rotation_euler',frame=f)
key(h,'scale',[(1,(.7,.7,.7)),(155,(.7,.7,.7)),(157,(0,0,0)),(193,(0,0,0))],'LINEAR')
pr,mp=clone_tree(proot,'DEMO_');pr.location=(0,-.10,2.40)
bp,mb=clone_tree(broot,'DEMO_');bp.location=(0,-.10,1.95)
key(bp,'scale',[(1,(1,1,1)),(156,(1,1,1)),(157,(0,0,0))],'CONSTANT')
pf=mp[fill]
key(pf,'scale',[(1,(.06,1,1)),(61,(.66,1,1)),(97,(.43,1,1)),(157,(1,1,1)),(193,(1,1,1))],'LINEAR')
# Use the source's geometry and identical channel sampling, shifted to demo completion.
cr,mc=clone_tree(croot,'DEMO_');cr.location=(0,0,0);cr.scale=(.94,.94,.94)
for orig,c in mc.items():
 if orig is croot:continue
 if orig.animation_data and orig.animation_data.action:
  c.animation_data_create();a=orig.animation_data.action.copy();c.animation_data.action=a
  for fc in a.fcurves:
   for k in fc.keyframe_points:k.co.x+=156;k.handle_left.x+=156;k.handle_right.x+=156
 if orig.data and hasattr(orig.data,'shape_keys') and orig.data.shape_keys:
  srcsk=orig.data.shape_keys;dstsk=c.data.shape_keys
  if srcsk.animation_data and srcsk.animation_data.action:
   dstsk.animation_data_create();a=srcsk.animation_data.action.copy();dstsk.animation_data.action=a
   for fc in a.fcurves:
    for k in fc.keyframe_points:k.co.x+=156;k.handle_left.x+=156;k.handle_right.x+=156

# Camera, lighting, and screen-aligned text in world space are demo-only.
bpy.ops.object.camera_add(location=(6.8,-10.5,7.0));cam=bpy.context.object;cam.name='DEMO_Camera'
target=Vector((0,0,1.1));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=7.5;s.camera=cam
for ob in (pr,bp): ob.rotation_euler=(cam.rotation_euler.to_quaternion() @ Euler((-math.pi/2,0,0)).to_quaternion()).to_euler()

def camera_text(name,body,x,y,size,material=M['text']):
 ob=label(name,body,(0,0,0),size,material,align='LEFT');ob.parent=cam;ob.location=(x,y,-10);ob.rotation_euler=(0,0,0);return ob
camera_text('DEMO_Title','FIRESIEGE  /  CONSTRUCTION FEEDBACK',-3.48,2.02,.17)
camera_text('DEMO_Subtitle','SHARED FX  •  TOWER + MINE  •  METERS / +Z UP',-3.48,1.77,.10,M['muted'])
camera_text('DEMO_PlaceholderNotice','DEMO PEDESTAL  /  PLACEHOLDER ONLY',-3.48,-1.98,.12,M['muted'])
camera_text('DEMO_TimingNotice','PREVIEW TIMING IS ILLUSTRATIVE  •  NO GAME LOGIC',-3.48,-2.18,.10,M['muted'])
statuses=[('HOLD B  /  BUILDING',1,60,M['gold']),('RELEASED  /  PROGRESS DECAYS',61,96,M['red']),('HOLD B  /  RESUME REMAINING',97,156,M['gold']),('COMPLETE  /  GOLD SPENT NOW',157,193,M['gold'])]
for i,(body,a,b,material) in enumerate(statuses):
 o=camera_text('DEMO_Status_'+str(i),body,-3.48,-1.71,.145,material)
 key(o,'scale',[(1,((1,1,1) if a==1 else (0,0,0))),(max(1,a-1),(0,0,0)),(a,(1,1,1)),(b,(1,1,1)),(b+1,(0,0,0))],'CONSTANT')
# Correct first status from frame 1 after intentionally constant transition setup.
first=bpy.data.objects.get('DEMO_Status_0')
first.animation_data_clear();key(first,'scale',[(1,(1,1,1)),(60,(1,1,1)),(61,(0,0,0))],'CONSTANT')

def area(name,loc,power,size,color):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
area('Studio_Key',(-3,-4,7),1050,5,(1,.81,.61));area('Studio_Fill',(5,-1,5),900,5,(.69,.82,1));area('Studio_Rim',(0,5,5),1500,4,(1,.67,.29))
s.render.engine='CYCLES';s.cycles.samples=64;s.cycles.use_denoising=False;s.render.resolution_x=1152;s.render.resolution_y=720;s.render.resolution_percentage=100
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
s.render.image_settings.file_format='PNG';s.render.film_transparent=False
s.frame_set(43)
# Store a comfortable default view in the blend.
for screen in bpy.data.screens:
 for ar in screen.areas:
  if ar.type=='VIEW_3D':
   ar.spaces.active.region_3d.view_perspective='CAMERA';ar.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'FireSiege_ConstructionFX_v1.blend'))
manifest={
 'units':'meters','blender_up':'+Z','blender_front':'-Y','gltf_up':'+Y','gltf_front':'+Z',
 'files':[
 {'file':'FS_FX_Hammer_BuildLoop.glb','root':'FX_HammerRoot','clip':'Build_HammerLoop','duration_seconds':1,'pivot':'FX_HammerSwingPivot / grip center'},
 {'file':'FS_FX_ProgressFrame.glb','root':'FX_ProgressRoot','fill':'ProgressFill','input':'scale.x = progress, anchored left','width_m':2.2},
 {'file':'FS_FX_BPrompt.glb','root':'FX_BPromptRoot','optional':True},
 {'file':'FS_FX_CompletionPulse.glb','root':'FX_CompletionRoot','clip':'Complete_GoldPulse','duration_seconds':1,'geometry':'TRS sparks + ring morph targets','radius_m':1.5},
 ],'preview':'Demo pedestal is a placeholder. Preview pacing is illustrative, not gameplay values.'
}
(OUT/'asset_manifest.json').write_text(json.dumps(manifest,indent=2))
if RENDER:
 for f,name in [(59,'build'),(91,'release_decay'),(130,'resume'),(165,'completion')]:
  s.frame_set(f);s.render.filepath=str(OUT/'previews'/('demo_'+name+'.png'));bpy.ops.render.render(write_still=True)
print('FX_BUILD_FINISHED',OUT)
