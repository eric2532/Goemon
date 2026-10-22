extends HeroModel
## Recovered rigid-part characters with separate in-place controller actions.
const PROPORTIONS=preload("res://scripts/character_proportions.gd")
const PALETTE=preload("res://assets/characters/recovered_leaders/source_palette.gdshader")
var character_id=14
var combat: Node
var animation_player: AnimationPlayer
var current_clip=""
var state="idle"
var clock=0.0
var gait_phase=0.0
var air_clock=0.0
var landing_clock=-1.0
var was_grounded=true
var was_moving=false
var last_jump=0
var last_vertical=0.0
var palette_materials=[]
var palette_environment=Vector3(-1,-1,-1)
var clips={}
var blend_from=[]
var blend_left=0.0
var hand_bones=[2,4]
var sword_trail: MeshInstance3D
var flight_clock=0.0
var was_flying=false
var flight_landing=false
var ben_accessory_meshes: Array[MeshInstance3D]=[]
static var ben_bomb_rom_frames: Array[Dictionary]=[]

class MotionBridge extends RefCounted:
	var step_events=0
	var jump_compression=0.0
	var free_feet=false
	var travel=0.0
	func reset():travel=0;step_events=0
	func evaluate():pass
	func tick(delta: float,speed: float,grounded: bool):
		if grounded:
			travel+=speed*delta
			if travel>=1.8:step_events+=floori(travel/1.8);travel=fmod(travel,1.8)

func _ready():
	body=Node3D.new();body.name="RecoveredLeaderBody";add_child(body)
	var key="ed" if character_id==14 else "ben"
	if character_id==15:hand_bones=[4,2]
	rig_visual=load("res://assets/characters/recovered_leaders/%s/model.glb"%key).instantiate();body.add_child(rig_visual)
	skeleton=rig_visual.find_child("Skeleton3D",true,false)
	animation_player=rig_visual.find_child("AnimationPlayer",true,false)
	assert(skeleton!=null and animation_player!=null,"Recovered leaders require their original part rig and motions")
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name_ in animation_player.get_animation_list():
		if name_.begins_with("Derived_"):clips[name_.trim_prefix("Derived_")]=name_
		for i in range(40):
			if "source_%02d__"%i in name_:clips["source_%02d"%i]=name_
	for key_ in ["Walk","Run","JumpRise","JumpAir","JumpFall","Land"]:assert(clips.has(key_),"Missing playable motion: "+key_)
	var bounds=AABB();var first=true
	for mesh in rig_visual.find_children("*","MeshInstance3D",true,false):
		var box: AABB=rig_visual.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	var fit=PROPORTIONS.ED_HEIGHT/maxf(.01,bounds.size.y) if character_id==14 else PROPORTIONS.BEN_MODEL_SCALE
	rig_visual.scale=Vector3.ONE*fit;rig_visual.position.y=-bounds.position.y*fit if character_id==14 else 0.0;rig_visual.rotation.y=PI
	_install_palette()
	head=_placeholder("HeadCompatibility");arms.assign([_placeholder("ArmL"),_placeholder("ArmR")]);legs.assign([_placeholder("LegL"),_placeholder("LegR")])
	pipe=_placeholder("PipeCompatibility");coin=_placeholder("CoinCompatibility");scarf=_placeholder("ScarfCompatibility")
	hair_normal=_placeholder("HairCompatibility");hair_gold=_placeholder("SurgeCompatibility")
	locomotion=MotionBridge.new();process_priority=30
	_sample(motion("source_12" if character_id==15 else "source_00"),0,0,true)
	if character_id==15:
		for part in range(12,16):
			ben_accessory_meshes.append(rig_visual.find_child("%02d_source_part_%02d"%[part,part],true,false))
		sword_trail=preload("res://scripts/recovered_leader_trail.gd").new();sword_trail.name="BenGuandaoTrail";add_child(sword_trail)

func _placeholder(label_: String)->Node3D:
	var node=Node3D.new();node.name=label_;body.add_child(node);node.hide();return node
