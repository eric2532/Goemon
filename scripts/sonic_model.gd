extends HeroModel
## Retail geometry, textures and motion; prepared welds use Godot's skinning.
const ROOT="res://assets/models/characters/sonic/"
var combat:Node
var animations:AnimationPlayer
var ball:Node3D
var ball_animation:AnimationPlayer
var current_clip=""

func _ready():
	body=Node3D.new();body.name="Sonic";add_child(body)
	head=driver("Head",Vector3(0,1.7,0))
	arms.assign([driver("Arm_L",Vector3(-.3,1.2,0)),driver("Arm_R",Vector3(.3,1.2,0))])
	legs.assign([driver("Leg_L",Vector3(-.2,.5,0)),driver("Leg_R",Vector3(.2,.5,0))])
	scarf=driver("Sash",Vector3.ZERO)
	hair_normal=Node3D.new();body.add_child(hair_normal)
	hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
	pipe=Node3D.new();body.add_child(pipe)
	coin=Node3D.new();body.add_child(coin);coin.hide()
	chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
	rig_visual=load(GameAssets.model_path(ROOT+"sonic.glb")).instantiate();body.add_child(rig_visual)
	skeleton=rig_visual.find_child("Skeleton3D",true,false) as Skeleton3D
	animations=rig_visual.find_child("AnimationPlayer",true,false) as AnimationPlayer
	ball=load(GameAssets.model_path(ROOT+"ball.glb")).instantiate();body.add_child(ball);ball.hide()
	ball_animation=ball.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var frames=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_sonic/native_tables.json")).clip_frames
	for player in [animations,ball_animation]:
		for clip in player.get_animation_list():
			if clip!="RESET":
				var animation=player.get_animation(clip)
				animation.loop_mode=Animation.LOOP_LINEAR
				# A 32-tick loop lasts 32 ticks, not the 31 between its endpoint samples.
				if frames.has(clip):animation.length=float(frames[clip])/60.0
	locomotion=preload("res://scripts/master_chief_locomotion.gd").new(self)
	visibility_changed.connect(update_visibility)
	play("Sonic Stand",.5)
	update_visibility()

func update_visibility():
	if animations!=null:animations.active=is_visible_in_tree() and rig_visual.visible
	if ball_animation!=null:ball_animation.active=is_visible_in_tree() and ball.visible

func play(clip:String,rate:float=1.0):
	if not animations.has_animation(clip):return
	if current_clip!=clip:
		current_clip=clip;animations.play(clip,.07)
	animations.speed_scale=maxf(.01,rate)

func animate(delta:float,speed:float,grounded:bool,vertical:float,_attack:float,_heavy:bool,_combo:int,_dodge:bool):
	locomotion.actual_speed=speed;locomotion.grounded=grounded;locomotion.vertical=vertical
	var kit=combat
	var hero=get_parent() as Hero
	if hero!=null and hero.spell_loadout.current!=null and hero.spell_loadout.current.source_id==19:kit=hero.spell_loadout.current.controller
	var spinning=(is_instance_valid(kit) and kit.spinning()) or (hero!=null and hero.jump_style.selected=="sonic" and not grounded and hero.jumps_used>0)
	if spinning or not grounded or speed<1:locomotion.step_clock=0
	ball.visible=spinning;rig_visual.visible=not spinning
	update_visibility()
	if spinning:
		if not ball_animation.is_playing():ball_animation.play("Sonic Spin (Jumpball)")
		return
	ball_animation.stop()
	if not grounded:play("Sonic Fall");return
	if is_instance_valid(combat) and combat.braking:play("Sonic Brake");return
	var native_speed=speed/12.0
	if native_speed<.1:play("Sonic Stand",.5)
	elif native_speed<.46:play("Sonic Walk",native_speed*3.4)
	elif native_speed<1.39:play("Sonic Speedwalk",native_speed*1.4)
	elif native_speed<2.3:play("Sonic Jog",native_speed*.8)
	elif native_speed<3.7:play("Sonic Run",native_speed*.5)
	else:play("Sonic Sprint",native_speed*.5)
	if speed>=1 and not (is_instance_valid(combat) and combat.braking):
		locomotion.step_clock+=delta*animations.speed_scale*2/maxf(.01,animations.current_animation_length)
		while locomotion.step_clock>=1:locomotion.step_events+=1;locomotion.step_clock-=1

func sync_skeleton():pass
func set_cloak(_equipped:bool,_gold:bool):pass
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):pass
func set_surge(_active:bool):pass
func apply_skin(_id:String):pass

func animate_qi_blast(_delta:float,progress:float):
	ball.hide();rig_visual.show();update_visibility()
	if progress<0:play("Sonic Stand",.5);return
	play("Sonic Ground Throw (Overhand)")
	animations.speed_scale=0
	animations.seek(qi_attack_time(progress,.24,.44),true)
