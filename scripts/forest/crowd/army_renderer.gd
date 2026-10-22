extends Node3D
## One packed upload per spatial batch; no actor or skeleton node per NPC.
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const CELL=32.0
const INSTANCE_CLIPS=["idle","walk","walk_back","primary0","primary1","primary2","primary3","primary4","primary5","primary0_walk","primary1_walk","primary2_walk","primary3_walk","primary4_walk","primary5_walk","primary0_back","primary1_back","primary2_back","primary3_back","primary4_back","primary5_back","shadow_cut","jump","fall","lance_leap","lance_landing","lance_sweep","guard","guard_walk","guard_back","shot","shot_walk","shot_back","ranger_fan","ranger_fan_walk","ranger_fan_back","hurt"]
var game:Node
var _soldier_environment=Vector3.INF
var meshes:Dictionary={}
var resources:Dictionary={}
var full_detail_meshes:Dictionary={}
var distance_meshes:Dictionary={}
var speeds:Dictionary={}
var cadences:Dictionary={}
var batches:Dictionary={}
var health:MultiMeshInstance3D
var submitted=0
var projectile_submitted=0
var presentation:Node3D
var _buffer=PackedFloat32Array()
var native_packer:Object
var native_profiles:Dictionary={}
func configure(owner_:Node):
 game=owner_
 for kind in [0,1,3]:meshes[kind]=Soldier.make_mesh(kind)
 for kind in [11,5,7,8,10]:
  var resource=load("res://assets/characters/ally_crowd/%d.res"%kind);resources[kind]=resource; speeds[kind]=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")[kind].speed
  var profile:Dictionary=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")[kind]
  cadences[kind]=preload("res://scripts/user_stride_run.gd").cadence(speeds[kind]) if preload("res://scripts/user_stride_run.gd").enabled(profile["class"]) else preload("res://scripts/goemon_reference_run_body.gd").cadence(speeds[kind])
  var source_mesh:ArrayMesh=resource.get_meta("mesh")
  var lod_path="res://assets/characters/ally_crowd/lod_%d.res"%kind
  if game.get_tree().get_meta("forest_army_mesh_lods",true) and ResourceLoader.exists(lod_path):
   var detail:ArrayMesh=load(lod_path)
   if detail.get_meta("source_sha256","")==FileAccess.get_sha256("res://assets/characters/ally_crowd/%d.res"%kind):source_mesh=detail
  var mesh:ArrayMesh=source_mesh.duplicate()
  for surface in mesh.get_surface_count():
   var material=ShaderMaterial.new();material.shader=preload("res://assets/materials/ally_crowd.gdshader")
   material.set_shader_parameter("pose_texture",resource.get_meta("pose_texture"));material.set_shader_parameter("surface_properties",resource.get_meta("properties"))
   var texture:Texture2D=resource.get_meta("textures")[surface]
   material.set_shader_parameter("textured",texture!=null)
   if texture!=null:material.set_shader_parameter("albedo_texture",texture)
   mesh.surface_set_material(surface,material)
  meshes[kind]=mesh;distance_meshes[kind]=mesh
  var exact:ArrayMesh=resource.get_meta("mesh").duplicate()
  for surface in exact.get_surface_count():exact.surface_set_material(surface,mesh.surface_get_material(surface))
  full_detail_meshes[kind]=exact
 health=MultiMeshInstance3D.new();health.name="ArmyHealth";health.multimesh=MultiMesh.new();health.multimesh.transform_format=MultiMesh.TRANSFORM_3D;health.multimesh.use_custom_data=true;health.multimesh.mesh=health_mesh();health.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(health)
 presentation=load("res://scripts/forest/crowd/army_presentation.gd").new();add_child(presentation);presentation.configure(game,meshes)
 if game!=null and is_instance_valid(game.get("army_runtime")):use_native_buffers(game.army_runtime.native)
func configure_profiles(data:Dictionary):
 for kind in resources:
  var resource:Resource=data.get("pose_resources",{}).get(kind,load("res://assets/characters/ally_crowd/%d.res"%kind))
  resources[kind]=resource
  # Custom tuned pose atlases may scale attachments beyond the baked error bound.
  # Retain full geometry for these; restoring default tuning restores distance detail.
  var selected:ArrayMesh=full_detail_meshes[kind] if data.get("pose_resources",{}).has(kind) else distance_meshes[kind]
  if meshes[kind]!=selected:
   meshes[kind]=selected
   for key in batches:
    if key.x==kind:batches[key].multimesh.mesh=selected
  var i:int=data.ally_kinds.find(kind)
  speeds[kind]=data.ally_profiles[i*5+1]
  var class_id=preload("res://scripts/rogue_roster.gd").class_id(kind)
  cadences[kind]=preload("res://scripts/user_stride_run.gd").cadence(speeds[kind]) if preload("res://scripts/user_stride_run.gd").enabled(class_id) else preload("res://scripts/goemon_reference_run_body.gd").cadence(speeds[kind])
  for surface in meshes[kind].get_surface_count():meshes[kind].surface_get_material(surface).set_shader_parameter("pose_texture",resource.get_meta("pose_texture"))

 if native_packer!=null:native_profiles=instance_profiles()