func motion(key: String)->String:return str(clips.get(key,clips.get("source_00","")))
func duration(key: String)->float:return animation_player.get_animation(motion(key)).length
func _install_palette():
	var cache={}
	for mesh in rig_visual.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(surface) as BaseMaterial3D
			if original==null:continue
			if not cache.has(original):
				var material=ShaderMaterial.new();material.shader=PALETTE
				material.set_shader_parameter("tint_color",original.albedo_color)
				material.set_shader_parameter("textured",original.albedo_texture!=null)
				if original.albedo_texture!=null:material.set_shader_parameter("albedo_texture",original.albedo_texture)
				cache[original]=material;palette_materials.append(material)
			mesh.set_surface_override_material(surface,cache[original])
func _sync_palette():
	var env=get_world_3d().environment;var settings=Vector3(0,1,1)
	if env!=null:settings=Vector3(1 if env.tonemap_mode==Environment.TONE_MAPPER_FILMIC else 0,env.tonemap_exposure,env.tonemap_white)
	if settings==palette_environment:return
	palette_environment=settings
	for mat in palette_materials:
		mat.set_shader_parameter("compensate_filmic",settings.x>0);mat.set_shader_parameter("scene_exposure",settings.y);mat.set_shader_parameter("scene_white",settings.z)
func _sample(clip: String,time: float,delta: float,loop: bool=false):
	if current_clip!=clip:
		blend_from.clear()
		for i in skeleton.get_bone_count():blend_from.append(skeleton.get_bone_pose(i))
		var native_ben_ground=character_id==15 and ("source_14__" in clip or "source_16__" in clip)
		blend_left=.07 if not current_clip.is_empty() and not native_ben_ground else 0.0
		current_clip=clip;animation_player.play(clip)
	var length=animation_player.get_animation(clip).length
	var sample_time=fposmod(time,length) if loop and length>0 else clampf(time,0,length)
	animation_player.seek(sample_time,true)
	if blend_left>0:
		blend_left=maxf(0,blend_left-delta)
		_blend_sample(1-blend_left/.07)
	skeleton.force_update_all_bone_transforms()
	if character_id==15:_apply_ben_flight_accessories(clip,sample_time)

func _blend_sample(weight: float):
	for i in skeleton.get_bone_count():
		var target=skeleton.get_bone_pose(i)
		skeleton.set_bone_pose(i,blend_from[i].interpolate_with(target,weight))

static func ben_accessory_table_entry(source: int,key: int)->Dictionary:
	# The actor indexes these contiguous tables directly; their zero entries
	# are renderer null pointers, not animation-interpreter loop commands.
	var lengths={21:39,22:10,23:25,24:33,25:36}
	while source<25 and key>int(lengths[source]):
		key-=int(lengths[source])+1;source+=1
	return {"source":source,"key":key,"visible":key<int(lengths[source])}

func _apply_ben_flight_accessories(clip: String,time: float):
	for mesh in ben_accessory_meshes:
		if is_instance_valid(mesh):mesh.visible=true
	var accessory_source=0
	var accessory_key=floori(time*30.0+.0001)
	var original_body=""
	if "source_18__" in clip or clip==motion("PropellerDeploy"):
		accessory_source=21;original_body="source_18"
		if accessory_key>=24:
			accessory_source=22;accessory_key=(accessory_key-24)%36
		elif is_instance_valid(combat) and combat.get("bomb_phase")=="deploy":
			# State1 switches to state2 on key14 without replacing the prop
			# pose. State2 reads table22 directly from the next update.
			if accessory_key==14:accessory_key=13
			elif accessory_key>14:accessory_source=22
	elif "source_17__" in clip or clip==motion("PropellerFly"):
		accessory_source=22;original_body="source_17";accessory_key%=36
	elif "source_20__" in clip or clip==motion("PropellerLand"):
		accessory_source=24;original_body="source_20"
		if is_instance_valid(combat) and combat.get("bomb_phase")=="land" and float(combat.get("bomb_clock"))*30.0<64.0:
			accessory_source=22
	elif "source_19__" in clip:return # The barrage carries its own verified four accessory tracks.
	else:
		# 8018057C..588 initially hides the separate rotor renderer. Neither
		# ground attack handler unhides it or dispatches accessory table23.
		for mesh in ben_accessory_meshes:
			if is_instance_valid(mesh):mesh.visible=false
		return
	var entry=ben_accessory_table_entry(accessory_source,accessory_key)
	if not entry.visible:
		for mesh in ben_accessory_meshes:
			if is_instance_valid(mesh):mesh.visible=false
		return
	# Accessory streams expose four absolute source transforms as Part00..03.
	# Retarget GLOBAL matrices: destination Part12..15 have other bind poses.
	var retained=[]
	for i in skeleton.get_bone_count():retained.append(skeleton.get_bone_pose(i))
	var head=skeleton.find_bone("Part_00")
	var displayed_head=skeleton.get_bone_global_pose(head).origin
	var common_shift=Vector3.ZERO
	if clip.begins_with("Derived_"):
		animation_player.play(motion(original_body));animation_player.seek(time,true)
		skeleton.force_update_all_bone_transforms()
		common_shift=displayed_head-skeleton.get_bone_global_pose(head).origin
	animation_player.play(motion("source_%02d"%int(entry.source)))
	animation_player.seek(float(entry.key)/30.0,true)
	skeleton.force_update_all_bone_transforms()
	var globals=[]
	for part in range(4):
		var transform=skeleton.get_bone_global_pose(skeleton.find_bone("Part_%02d"%part))
		transform.origin+=common_shift;globals.append(transform)
	animation_player.play(clip);animation_player.seek(time,true)
	for i in skeleton.get_bone_count():skeleton.set_bone_pose(i,retained[i])
	skeleton.force_update_all_bone_transforms()
	for part in range(4):
		var index=skeleton.find_bone("Part_%02d"%(part+12))
		skeleton.set_bone_global_pose(index,globals[part])
		if blend_left>0:skeleton.set_bone_pose(index,blend_from[index].interpolate_with(skeleton.get_bone_pose(index),1-blend_left/.07))
	skeleton.force_update_all_bone_transforms()

