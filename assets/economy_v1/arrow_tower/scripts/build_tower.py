import bpy, math, os, json, random
from mathutils import Vector
ROOT='/workspace/scratch/23f1a29e8f92/tower_assets_v1'
random.seed(8)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.materials,bpy.data.collections,bpy.data.actions):
    for d in list(datablocks):
        if getattr(d,'users',0)==0: datablocks.remove(d)
scene=bpy.context.scene; scene.name='01_COMPLETE_TOWER'
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
scene.render.fps=24
materials={}
def mat(name,c,metal=0,rough=.72):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    materials[name]=m;return m
wood=mat('FS_Timber_Cedar',(0.33,.16,.063));woodlight=mat('FS_Timber_Edge',(0.46,.255,.105));wooddark=mat('FS_Timber_Endgrain',(.22,.093,.035));iron=mat('FS_Iron',(.057,.071,.082),.7,.38);ironedge=mat('FS_Iron_Edge',(.20,.235,.245),.68,.33);stone=mat('FS_Stone_Gray',(.33,.35,.33));stone2=mat('FS_Stone_Light',(.43,.445,.405));roof=mat('FS_Roof_Slate',(.048,.067,.078));roof2=mat('FS_Roof_Slate_Light',(.070,.088,.101));rope=mat('FS_Rope',(.60,.47,.25));gold=mat('FS_Gold',(.83,.47,.055),.65,.34)
asset=bpy.data.collections.new('TOWER_CANONICAL_PARTS');scene.collection.children.link(asset)
wall=bpy.data.collections.new('OPTIONAL_WALL_MOUNT');scene.collection.children.link(wall)
preview=bpy.data.collections.new('PREVIEW_ONLY');scene.collection.children.link(preview)
parts=[]
def move(o,coll):
    for c in list(o.users_collection):c.objects.unlink(o)
    coll.objects.link(o)
def register(o,name,material,stage=0,coll=asset,parent=None):
    o.name=name;o.data.name=name+'_mesh' if o.type=='MESH' else name+'_data'
    move(o,coll)
    if material:o.data.materials.append(material)
    o['stable_id']='firesiege.tower.'+name.lower();o['stage_min']=stage
    if coll==asset:parts.append(o)
    if parent:o.parent=parent
    return o
def cube(name,loc,dim,material,stage=0,bevel=.025,coll=asset,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=dim
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Crafted bevel','BEVEL');m.width=bevel;m.segments=2
        m=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return register(o,name,material,stage,coll,parent)
def cyl(name,loc,r,depth,material,stage=0,vertices=12,coll=asset,parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc)
    o=bpy.context.object;m=o.modifiers.new('Edge bevel','BEVEL');m.width=.012;m.segments=2
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return register(o,name,material,stage,coll,parent)
def beam(name,a,b,width,depth,material,stage=0,coll=asset,parent=None):
    a,b=Vector(a),Vector(b);o=cube(name,(a+b)/2,(width,depth,(b-a).length),material,stage,.014,coll,parent)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def mesh(name,verts,faces,material,stage=0,coll=asset,parent=None,bevel=0):
    me=bpy.data.meshes.new(name+'_mesh');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);coll.objects.link(o)
    if bevel:
        mod=o.modifiers.new('Soft carved edges','BEVEL');mod.width=bevel;mod.segments=2;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return register(o,name,material,stage,coll,parent)
def empty(name,loc=(0,0,0),coll=asset,parent=None):
    o=bpy.data.objects.new(name,None);coll.objects.link(o);o.empty_display_type='PLAIN_AXES';o.empty_display_size=.25;o.location=loc;o['stable_id']='firesiege.tower.'+name.lower()
    if parent:o.parent=parent
    return o
root=empty('TOWER_ROOT');root['units']='meters';root['forward_axis']='-Y';root['up_axis']='+Z';root['pivot']='ground-center';root['ground_footprint_m']=[2.8,2.8];root['asset_version']='1.0'
# Separated readable foundation and timber deck. All positions in local meters.
for x in (-1.05,1.05):
 for y in (-1.05,1.05):
    cube('stone_foot_%s_%s'%('L' if x<0 else 'R','F' if y<0 else 'B'),(x,y,.13),(.65,.65,.26),stone2,0,.065)
