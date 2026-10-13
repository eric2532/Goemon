import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Euler
BASE=Path('/workspace/scratch/23f1a29e8f92');OUT=BASE/'construction_fx_v1/combined_demo';FX=BASE/'construction_fx_v1/exports'
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.name='FireSiege_Actual_Assets_Demo';s.render.fps=24;s.frame_start=1;s.frame_end=145
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1

def empty(name):
 o=bpy.data.objects.new(name,None);s.collection.objects.link(o);return o

def import_asset(path,clip=None):
 before=set(s.objects);bpy.ops.import_scene.gltf(filepath=str(path));objects=list(set(s.objects)-before)
 if clip:
  for o in objects:
   ad=o.animation_data
   if ad:
    match=[t for t in ad.nla_tracks if t.name==clip]
    if match and match[0].strips:ad.action=match[0].strips[0].action
    ad.use_nla=False
   if o.type=='MESH' and o.data.shape_keys and o.data.shape_keys.animation_data:
    ad=o.data.shape_keys.animation_data;match=[t for t in ad.nla_tracks if t.name==clip]
    if match and match[0].strips:ad.action=match[0].strips[0].action
    ad.use_nla=False
 return objects

def sample_and_retime(objects,src_duration,clock,prefix):
 subjects=[o for o in objects if o.animation_data and o.animation_data.action]
 shape_subjects=[o.data.shape_keys for o in objects if o.type=='MESH' and o.data.shape_keys and o.data.shape_keys.animation_data and o.data.shape_keys.animation_data.action]
 ranges=[o.animation_data.action.frame_range[0] for o in subjects+shape_subjects]
 start=min(ranges) if ranges else 1
 samples={o:[] for o in subjects};shape_samples={k:[] for k in shape_subjects}
 for i in range(src_duration+1):
  s.frame_set(int(start+i),subframe=(start+i)%1)
  for o in subjects:samples[o].append((o.location.copy(),o.rotation_quaternion.copy(),o.scale.copy()))
  for k in shape_subjects:shape_samples[k].append([b.value for b in k.key_blocks])
 for o in objects:
  o.animation_data_clear()
  if o.type=='MESH' and o.data.shape_keys:o.data.shape_keys.animation_data_clear()
 for f in range(1,146):
  t=max(0,min(src_duration,clock(f)));i=int(t);j=min(i+1,src_duration);a=t-i
  for o,values in samples.items():
   p0,r0,z0=values[i];p1,r1,z1=values[j]
   o.location=p0.lerp(p1,a);o.rotation_mode='QUATERNION';o.rotation_quaternion=r0.slerp(r1,a);o.scale=z0.lerp(z1,a)
   for field in ('location','rotation_quaternion','scale'):o.keyframe_insert(data_path=field,frame=f)
  for k,values in shape_samples.items():
   for n,b in enumerate(k.key_blocks):
    b.value=values[i][n]*(1-a)+values[j][n]*a
    if n:b.keyframe_insert(data_path='value',frame=f)
 for o in subjects:
  for fc in o.animation_data.action.fcurves:
   for k in fc.keyframe_points:k.interpolation='LINEAR'
 for o in objects:o.name=prefix+o.name
 group=empty(prefix+'Attachment')
 for o in objects:
  if o.parent not in objects:o.parent=group
 return group,objects

def progress(f):
 for a,b,pa,pb in [(1,49,0,.7),(49,73,.7,.4),(73,121,.4,1),(121,145,1,1)]:
  if f<=b:return pa+(pb-pa)*(max(a,f)-a)/(b-a)
 return 1

sources={
 'tower':BASE/'tower_assets_v1/exports/tower_build_recoil_reverse.glb',
 'mine':BASE/'goldmine_assets_v1/goldmine_v1.glb'}