static func ben_bomb_rom_frame(world_tick: int)->Dictionary:
	# 8017849C advances the animation before 8017E120 runs. The latter
	# changes actor+94 to11 without reloading the body pose, but immediately
	# uses that changed index for the separate four-part propeller renderer.
	if ben_bomb_rom_frames.is_empty():
		ben_bomb_rom_frames.append({"body_key":0,"accessory_key":0,"release":false,"release_count":0,"heading_units":0,"bob_offset_metres":0.0})
		var cursor=0
		var threshold=0
		var released=0
		for tick in range(1,134):
			cursor+=1
			var displayed_body=cursor
			if tick*32>=threshold:
				cursor=11
				threshold+=215
			var release_=cursor==16
			if release_:released+=1
			var bob_units=floori(sin(float(tick*128)*TAU/4096.0)*32.0)
			ben_bomb_rom_frames.append({"body_key":displayed_body,"accessory_key":cursor,"release":release_,"release_count":released,"heading_units":tick*32,"bob_offset_metres":-bob_units*.01})
	var frame=ben_bomb_rom_frames[clampi(world_tick,0,133)].duplicate()
	if world_tick>133:frame.release=false
	return frame

func sample_ben_bomb_rom(world_tick: int,delta: float):
	var frame=ben_bomb_rom_frame(world_tick)
	sample_ben_bomb_frame(int(frame.body_key),int(frame.accessory_key),delta)

func sample_ben_bomb_frame(body_key: int,accessory_key: int,delta: float):
	var source=motion("source_19")
	_sample(source,float(body_key)/30.0,delta)
	if body_key==accessory_key:return
	var retained=[]
	for i in skeleton.get_bone_count():retained.append(skeleton.get_bone_pose(i))
	# Source19 includes exact duplicates of accessory table8019FAD4's four
	# transforms, so its last four tracks are valid independent samples.
	animation_player.seek(float(accessory_key)/30.0,true)
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i) in ["Part_12","Part_13","Part_14","Part_15"]:
			if blend_left>0:skeleton.set_bone_pose(i,blend_from[i].interpolate_with(skeleton.get_bone_pose(i),1-blend_left/.07))
		else:skeleton.set_bone_pose(i,retained[i])
	skeleton.force_update_all_bone_transforms()