func use_native_buffers(packer:Object):
 native_packer=packer;native_profiles=instance_profiles()

func instance_profiles()->Dictionary:
 var kinds=PackedInt32Array();var values=PackedFloat64Array()
 for kind in resources:
  kinds.append(kind);values.append(speeds[kind]);values.append(cadences[kind])
  var clips:Dictionary=resources[kind].get_meta("clips")
  for key in INSTANCE_CLIPS:
   var clip:Dictionary=clips.get(key,{"start":0,"count":1,"duration":1.0})
   values.append_array(PackedFloat64Array([clip.start,clip.count,clip.duration,1 if clip.get("loop",false) else 0,1 if clips.has(key) else 0]))
 return {"kinds":kinds,"values":values}

func health_mesh()->ArrayMesh:
 var a=[];a.resize(Mesh.ARRAY_MAX);var vertices=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
 for fill in 2:
  var w=.94 if fill==0 else .9;var h=.11 if fill==0 else .075;var z=fill*.008;var offset=vertices.size()
  vertices.append_array(PackedVector3Array([Vector3(-w,-h,z),Vector3(w,-h,z),Vector3(w,h,z),Vector3(-w,h,z)]))
  for i in 4:uv.append(Vector2(fill,0))
  for index in [0,1,2,0,2,3]:indices.append(offset+index)
 a[Mesh.ARRAY_VERTEX]=vertices;a[Mesh.ARRAY_TEX_UV2]=uv;a[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 var material=ShaderMaterial.new();material.shader=preload("res://assets/materials/army_health.gdshader");mesh.surface_set_material(0,material);return mesh
func batch(key:Vector3i)->MultiMeshInstance3D:
 if batches.has(key):return batches[key]
 var node=MultiMeshInstance3D.new();node.name="Army_%d_%d_%d"%[key.x,key.y,key.z]
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.mesh=meshes[key.x]
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);batches[key]=node;return node
func pose_sample(s:Dictionary,index:int)->Color:
 var kind:int=s.kinds[index];var action:int=s.render_actions[index];var time:float=s.render_time[index]
 if Soldier.supports(kind):
  if s.pose_rows[index]>=0:return Color(s.pose_rows[index],1.0 if s.status[index]&1 else 0.0,0,0)
  var clip="";var source={"variant":kind,"soldier_tick":time*30,"soldier_pose_tick":s.pose_time[index]*30,"velocity":s.pose_velocities[index],"walk_phase":s.walk_phase[index]}
  if action in [1,2,3,4,5]:
   clip={1:"Source__801b0118",2:"Source__801afd28",3:"Source__801b01e0",4:"Source__801b0d50",5:"Source__801b0e48"}[action];source.soldier_action="attack";source.soldier_clip=clip
  if action==6:source.soldier_hurt_clip="Source__801b02a8";source.soldier_hurt_left=1;source.soldier_hurt_tick=(16.0/30-s.stun_left[index])*30
  return Color(Soldier.frame_state(source).row,1.0 if s.status[index]&1 else 0.0,0,0)
 var clips:Dictionary=resources[kind].get_meta("clips");var key="idle";var moving_key="idle";var t:float=s.pose_time[index];var moving_t=t
 var velocity:Vector3=s.pose_velocities[index];var speed=Vector2(velocity.x,velocity.z).length();var motion=velocity.dot(Vector3(sin(s.yaw[index]),0,cos(s.yaw[index])))
 var suffix="_walk" if motion>=0 else "_back";var strength=clampf(speed/maxf(.001,speeds[kind]),0,1)
 if action==8:key="primary%d"%s.action_indices[index];moving_key=key+suffix;t=time;moving_t=time
 elif action==9:key="shadow_cut";moving_key=key;t=time;moving_t=time;strength=0
 elif action==10:key="jump" if s.air_phase[index] in [3,5] else ("fall" if s.air_phase[index]==4 else "lance_leap");moving_key=key;t=time;moving_t=time;strength=0
 elif action==11:key="lance_landing";moving_key="walk" if motion>=0 else "walk_back";t=time;moving_t=s.walk_phase[index]/TAU/cadences[kind]
 elif action==16:key="lance_sweep";moving_key=key;t=time;moving_t=time;strength=0
 elif action==13:key="guard";moving_key="guard_walk" if motion>=0 else "guard_back"
 elif action==12:key="shot" if kind==5 else "ranger_fan";moving_key=key+suffix;t=time;moving_t=time
 elif action==6:key="hurt";moving_key=key;t=time;moving_t=time;strength=0
 else:moving_key="walk" if motion>=0 else "walk_back";moving_t=s.walk_phase[index]/TAU/cadences[kind]
 if not clips.has(key):key="idle"
 if not clips.has(moving_key):moving_key=key;strength=0
 return Color(clip_row(clips[key],t),clip_row(clips[moving_key],moving_t),strength+(2.0 if s.status[index]&1 else 0.0),s.flash_left[index])
