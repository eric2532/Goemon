extends HeroModel
## Authored rigid parts, original STEP motion, shared palette and hero contract.
const DATA="res://assets/characters/recovered_kojiro/"
const FLIP_DURATION=preload("res://scripts/recovered_musashi_model.gd").FLIP_DURATION
static var profile:Dictionary={}
var combat:Node
var animation_player:AnimationPlayer
var parts:Array[Node3D]=[]
var clock=0.0
var move_clock=0.0
var air_clock=0.0
var flip_time=-1.0
var last_jump_count=0
var current_clip=""
var was_grounded=true
var palette_materials=[]
var palette_environment=Vector3(-1,-1,-1)
var trail:MeshInstance3D

static func data()->Dictionary:
	if profile.is_empty():profile=JSON.parse_string(FileAccess.get_file_as_string(DATA+"combat.json"))
	return profile

func _ready():
	body=Node3D.new();body.name="Kojiro";add_child(body)
	head=driver("Head",Vector3(0,2.4,0))
	arms.assign([driver("Arm_L",Vector3(-.4,1.6,0)),driver("Arm_R",Vector3(.4,1.6,0))])
	legs.assign([driver("Leg_L",Vector3(-.2,.5,0)),driver("Leg_R",Vector3(.2,.5,0))])
	scarf=driver("Sash",Vector3.ZERO)
	hair_normal=Node3D.new();body.add_child(hair_normal)
	hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
	pipe=Node3D.new();body.add_child(pipe);pipe.hide()
	coin=Node3D.new();body.add_child(coin);coin.hide()
	chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
	rig_visual=load(GameAssets.model_path("res://assets/models/characters/kojiro/kojiro.glb")).instantiate();body.add_child(rig_visual)
	animation_player=rig_visual.find_child("AnimationPlayer",true,false)
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i in 15:parts.append(rig_visual.find_child("Part_%02d"%i,true,false))
	pose(data().semantics.idle,0,true)
	var bounds=AABB();var first=true
	for i in 14:
		var mesh=parts[i] as MeshInstance3D
		var box=global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	var proportions=preload("res://scripts/character_proportions.gd")
	var fit=proportions.GOEMON_HEIGHT*proportions.KOJIRO_SIZE/bounds.size.y
	rig_visual.scale*=fit;rig_visual.position.y=-bounds.position.y*fit;rig_visual.rotation.y=PI
	palette_materials=preload("res://scripts/recovered_leader_model.gd").install_palette_for(rig_visual)
	locomotion=preload("res://scripts/master_chief_locomotion.gd").new(self)
	trail=preload("res://scripts/recovered_leader_trail.gd").new()
	trail.lifetime=16.0/30;trail.light_color=Color(240.0/255,120.0/255,240.0/255);trail.heavy_color=trail.light_color
	trail.additive=true;trail.opacity=1;trail.sample_interval=1.0/30;add_child(trail)

func pose(clip:String,time:float,loop:bool=false):
	if current_clip!=clip:animation_player.play(clip);current_clip=clip
	var length=animation_player.get_animation(clip).length
	animation_player.seek(fposmod(time,length) if loop and length>0 else clampf(time,0,maxf(0,length-.00001)),true)

func source_point(point:Array)->Vector3:
	return parts[0].get_parent().global_transform*Vector3(point[0],-point[1],-point[2])

func source_unit()->float:return parts[0].get_parent().global_basis.get_scale().x

func blade()->PackedVector3Array:
	return PackedVector3Array([parts[14].global_position,parts[14].global_transform*Vector3(0,0,64)])

func animate(delta:float,speed:float,grounded:bool,vertical:float,_attack:float,_heavy:bool,_combo:int,_dodge:bool):
	clock+=delta;locomotion.update(delta,locomotion_velocity,grounded,vertical,0,false)
	var env=get_world_3d().environment
	var settings=Vector3(1 if env!=null and env.tonemap_mode==Environment.TONE_MAPPER_FILMIC else 0,env.tonemap_exposure if env!=null else 1,env.tonemap_white if env!=null else 1)
	if settings!=palette_environment:
		palette_environment=settings
		for material in palette_materials:
			material.set_shader_parameter("compensate_filmic",settings.x>0);material.set_shader_parameter("scene_exposure",settings.y);material.set_shader_parameter("scene_white",settings.z)
	var semantic:Dictionary=data().semantics
	var jump_count=combat.hero.jumps_used if is_instance_valid(combat) and is_instance_valid(combat.hero) else 0
	if grounded:flip_time=-1.0
	elif not was_grounded and jump_count>last_jump_count and jump_count>=2:flip_time=0.0
	elif flip_time>=0:flip_time+=delta
	last_jump_count=0 if grounded else jump_count
	if is_instance_valid(combat) and not combat.clip.is_empty():
		pose(combat.clip,combat.elapsed,false)
	elif not grounded:
		air_clock=0 if was_grounded else air_clock+delta
		if flip_time>=0 and flip_time<FLIP_DURATION:
			# Reuse the prepared somersault at Musashi's pace; combat still owns hits.
			pose(semantic.air_spin,flip_time/FLIP_DURATION*animation_player.get_animation(semantic.air_spin).length)
		else:pose(semantic.jump if vertical>0 and air_clock<.3 else (semantic.air if vertical>0 else semantic.fall),air_clock,false)
	elif speed>.25:
		move_clock+=delta*clampf(speed/7.0,.35,2.0)
		pose(semantic.walk if speed<4 else semantic.run,move_clock,true)
	elif is_instance_valid(combat) and combat.combo>=0 and combat.combo_timer>0:
		var section:Dictionary=combat.SWORD_SECTIONS[combat.combo]
		pose(section.clip,(section.ticks-1)/30.0)
	else:
		move_clock=0;pose(semantic.idle,clock,true)
	was_grounded=grounded
	trail.advance(delta,blade(),is_instance_valid(combat) and combat.blade_active(),false)

func animate_spell(_delta:float,_spell:Node):pose(data().semantics.ready,0,false)
func hand_position(_side:String="R")->Vector3:return parts[2].global_position
func sync_skeleton():pass
func set_cloak(_equipped:bool,_gold:bool):pass
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):pass
func set_surge(_active:bool):pass
func apply_skin(_id:String):pass