tower=import_asset(sources['tower'],'Tower_Build_Recoil_Reverse')
tr,tobs=sample_and_retime(tower,71,lambda f:progress(f)*71,'DEMO_Tower_');tr.location=(-3.0,0,0)
mine=import_asset(sources['mine'],'build')
mr,mobs=sample_and_retime(mine,48,lambda f:progress(f)*48,'DEMO_Mine_');mr.location=(3.0,0,0)

def mat(name,color,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.75
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
floor=mat('DemoStudio_Charcoal',(.032,.041,.047));ivory=mat('DemoLabels_Ivory',(.84,.83,.78),.3);muted=mat('DemoLabels_Muted',(.37,.41,.43),.2);gold=mat('DemoLabels_Gold',(.97,.56,.13),.4);red=mat('DemoLabels_Release',(.83,.24,.14),.4)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.06));bpy.context.object.name='DemoStudio_Floor';bpy.context.object.data.materials.append(floor)
bpy.ops.object.camera_add(location=(7,-18,11));cam=bpy.context.object;cam.name='DemoStudio_Camera';target=Vector((0,0,1.8));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=13.5;s.camera=cam
billboard=(cam.rotation_euler.to_quaternion() @ Euler((-math.pi/2,0,0)).to_quaternion()).to_euler()

for name,x,z,pulse_scale in [('Tower',-3.0,4.45,1.05),('Mine',3.0,3.6,1.4)]:
 obs=import_asset(FX/'FS_FX_ProgressFrame.glb');root=next(o for o in obs if o.parent is None);root.location=(x,-.25,z);root.rotation_mode="XYZ";root.rotation_euler=billboard
 fill=next(o for o in obs if o.name.startswith('ProgressFill'))
 for f in range(1,146):fill.scale.x=max(.00001,progress(f));fill.keyframe_insert(data_path='scale',frame=f)
 for o in obs:o.name='DEMO_'+name+'_'+o.name
 obs=import_asset(FX/'FS_FX_BPrompt.glb');root=next(o for o in obs if o.parent is None);root.location=(x,-.25,z-.47);root.rotation_mode="XYZ";root.rotation_euler=billboard
 for f,sc in [(1,1),(120,1),(121,.00001)]:root.scale=(sc,sc,sc);root.keyframe_insert(data_path='scale',frame=f)
 for fc in root.animation_data.action.fcurves:
  for k in fc.keyframe_points:k.interpolation='CONSTANT'
 for o in obs:o.name='DEMO_'+name+'_'+o.name
 obs=import_asset(FX/'FS_FX_Hammer_BuildLoop.glb','Build_HammerLoop')
 hr,ho=sample_and_retime(obs,24,lambda f: ((f-1)%24 if f<49 or 73<=f<121 else 0),'DEMO_'+name+'_Hammer_')
 hr.location=(x+1.36,-.25,z-.72)
 for f,sc in [(1,.58),(120,.58),(121,.00001)]:hr.scale=(sc,sc,sc);hr.keyframe_insert(data_path='scale',frame=f)
 for fc in hr.animation_data.action.fcurves:
  for k in fc.keyframe_points:k.interpolation='CONSTANT'
 obs=import_asset(FX/'FS_FX_CompletionPulse.glb','Complete_GoldPulse')
 cr,co=sample_and_retime(obs,24,lambda f: max(0,f-121),'DEMO_'+name+'_Complete_');cr.location=(x,0,0);cr.scale=(pulse_scale,pulse_scale,pulse_scale)

def camera_text(name,text,x,y,size,material):
 data=bpy.data.curves.new(name,'FONT');data.body=text;data.size=size;data.align_x='LEFT';data.extrude=.0001;data.materials.append(material)
 o=bpy.data.objects.new(name,data);s.collection.objects.link(o);o.parent=cam;o.location=(x,y,-15);return o