for y,label in ((-1.18,'front'),(1.18,'back')):cube('base_beam_'+label,(0,y,.345),(2.8,.32,.28),wood,0,.035)
for x,label in ((-1.18,'left'),(1.18,'right')):cube('base_beam_'+label,(x,0,.345),(.32,2.35,.28),wood,0,.035)
for i in range(7):cube('deck_plank_%02d'%i,((i-3)*.318,0,.49),(.309,2.36,.16),woodlight if i%3==0 else wood,0,.014)
# Four clean, tapered timber pillars and broad metal collars.
for x,lr in ((-1.02,'L'),(1.02,'R')):
 for y,fb in ((-1.02,'F'),(1.02,'B')):
    tag=lr+fb
    cube('post_'+tag,(x,y,1.70),(.26,.26,2.44),wood,1,.028)
    for z,k in ((.68,'low'),(2.71,'high')):
        cube('post_iron_'+tag+'_'+k,(x,y,z),(.29,.29,.16),iron,1,.012)
        # Bolts visible on outer faces; stable separate mesh.
        for ax in ['X','Y']:
            lo=[x,y,z];lo[0 if ax=='X' else 1]+=(1 if (x if ax=='X' else y)>0 else -1)*.154
            o=cyl('bolt_'+tag+'_'+k+'_'+ax,lo,.033,.022,ironedge,1,8)
            o.rotation_euler=(0,math.pi/2,0) if ax=='X' else (math.pi/2,0,0)
    cube('post_cap_'+tag,(x,y,2.94),(.29,.29,.14),woodlight,1,.022)
for y,lab in ((-1.02,'front'),(1.02,'back')):cube('upper_beam_'+lab,(0,y,2.70),(2.26,.20,.22),woodlight,1,.020)
for x,lab in ((-1.02,'left'),(1.02,'right')):cube('upper_beam_'+lab,(x,0,2.70),(.20,2.26,.22),woodlight,1,.020)
# Kneebraces and rails preserve open firing aperture.
for y,fb in ((-1.02,'F'),(1.02,'B')):
 for x,lr in ((-1.02,'L'),(1.02,'R')):
    beam('knee_'+lr+fb,(x,y,2.25),(x*.50,y,2.65),.12,.16,wood,2)
for x,lab in ((-1.02,'left'),(1.02,'right')):
    cube('rail_'+lab,(x,.05,1.18),(.13,1.95,.15),woodlight,2,.020)
    for j,y in enumerate((-.50,.28,.82)):
        cube('baluster_'+lab+str(j),(x,y,.90),(.10,.10,.58),wood,2,.012)
    cube('sill_'+lab,(x,0,.66),(.20,2.20,.18),wood,2,.020)
cube('rail_back',(0,1.02,1.18),(2.18,.13,.15),woodlight,2,.02)
for i,x in enumerate((-.55,0,.55)):cube('baluster_back'+str(i),(x,1.02,.90),(.10,.10,.57),wood,2,.012)
# Little low front lip, with central firing opening above.
cube('front_deck_lip',(0,-1.20,.72),(2.36,.10,.30),wood,2,.02)
for x,lab in ((-1.02,'left'),(1.02,'right')):
    cube('side_iron_foot_'+lab,(x,-1.155,.53),(.19,.16,.38),iron,2,.012)