func clip_row(clip:Dictionary,time:float)->float:
 var sample=fposmod(time,float(clip.duration))*60 if clip.get("loop",false) else clampf(time*60,0,int(clip.count)-1)
 return float(clip.start)+sample

func write_instance(index:int,pose:Transform3D,color:Color):
 var at=index*16
 for row in 3:
  _buffer[at+row*4]=pose.basis.x[row];_buffer[at+row*4+1]=pose.basis.y[row];_buffer[at+row*4+2]=pose.basis.z[row];_buffer[at+row*4+3]=pose.origin[row]
 _buffer[at+12]=color.r;_buffer[at+13]=color.g;_buffer[at+14]=color.b;_buffer[at+15]=color.a
func upload(node:MultiMeshInstance3D,buffer:PackedFloat32Array,bounds:AABB):
 var mm=node.multimesh;var count=buffer.size()/16
 node.visible=count>0
 if count==0:mm.visible_instance_count=0;return
 if mm.instance_count<count:mm.instance_count=nearest_po2(count)
 buffer.resize(mm.instance_count*16)
 mm.buffer=buffer;mm.custom_aabb=bounds;mm.visible_instance_count=count
func present(snapshot:Dictionary,_events:Array):
 var profiler=game.army_runtime if game!=null and is_instance_valid(game.get("army_runtime")) and game.army_runtime.profile_enabled else null
 var clock=Time.get_ticks_usec() if profiler!=null else 0
 var environment=get_world_3d().environment
 var environment_key=Vector3(environment.tonemap_exposure,environment.tonemap_white,float(environment.tonemap_mode)) if environment!=null else Vector3.ZERO
 if _soldier_environment!=environment_key:
  for kind in [0,1,3]:Soldier.update_environment(meshes[kind],environment)
  _soldier_environment=environment_key
 presentation.present(_events)
 if profiler!=null:clock=profiler.profile_mark("renderer_events",clock)
 presentation.present_snapshot(snapshot);projectile_submitted=presentation.projectile_count
 if profiler!=null:clock=profiler.profile_mark("renderer_projectiles",clock)
 if native_packer!=null:
  var data:Dictionary=native_packer.instance_buffers(snapshot,native_profiles)
  if profiler!=null:clock=profiler.profile_mark("renderer_packing",clock)
  if data.get("valid",false):
   var active={};submitted=data.submitted
   for row:Dictionary in data.batches:active[row.key]=true;upload(batch(row.key),row.buffer,row.bounds)
   for key in batches:
    if not active.has(key):batches[key].multimesh.visible_instance_count=0;batches[key].hide()
   upload(health,data.health,AABB(Vector3(-1000,-1000,-1000),Vector3.ONE*2000))
   if profiler!=null:profiler.profile_mark("renderer_uploads",clock)
   return
 var groups={};var allies=PackedInt32Array();submitted=0
 for i in snapshot.handles.size():
  var kind:int=snapshot.kinds[i]
  if not meshes.has(kind) or (snapshot.status[i]&64 and kind!=8):continue
  var position_:Vector3=snapshot.positions[i];var key=Vector3i(kind,floori(position_.x/CELL),floori(position_.z/CELL))
  if not groups.has(key):groups[key]=PackedInt32Array()
  groups[key].append(i);submitted+=1
  if snapshot.teams[i]==1:allies.append(i)
 for key in batches:
  if not groups.has(key):batches[key].multimesh.visible_instance_count=0;batches[key].hide()
 for key in groups:
  var indices:PackedInt32Array=groups[key];_buffer=PackedFloat32Array();_buffer.resize(indices.size()*16);var low=INF;var high=-INF
  for row in indices.size():
   var i=indices[row];var position_:Vector3=snapshot.positions[i];low=minf(low,position_.y);high=maxf(high,position_.y)
   write_instance(row,Transform3D(Basis(Vector3.UP,snapshot.yaw[i]),position_),pose_sample(snapshot,i))
  upload(batch(key),_buffer,AABB(Vector3(key.y*CELL-12,low-4,key.z*CELL-12),Vector3(CELL+24,high-low+20,CELL+24)))
 _buffer=PackedFloat32Array();_buffer.resize(allies.size()*16)
 for row in allies.size():
  var i=allies[row];write_instance(row,Transform3D(Basis.IDENTITY,snapshot.positions[i]+Vector3.UP*3.0),Color(clampf(snapshot.hp[i]/snapshot.max_hp[i],0,1),1,0,0))
 upload(health,_buffer,AABB(Vector3(-1000,-1000,-1000),Vector3.ONE*2000))
func clear():
 for node in batches.values():node.multimesh.visible_instance_count=0;node.hide()
 if is_instance_valid(health):health.multimesh.visible_instance_count=0
 submitted=0;projectile_submitted=0
 if is_instance_valid(presentation):presentation.clear()
func counts()->Dictionary:return {"units":submitted,"batches":batches.size(),"health":health.multimesh.visible_instance_count if is_instance_valid(health) else 0,"projectiles":projectile_submitted}
