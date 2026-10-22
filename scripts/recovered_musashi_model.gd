extends HeroModel
## Original rigid-part rig. Gameplay names below select recovered source clips;
## the GLB still retains every numeric source name for further animation work.
const ASSET=preload("res://assets/optimized/musashi.glb")
const IDLE="Table_00__800d46e4"
const WALK="Table_06__800d48dc"
const RUN="Table_07__800d4944"
const SPRINT="Table_08__800d499c"
const STOP="Table_09__800d49f4"
const JUMP="Table_13__800d4a9c"
const MOVING_JUMP="Table_15__800d4b48"
const FALL="Source__800d4ad4"
const MOVING_FALL="Source__800d4b70"
const LAND="Table_14__800d4b10"
const MOVING_LAND="Table_16__800d4ba8"
const FLIP="Extra__800d4be0"
const STRIKES=["Extra__800d4c94","Source__800d4ce4","Source__800d4d38"]
const HEAVY="Extra__800d4f14"
const AIR_STRIKE="Table_11__800d4e94"
const MOVING_AIR_STRIKE="Table_12__800d4ed4"
const AIR_HEAVY="Extra__800d4f8c"
const GUARD="Table_29__800d5734"
const GUARD_WALK="Table_30__800d5790"
const ROTATION="Extra__800d5360"
const COUNTER="Table_23__800d552c"
const PALETTE_SHADER=preload("res://assets/characters/recovered_musashi/reference_palette.gdshader")
var combat: Node
var animation_player: AnimationPlayer
var current_clip=""
var idle_time=0.0
var gait_phase=0.0
var was_moving=false
var air_stage="rise"
var air_phase_time=0.0
var moving_jump=false
var last_vertical=0.0
var last_jump_count=0
var landing_time=-1.0
var was_grounded=true
var palette_materials: Array[ShaderMaterial]=[]
var palette_environment=Vector3(-1,-1,-1)
var sword_trail: MeshInstance3D
var rotation_effect: Node3D
var outfit_mask=31
var presentation_scale=preload("res://scripts/character_proportions.gd").MUSASHI_SIZE
var native_motion=false
var step_side=0
var was_stopping=false
static var outfit_sources:Dictionary={}

class MotionBridge extends RefCounted:
	var owner_model
	var step_events=0
	var jump_compression=0.0
	var free_feet=false
	var travel=0.0
	func _init(owner_=null):owner_model=owner_
	func reset():
		travel=0;step_events=0
		if is_instance_valid(owner_model) and is_instance_valid(owner_model.combat) and owner_model.combat.locomotion!=null:owner_model.combat.locomotion.reset()
	func evaluate():pass
	func tick(delta: float,speed: float,grounded: bool):
		if not grounded:return
		travel+=speed*delta
		if travel>=1.8:step_events+=floori(travel/1.8);travel=fmod(travel,1.8)

func _ready():
	body=Node3D.new();body.name="RecoveredMusashiBody";add_child(body)
	rig_visual=ASSET.instantiate();body.add_child(rig_visual)
	# Recovered export is ~1.04m tall; retain its fitted baseline and enlarge
	# the rig so weapons and bone-attached effects follow the same presentation.
	rig_visual.scale=Vector3.ONE*1.8*presentation_scale
	rig_visual.rotation.y=PI
	_install_palette()
	set_outfit_mask(outfit_mask)
	skeleton=rig_visual.find_child("Skeleton3D",true,false)
	animation_player=rig_visual.find_child("AnimationPlayer",true,false)
	assert(skeleton!=null and animation_player!=null,"Recovered Musashi requires its skin and motion library")
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	head=_placeholder("HeadCompatibility")
	arms.assign([_placeholder("LeftArmCompatibility"),_placeholder("RightArmCompatibility")])
	legs.assign([_placeholder("LeftLegCompatibility"),_placeholder("RightLegCompatibility")])
	pipe=_placeholder("PipeCompatibility");coin=_placeholder("CoinCompatibility")
	scarf=_placeholder("ScarfCompatibility");hair_normal=_placeholder("HairCompatibility");hair_gold=_placeholder("SurgeCompatibility")
	locomotion=MotionBridge.new(self);process_priority=30
	_sample(IDLE,0,true)
	_sync_palette_environment()
	sword_trail=preload("res://scripts/recovered_musashi_trail.gd").new()
	sword_trail.name="MusashiBladeTrail";add_child(sword_trail)
	rotation_effect=preload("res://scripts/recovered_musashi_rotation_effect.gd").new();rotation_effect.name="MusashiRotationEffect";add_child(rotation_effect)