camera_text('Title','FIRESIEGE  /  THE CONSTRUCTION KIT',-6.28,3.62,.31,ivory)
camera_text('Subtitle','ACTUAL TOWER + MINE MODELS  /  SHARED BUILD FEEDBACK',-6.28,3.18,.18,muted)
camera_text('Tower_Label','ARROW TOWER',-5.5,-2.62,.21,ivory)
camera_text('Mine_Label','GOLD MINE',1.60,-3.16,.21,ivory)
camera_text('Timing_Notice','ILLUSTRATIVE TIMING  /  ASSET DEMO, NOT GAMEPLAY INTEGRATION',-6.28,-3.64,.17,muted)
for i,(msg,a,b,ma) in enumerate([('HOLD B  /  CONSTRUCTION ADVANCES',1,48,gold),('RELEASE  /  PROGRESS DECAYS',49,72,red),('HOLD B  /  RESUME REMAINING',73,120,gold),('COMPLETE  /  GOLD SPENT ONLY NOW',121,145,gold)]):
 o=camera_text('State_'+str(i),msg,-6.28,-3.22,.23,ma)
 for f,sc in [(1,1 if a==1 else .00001),(max(1,a-1),.00001),(a,1),(b,1),(b+1,.00001)]:o.scale=(sc,sc,sc);o.keyframe_insert(data_path='scale',frame=f)
 if a==1:o.scale=(1,1,1);o.keyframe_insert(data_path='scale',frame=1)
 for fc in o.animation_data.action.fcurves:
  for k in fc.keyframe_points:k.interpolation='CONSTANT'

def light(name,loc,power,size,color):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
light('Studio_Key',(-5,-6,11),2300,8,(1,.82,.65));light('Studio_Fill',(7,-2,9),2400,7,(.65,.79,1));light('Studio_Rim',(0,6,10),3400,7,(1,.64,.31))
s.world=bpy.data.worlds.new('Studio_World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.09,.11,.15,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.45
s.render.engine='BLENDER_EEVEE_NEXT';s.eevee.taa_render_samples=32;s.render.resolution_x=1280;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
s['NOTICE']='Actual model/FX assembly for presentation only. No game project integration. Timing and all state changes are illustrative.'
s['preview_timeline']='1-48 hold/build; 49-72 release/decay; 73-120 resume; 121-145 completion pulse. All presentation timing is illustrative.'
s['gameplay_notes']='Reference metadata only; no game behavior implemented. Mine base income is 2 gold per second during combat only, and zero during setup/pause. L1 tower arrow damage is 50 with 0.5 seconds between shots. Construction gold is charged on completion. Demo timing is illustrative and is not gameplay balance.'
s['gameplay_fire_interval_seconds']=0.5
s['gameplay_shots_per_second']=2
s['gameplay_arrow_damage']=50
s['mine_base_income_gold_per_second']=2
s['mine_income_phase']='combat_only'

s.frame_set(129)
for screen in bpy.data.screens:
 for ar in screen.areas:
  if ar.type=='VIEW_3D':ar.spaces.active.region_3d.view_perspective='CAMERA';ar.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'FireSiege_Combined_Construction_Demo.blend'),compress=True)
(OUT/'qa/source_manifest.json').write_text(json.dumps({'demo_fps':24,'frame_range':[1,145],'timing':'illustrative only','sources':{name:{'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()} for name,path in sources.items()},'frames':{'hold':[1,48],'release_decay':[49,72],'resume':[73,120],'complete':[121,145]},'tower_source_build_frames':[1,72],'mine_source_build_frames':[1,49]},indent=2))
manifest=json.loads((OUT/'qa/source_manifest.json').read_text())
manifest['reference_metadata']={'mine_base_income_gold_per_second':2,'mine_income_phase':'combat_only','tower_l1_fire_interval_seconds':0.5,'tower_l1_arrow_damage':50,'note':'Metadata only; illustration timing is unchanged.'}
(OUT/'qa/source_manifest.json').write_text(json.dumps(manifest,indent=2))
s.render.filepath=str(OUT/'previews/FS_Combined_Construction_Hero.png');bpy.ops.render.render(write_still=True)
print('COMBINED_DEMO_BUILT')