# Roof: curved eaves, solid panel slabs, broad restrained slate rows.
profile=[(0,3.56),(.42,3.42),(.90,3.15),(1.38,2.92),(1.70,2.98)]
for side,sgn in (('L',-1),('R',1)):
 for j in range(len(profile)-1):
    x1,z1=profile[j];x2,z2=profile[j+1];x1*=sgn;x2*=sgn
    # 5 wide tile-like bands along roof depth, more silhouette than texture.
    for k in range(5):
        ya=-1.53+k*.612;yb=ya+.600;t=.075
        vs=[(x1,ya,z1),(x2,ya,z2),(x2,yb,z2),(x1,yb,z1),(x1,ya,z1-t),(x2,ya,z2-t),(x2,yb,z2-t),(x1,yb,z1-t)]
        fs=[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
        mesh('roof_'+side+'_%d_%d'%(j,k),vs,fs,roof if (j+k)%3 else roof2,3,bevel=.008)
 # Exposed curved gable fascia.
 for y,fb in ((-1.56,'front'),(1.56,'back')):
    for j in range(4):
        (x1,z1),(x2,z2)=profile[j],profile[j+1]
        beam('fascia_'+side+'_'+fb+str(j),(sgn*x1,y,z1-.015),(sgn*x2,y,z2-.015),.14,.12,iron,3)
    # Upturned eave end cap.
    cube('eave_tip_'+side+'_'+fb,(sgn*1.69,y,3.045),(.17,.21,.21),iron,3,.022)
 beam('roof_eave_'+side,(sgn*1.68,-1.52,2.95),(sgn*1.68,1.52,2.95),.14,.14,wooddark,3)
# Ridge cap, gold-capped center joinery (small restrained detail).
cube('roof_ridge',(0,0,3.59),(.21,3.25,.17),iron,3,.023)
for y,label in ((-1.60,'front'),(1.60,'back')):
    cube('ridge_finial_'+label,(0,y,3.67),(.24,.21,.23),iron,3,.022)
    beam('gable_left_'+label,(-.98,y*.67,2.78),(0,y*.67,3.42),.16,.16,woodlight,2)
    beam('gable_right_'+label,(.98,y*.67,2.78),(0,y*.67,3.42),.16,.16,woodlight,2)
# Launcher: own pivot hierarchy. All children have origin-relative positions after parenting below.
pivot=empty('LAUNCHER_YAW',(0,-.05,.59));pivot['socket']='launcher_upgrade';pivot['stage_min']=2
cyl('launcher_turntable',(0,-.05,.64),.43,.14,iron,2,20)
cyl('launcher_wood_plate',(0,-.05,.74),.36,.09,wooddark,2,20)
cube('launcher_pedestal',(0,-.05,1.12),(.22,.24,.68),wood,2,.024)
cube('launcher_pedestal_iron',(0,-.05,1.33),(.26,.28,.14),iron,2,.014)
# Static supporting fork.
for x,lab in ((-.19,'L'),(.19,'R')):
    cube('launcher_fork_'+lab,(x,-.05,1.55),(.12,.29,.49),woodlight,2,.020)
    o=cyl('launcher_axle_'+lab,(x*1.43,-.05,1.63),.065,.06,ironedge,2,12);o.rotation_euler[1]=math.pi/2
recoil=empty('LAUNCHER_RECOIL',(0,0,0));recoil['stage_min']=2
launchparts=[]
def launch(o):launchparts.append(o);return o
launch(cube('crossbow_stock',(0,-.25,1.72),(.19,1.65,.15),woodlight,2,.02))
launch(cube('crossbow_slide',(0,-.16,1.80),(.082,1.18,.028),iron,2,.006))
launch(cube('crossbow_lock',(0,.48,1.79),(.24,.16,.25),iron,2,.016))
for s,label in ((-1,'L'),(1,'R')):
    pts=[(0,-.70,1.73),(s*.39,-.75,1.73),(s*.76,-.59,1.73),(s*1.02,-.34,1.73)]
    for j in range(3):
        launch(beam('bow_limb_'+label+str(j),pts[j],pts[j+1],.10,.095,wooddark,2))
    launch(cube('bow_tip_'+label,(s*1.02,-.34,1.73),(.13,.11,.12),iron,2,.014))
    launch(beam('bow_string_'+label,(s*1.02,-.34,1.75),(0,.40,1.79),.025,.025,rope,2))
    launch(cube('limb_iron_binding_'+label,(s*.30,-.74,1.73),(.13,.14,.14),iron,2,.008))
launch(cube('crossbow_front_brace',(0,-.68,1.72),(.38,.20,.29),iron,2,.020))
# Arrow projectile own assembly and muzzle socket.
arrow=empty('ARROW_PROJECTILE',(0,0,0));arrow['stage_min']=2;arrow['projectile_forward']='-Y'
arrowparts=[]
arrowparts.append(beam('arrow_shaft',(0,.48,1.86),(0,-1.38,1.86),.045,.045,woodlight,2))
arrowparts.append(mesh('arrow_head',[(0,-1.72,1.86),(-.12,-1.37,1.86),(0,-1.38,1.93),(.12,-1.37,1.86),(0,-1.38,1.79)],[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(1,4,3,2)],ironedge,2))
for i,ang in enumerate((0,2*math.pi/3,4*math.pi/3)):
    v=[(0,.37,1.86),(0,.56,1.86),(math.cos(ang)*.09,.56,1.86+math.sin(ang)*.09),(math.cos(ang)*.09,.37,1.86+math.sin(ang)*.09)]
    arrowparts.append(mesh('arrow_fletching_'+str(i),v,[(0,1,2,3)],roof2,2))
muzzle=empty('SOCKET_ARROW_MUZZLE',(0,-1.73,1.86));muzzle['socket']='arrow_spawn';muzzle['stage_min']=2
fxsocket=empty('SOCKET_BUILD_FX',(0,0,3.90));fxsocket['socket']='construction_ui'
# Parent all meshes to root while keeping coordinates; launcher groups carry recoil.
for o in parts:o.parent=root
pivot.parent=root;recoil.parent=root;arrow.parent=root;muzzle.parent=root;fxsocket.parent=root
for o in launchparts:o.parent=recoil
for o in arrowparts:o.parent=arrow
# Detachable wall collar: designed for wall-top origin, no assumed wall mesh.
wallroot=empty('WALL_MOUNT_ROOT',coll=wall);wallroot['pivot']='wall_top_center';wallroot['wall_thickness_range_m']=[.6,1.0];wallroot['attach_tower_root_z']=0.0
for y,lab in ((-.58,'front'),(.58,'back')):
    cube('wall_collar_'+lab,(0,y,-.20),(2.66,.18,.38),wood,0,.025,wall,wallroot)
    for x,side in ((-.95,'L'),(.95,'R')):
        cube('wall_hook_'+lab+side,(x,y,-.33),(.19,.21,.58),iron,0,.015,wall,wallroot)
        beam('wall_brace_'+lab+side,(x,y,-.50),(x,y*1.9,.24),.12,.16,wooddark,0,wall,wallroot)
wall.hide_render=True;wall.hide_viewport=True
# Applied modifier counts evaluated, not destructive to editable source.
for o in parts:
    o['part_role']='projectile' if o in arrowparts else 'construction'
    o['completed_local_transform']=list(o.location)
# root is origin; no blender render extras in exports
scene.world.color=(.16,.16,.16)
world=scene.world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.24,.29,.34,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5
backmat=mat('Preview_Backdrop',(.24,.265,.28))
floor=cube('PREVIEW_GROUND',(0,0,-.095),(200,200,.1),backmat,0,.0,preview)
def aim(o,at):o.rotation_euler=(Vector(at)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,energy,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);preview.objects.link(o);o.location=loc;aim(o,(0,0,1.5))
area('Key_softbox',(-4,-5,8),1050,5);area('Fill_softbox',(5,-1,5),700,4);area('Rim_softbox',(1,5,7),1400,4)
d=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',d);preview.objects.link(cam);scene.camera=cam;d.type='ORTHO';d.ortho_scale=5.9
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
# Frame rates and native named stage scenes; snapshots retain truly separate objects.
baseobjs=list(asset.objects)
for label,maxstage in [('00_EMPTY_BASE',0),('10_FRAME',1),('20_ASSEMBLING',2),('30_COMPLETE',3)]:
    coll=bpy.data.collections.new('STAGE_'+label)
    # Stages linked to separate scenes to avoid overlap; open scene selector to inspect.
    ss=bpy.data.scenes.new('STAGE_'+label);ss.collection.children.link(coll);ss.unit_settings.system='METRIC'
    mapping={}
    for o in baseobjs:
        if o.type!='MESH' or o.get('stage_min',0)<=maxstage:
            no=o.copy();no.name='S'+str(maxstage)+'__'+o.name;coll.objects.link(no);mapping[o]=no
    for src,no in mapping.items():
        no.parent=mapping.get(src.parent);no['source_stable_id']=src.get('stable_id','')
        if no.type=='EMPTY':no.hide_render=True
    ss['progress_normalized']=[0,.33,.66,1][maxstage]
# GLB static exports independently selected, no stage duplicates or studio.
bpy.context.window.scene=scene
for o in bpy.context.selected_objects:o.select_set(False)
def select_stage(maxstage,wallonly=False):
    bpy.ops.object.select_all(action='DESELECT')
    for o in (list(wall.objects) if wallonly else baseobjs):
        if wallonly or o.type!='MESH' or o.get('stage_min',0)<=maxstage:o.select_set(True)
def exp(filename,animations=False):
    bpy.ops.export_scene.gltf(filepath=ROOT+'/exports/'+filename,export_format='GLB',use_selection=True,export_extras=True,export_apply=True,export_yup=True,export_animations=animations,export_animation_mode='SCENE',export_nla_strips_merged_animation_name='Tower_Build_Recoil_Reverse',export_force_sampling=True,export_frame_range=True)
for label,maxstage in [('empty',0),('frame',1),('assembling',2),('complete',3)]:
    select_stage(maxstage);exp('tower_stage_'+label+'.glb')
wall.hide_viewport=False;select_stage(3,True);exp('tower_wall_mount.glb');wall.hide_viewport=True
# Render clean front, side, and front quarter before animation.
for name,loc in [('quarter',(5.8,-8.5,5.7)),('front',(0,-9,3.9)),('side',(9,0,3.9))]:
    cam.location=loc;aim(cam,(0,-.03,1.80));scene.render.filepath=ROOT+'/renders/tower_'+name+'.png';bpy.ops.render.render(write_still=True)
# Animation: scale & gentle lift reveal. Exact progress controls are engine tasks, not game code.
# Timeline 1-72 build, 73-91 hold/fire, 92-108 settle, 109-180 reverse.
scene.frame_start=1;scene.frame_end=180
stage_windows={0:(1,1),1:(9,29),2:(30,52),3:(53,72)}
orig={o.name:(o.location.copy(),o.scale.copy()) for o in parts}
def key(o,f,loc,scale):
    o.location=loc;o.scale=scale;o.keyframe_insert(data_path='location',frame=f);o.keyframe_insert(data_path='scale',frame=f)
for o in parts:
    loc,sc=orig[o.name];stage=o['stage_min'];start,end=stage_windows[stage]
    if stage==0:
        key(o,1,loc,sc);key(o,180,loc,sc);continue
    # ordered pieces within each tier, reverse follows exactly.
    index=[p for p in parts if p['stage_min']==stage].index(o)
    num=len([p for p in parts if p['stage_min']==stage]);a=start+(end-start-7)*index/max(1,num-1);b=a+7
    key(o,1,loc+Vector((0,0,.4)),Vector((.001,.001,.001)))
    key(o,a,loc+Vector((0,0,.4)),Vector((.001,.001,.001)))
    key(o,b,loc,sc);key(o,108,loc,sc)
    key(o,181-b,loc,sc);key(o,181-a,loc+Vector((0,0,.4)),Vector((.001,.001,.001)))
    key(o,180,loc+Vector((0,0,.4)),Vector((.001,.001,.001)))
# Recoil and launched arrow along -Y in self contained preview. Arrow scale resets after travel.
for f,y in [(1,0),(79,0),(82,.16),(88,0),(180,0)]:recoil.location.y=y;recoil.keyframe_insert(data_path='location',frame=f)
for f,y,sz in [(1,0,1),(81,0,1),(91,-5,1),(92,-5,.001),(94,0,.001),(98,0,1),(180,0,1)]:
    arrow.location.y=y;arrow.scale=(sz,)*3;arrow.keyframe_insert(data_path='location',frame=f);arrow.keyframe_insert(data_path='scale',frame=f)
for o in parts+[arrow,recoil]:
    if o.animation_data and o.animation_data.action:
        o.animation_data.action.name='TOWER_PREVIEW__'+o.name
        for fc in o.animation_data.action.fcurves:
            for kp in fc.keyframe_points:kp.interpolation='LINEAR'
scene.timeline_markers.new('EMPTY BASE / ready to build',frame=1)
for name,f in [('FRAME',29),('ASSEMBLING',52),('COMPLETE / spend 5 gold in game',72),('FIRE 50 damage in game',81),('REVERSE preview',109),('EMPTY BASE',180)]:scene.timeline_markers.new(name,frame=f)
scene.frame_set(72)
select_stage(3);exp('tower_build_recoil_reverse.glb',True)
# Keep actual export-only rig in 02 scene, static complete and independent snapshots remain available.
scene.name='02_BUILD_RECOIL_REVERSE_PREVIEW'
cam.location=(5.8,-8.5,5.7);aim(cam,(0,-.15,1.70));cam.data.ortho_scale=6.0
scene.render.resolution_x=800;scene.render.resolution_y=800;scene.cycles.samples=12
scene['preview_timeline']='1-72 build; 79-91 recoil and arrow; 109-180 reverse construction'
scene['gameplay_notes']='Asset demo only. Initially no towers. 4 wall sites + 8 entrance sites. Hold B builds; release decays; resume remaining. Spend 5 gold at completion. Enemies 100 HP; level-1 arrow 50 damage. Confirmed gameplay: one shot every 0.5 seconds (2 shots per second). Time-based gold drain per built tower during combat is required; drain rate and zero-wallet behavior remain unresolved. Preview animation timing is illustrative and unchanged. No engine integration.'
for target in [scene,root]:
    for key,value in {'gameplay_fire_interval_seconds': 0.5, 'gameplay_shots_per_second': 2, 'gameplay_arrow_damage': 50, 'gameplay_combat_drain_required': True, 'gameplay_combat_drain_scope': 'time-based per built tower during combat', 'gameplay_combat_drain_rate': 'unresolved', 'gameplay_zero_wallet_behavior': 'unresolved'}.items():target[key]=value
scene.frame_set(72)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/firesiege_arrow_tower_v1.blend',compress=True)
# Rich manifest and metrics.
deps=bpy.context.evaluated_depsgraph_get();v=0;t=0
for o in parts:
    e=o.evaluated_get(deps);me=e.to_mesh();me.calc_loop_triangles();v+=len(me.vertices);t+=len(me.loop_triangles);e.to_mesh_clear()
bounds=[o.matrix_world@Vector(c) for o in parts for c in o.bound_box]
manifest={'asset':'Fire Siege Japanese-inspired arrow tower','version':'1.0','native_format':'Blender 4.3.2','units':'meters','blender_axes':{'up':'+Z','forward':'-Y','pivot':'ground-center (0,0,0)'},'gltf_axes':{'up':'+Y','forward':'+Z','conversion':'standard Blender glTF axis conversion'},'core_footprint_m':[2.8,2.8],'bounds_complete_m':{'min':[min(p[i] for p in bounds) for i in range(3)],'max':[max(p[i] for p in bounds) for i in range(3)]},'mesh_count':len(parts),'evaluated_vertices':v,'evaluated_triangles':t,'materials':[m.name for m in materials.values() if not m.name.startswith('Preview')],'stages':{'empty':0,'frame':1,'assembling':2,'complete':3},'stage_scene_note':'Each STAGE scene owns a discrete independently inspectable collection. GLB stage exports contain cumulative parts at that stage.','animation':{'fps':24,'frame_start':1,'frame_end':180,'build':[1,72],'fire':[79,91],'reverse':[109,180],'gltf_clip':'Scene animation: inspect GLB report for exact name','animated_channels':'scale/location, no visibility keys needed'},'mounting':'Ground version includes four stone feet. Wall collar is separate GLB, pivot at wall top; remove stone_foot_* meshes for wall placement, attach collar and tower at same wall-top origin. Wall mesh is not included.','sockets':{'SOCKET_ARROW_MUZZLE':[0,-1.73,1.86],'SOCKET_BUILD_FX':[0,0,3.90],'launcher_upgrade_pivot':[0,-.05,.59]},'gameplay_not_implemented':{'starting_towers':0,'wall_sites':4,'entrance_sites':8,'input':'Hold B; release progress decays, resume from remaining','cost_on_completion_gold':5,'enemy_hp':100,'arrow_damage':50,'fire_interval_seconds':0.5,'shots_per_second':2,'combat_drain':{'required':True,'basis':'time-based per built tower during combat','gold_per_second':None,'zero_wallet_behavior':None}},'upgrade_note':'Cannon level count unresolved; no fixed upgrade levels encoded.','parts':[{'stable_id':o['stable_id'],'name':o.name,'stage_min':o['stage_min'],'parent':o.parent.name if o.parent else None} for o in parts],'verification':'See verification_report.json after GLB reimport'}
with open(ROOT+'/asset_manifest.json','w') as f:json.dump(manifest,f,indent=2)
print('TOWER_READY',len(parts),v,t)