func _install_palette():
	palette_materials=install_palette_for(rig_visual)

static func install_palette_for(visual:Node)->Array[ShaderMaterial]:
	var materials:Array[ShaderMaterial]=[]
	var cache={}
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(surface) as BaseMaterial3D
			if original==null:continue
			if not cache.has(original):
				var material=ShaderMaterial.new();material.shader=PALETTE_SHADER
				material.set_shader_parameter("tint_color",original.albedo_color)
				material.set_shader_parameter("textured",original.albedo_texture!=null)
				if original.albedo_texture!=null:material.set_shader_parameter("albedo_texture",original.albedo_texture)
				if "clut_" in original.resource_name:material.set_meta("source_clut",str(original.resource_name).get_slice("clut_",1).to_int())
				cache[original]=material;materials.append(material)
			mesh.set_surface_override_material(surface,cache[original])

	return materials

static func equipment_sources()->Dictionary:
	if outfit_sources.is_empty():outfit_sources=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_musashi/outfit_sources.json"))
	return outfit_sources
func set_outfit_mask(mask:int):
	outfit_mask=clampi(mask,0,31)
	if palette_materials.is_empty():return
	var pages:Dictionary=equipment_sources().looks[outfit_mask].pages
	for material in palette_materials:
		if material.has_meta("source_clut"):
			var key=str(material.get_meta("source_clut"))
			if pages.has(key):material.set_shader_parameter("albedo_texture",load("res://assets/characters/recovered_musashi/outfits/"+pages[key]))

func _sync_palette_environment():
	var environment=get_world_3d().environment
	var settings=Vector3(0,1,1)
	if environment!=null:
		settings=Vector3(1 if environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC else 0,environment.tonemap_exposure,environment.tonemap_white)
	if settings==palette_environment:return
	palette_environment=settings
	for material in palette_materials:
		material.set_shader_parameter("compensate_filmic",settings.x>0)
		material.set_shader_parameter("scene_exposure",settings.y)
		material.set_shader_parameter("scene_white",settings.z)

func _placeholder(label: String)->Node3D:
	var node=Node3D.new();node.name=label;body.add_child(node);node.hide();return node

func _sample(clip: String,time: float,loop: bool=false,loop_start: float=0.0):
	if not animation_player.has_animation(clip):return
	if current_clip!=clip:
		current_clip=clip;animation_player.play(clip)
	var length=animation_player.get_animation(clip).length
	var sample_time=clampf(time,0,length)
	if loop and time>=length and length>loop_start:
		sample_time=loop_start+fposmod(time-loop_start,length-loop_start)
	animation_player.seek(sample_time,true)
	skeleton.force_update_all_bone_transforms()