func ground_gait(speed: float,dodge: bool)->String:return "Run" if speed>=3.5 or dodge else "Walk"
func gait_nominal_speed(key: String)->float:return 7.0 if key=="Run" else 2.2
func animate(delta: float,speed: float,grounded: bool,vertical: float,_attack: float,_heavy: bool,_combo: int,dodge: bool):
	_sync_palette();body.transform=Transform3D.IDENTITY;clock+=delta
	locomotion.tick(delta,speed,grounded)
	var jumping=combat.hero.jumps_used if is_instance_valid(combat) else 0
	if grounded:
		if not was_grounded:landing_clock=0
		elif landing_clock>=0:landing_clock+=delta
		last_jump=0
	else:
		landing_clock=-1
		if was_grounded or jumping>last_jump or vertical>last_vertical+2:air_clock=0
		else:air_clock+=delta
		if vertical<0 and last_vertical>=0:air_clock=0
		last_jump=jumping
	var moving=speed>.25
	var flying=is_instance_valid(combat) and combat.hero.flying and character_id==15
	var propeller=flying or (is_instance_valid(combat) and character_id==15 and combat.is_bombing())
	if flying:
		flight_clock=flight_clock+delta if was_flying else 0.0
		flight_landing=false
	elif was_flying and grounded:flight_landing=true;landing_clock=0
	if is_instance_valid(combat) and combat.is_attacking():
		state="attack"
		var bomb_frame: Dictionary={}
		if character_id==15 and combat.is_bombing() and combat.get("bomb_phase")=="barrage" and combat.has_method("bomb_motion_frame"):
			bomb_frame=combat.bomb_motion_frame()
		if not bomb_frame.is_empty():
			rotation.y=atan2(-combat.hero.facing.x,-combat.hero.facing.z)+float(bomb_frame.heading_units)/4096.0*TAU
			sample_ben_bomb_frame(int(bomb_frame.body_key),int(bomb_frame.accessory_key),delta)
		else:
			_sample(combat.clip,combat.motion_time(),delta)
	elif character_id==14 and grounded and not moving and is_instance_valid(combat) and combat.beam_release_pose_time()>=0:
		state="release";_sample(motion("source_06"),combat.beam_release_pose_time(),delta,true)
	elif character_id==14 and is_instance_valid(combat) and combat.recovery_time>=0 and not moving:
		state="recover";_sample(motion("source_05"),combat.recovery_time,delta)
	elif flying:
		state="fly"
		var deploying=flight_clock<duration("PropellerDeploy")
		_sample(motion("PropellerDeploy" if deploying else "PropellerFly"),flight_clock if deploying else flight_clock-duration("PropellerDeploy"),delta,not deploying)
	elif not grounded:
		state="jump" if vertical>0 else "fall"
		var key="JumpRise" if vertical>0 and air_clock<duration("JumpRise") else ("JumpAir" if vertical>0 else "JumpFall")
		_sample(motion(key),air_clock if key!="JumpAir" else air_clock-duration("JumpRise"),delta,key=="JumpAir")
	elif landing_clock>=0 and landing_clock<duration("PropellerLand" if flight_landing else "Land") and not moving:
		state="land";_sample(motion("PropellerLand" if flight_landing else "Land"),landing_clock,delta)
	elif moving:
		state="run";var key=ground_gait(speed,dodge)
		if not was_moving or not was_grounded:gait_phase=0
		else:gait_phase=fposmod(gait_phase+delta*clampf(speed/gait_nominal_speed(key),.45,1.8)/duration(key),1.0)
		_sample(motion(key),gait_phase*duration(key),delta,true)
	else:state="idle";_sample(motion("source_12" if character_id==15 else "source_00"),clock,delta,character_id!=15)
	was_grounded=grounded;was_moving=moving;last_vertical=vertical;was_flying=propeller
	if is_instance_valid(sword_trail):
		var transform=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Part_11"))
		var segment=PackedVector3Array([transform*Vector3(.16,.01,.92),transform*Vector3(-.027,.01,1.56)])
		sword_trail.advance(delta,segment,is_instance_valid(combat) and combat.blade_active(),false)
func hand_position(side: String="R")->Vector3:
	var index=skeleton.find_bone("Part_%02d"%hand_bones[0 if side=="R" else 1])
	return (skeleton.global_transform*skeleton.get_bone_global_pose(index)).origin if index>=0 else global_position+Vector3.UP*1.2
func sync_skeleton():skeleton.force_update_all_bone_transforms()
func set_cloak(_equipped: bool,_gold: bool):pass
func set_surge(_active: bool):pass
func apply_skin(_id: String):pass