func animate(delta: float,speed: float,grounded: bool,vertical: float,_attack: float,_heavy: bool,_combo: int,dodge: bool):
	_sync_palette_environment()
	body.transform=Transform3D.IDENTITY
	if is_instance_valid(combat) and combat.mode=="rotation":body.rotation.y=-float(combat.rotation_angle)*TAU/4096.0
	locomotion.tick(delta,speed,grounded)
	# State clocks belong to motion phases, never total time since spawn. Keeping
	# the gait phase across speed changes avoids skipping whole strides.
	var moving=speed>.25
	var jump_count=combat.hero.jumps_used if is_instance_valid(combat) and is_instance_valid(combat.hero) else 0
	if grounded:
		if not was_grounded:landing_time=0.0
		elif landing_time>=0:landing_time+=delta
		last_jump_count=0
	else:
		landing_time=-1.0
		var new_impulse=not was_grounded and (jump_count>last_jump_count or vertical>last_vertical+2.0)
		if was_grounded or new_impulse:
			moving_jump=moving
			air_stage="flip" if new_impulse else ("rise" if vertical>0 else "fall")
			air_phase_time=0.0
		else:air_phase_time+=delta
		if air_stage=="flip" and air_phase_time>=8.0/30.0:
			air_stage="rise" if vertical>0 else "fall";air_phase_time=0.0
		if air_stage=="rise" and vertical<=0:
			air_stage="fall";air_phase_time=0.0
		last_jump_count=jump_count
	idle_time=idle_time+delta if not moving and was_grounded and grounded else 0.0
	var gait=SPRINT if dodge or speed>=10.0 else (RUN if speed>=3.5 else WALK)
	if native_motion and is_instance_valid(combat):
		# 5A3C8 selects by original 16.16 speed, not host sprint settings.
		gait=SPRINT if combat.locomotion.source_speed< -0x94000 else (RUN if combat.locomotion.source_speed< -0x70000 else WALK)
	if moving and grounded:
		if not was_moving or not was_grounded:gait_phase=0.0
		else:
			var nominal_speed=12.0 if gait==SPRINT else (7.0 if gait==RUN else 3.5)
			var rate=1.0 if native_motion else clampf(speed/nominal_speed,.4,1.8)
			var length=animation_player.get_animation(gait).length
			var before=gait_phase*length;var after=before+delta*rate
			if native_motion and is_instance_valid(combat) and not combat.is_attacking() and not combat.guarding() and combat.locomotion.animation_state()!="stop":
				# Original opcode8 in the resident body streams. Terrain-0 uses
				# SC01 61C24's alternating 0x406/0x407 events.
				var markers=[3.0/30.0,10.0/30.0] if gait==SPRINT else ([2.0/30.0,10.0/30.0] if gait==RUN else [2.0/30.0,12.0/30.0])
				for marker in markers:
					var crossings=floori((after-marker+.000001)/length)-floori((before-marker+.000001)/length)
					for i in crossings:
						combat.game.sound("musashi_step_%d"%step_side,.22,false,{},13);step_side=1-step_side
			gait_phase=fposmod(after/length,1.0)
	if is_instance_valid(combat) and combat.is_attacking():
		_sample(combat.clip,combat.elapsed)
	elif is_instance_valid(combat) and combat.guarding() and grounded:
		_sample(GUARD_WALK if moving else GUARD,combat.guard_elapsed,true)
	elif native_motion and is_instance_valid(combat) and combat.locomotion.animation_state()=="stop" and grounded:
		_sample(STOP,(combat.locomotion.stop_ticks+1)/30.0)
		if not was_stopping:combat.game.sound("ground_stop",.22,false,{},13)
	elif not grounded:
		if air_stage=="flip":_sample(FLIP,air_phase_time)
		elif air_stage=="rise":_sample(MOVING_JUMP if moving_jump else JUMP,air_phase_time)
		else:_sample(MOVING_FALL if moving_jump else FALL,air_phase_time,true,(7.0 if moving_jump else 8.0)/30.0)
	elif landing_time>=0 and landing_time<animation_player.get_animation(MOVING_LAND if moving_jump else LAND).length and not dodge:
		_sample(MOVING_LAND if moving_jump else LAND,landing_time)
	else:
		_sample(gait,gait_phase*animation_player.get_animation(gait).length,true) if moving else _sample(IDLE,idle_time,true)
	# Native renderer80020598 scales drawn Lumina(part25), never the body.
	var blade=skeleton.find_bone("Part_25_weapon_attachment")
	if blade>=0 and is_instance_valid(combat):
		skeleton.set_bone_pose_scale(blade,skeleton.get_bone_pose_scale(blade)*combat.lumina_scale_factor())
		skeleton.force_update_all_bone_transforms()
	was_grounded=grounded
	was_stopping=native_motion and is_instance_valid(combat) and combat.locomotion.animation_state()=="stop"
	was_moving=moving
	last_vertical=vertical
	if is_instance_valid(sword_trail):
		if is_instance_valid(combat):sword_trail.advance_model(delta,self,combat)
	if is_instance_valid(rotation_effect):rotation_effect.advance(delta)

func sword_segment(heavy: bool)->PackedVector3Array:
	# Labels were assigned during recovery: the drawn blades are part25/22,
	# despite their reconstructed names. Endpoints come from mesh inverse binds.
	var index=skeleton.find_bone("Part_25_weapon_attachment" if heavy else "Part_22_fusion_guard")
	var pose=skeleton.get_bone_global_pose(index)
	if pose.basis.get_scale().length()<.001:return PackedVector3Array()
	var transform=skeleton.global_transform*pose
	return PackedVector3Array([transform*Vector3(0,-.10 if heavy else -.08,0),transform*(Vector3(0,-.59,0) if heavy else Vector3(.01,-.42,.02))])

func sync_skeleton():
	if is_instance_valid(skeleton):skeleton.force_update_all_bone_transforms()
func set_cloak(_equipped: bool,_gold: bool):pass
func set_surge(_active: bool):pass
func apply_skin(_id: String):pass
func hand_position(side: String="R")->Vector3:
	var index=skeleton.find_bone("Part_08_hand_b" if side=="R" else "Part_07_hand_a")
	return skeleton.global_transform*skeleton.get_bone_global_pose(index).origin
