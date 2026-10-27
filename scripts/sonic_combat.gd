extends "res://scripts/character_combat.gd"
## Source movement parameters adapted to the existing Hero body and army queries.
const UNIT=.2
const HZ=60.0
const SPEED_UNIT=UNIT*HZ
const SOURCE_PATH="res://assets/characters/recovered_sonic/native_tables.json"
static var parameters:Dictionary={}
var mode="idle"
var braking=false
var charge=0.0
var attack_time=0.0
var jump_held=false
var jump_requested=false
var jump_ticks=0.0
var miss_ticks=0.0
var homing_used=false
var target:WeakRef
var hits:Dictionary={}
var ticket:Dictionary={}
var charge_voice:AudioStreamPlayer
var blue_effect:Node3D

static func physics_parameters()->Dictionary:
	if parameters.is_empty():parameters=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH)).physics
	return parameters

static func jump_velocity(vertical:float,ticks:float,held:bool,held_ticks:float)->float:
	if held and held_ticks<parameters.jump2_timer:
		vertical+=.8*parameters.jmp_addit*SPEED_UNIT*minf(ticks,parameters.jump2_timer-held_ticks)
	return maxf(-parameters.lim_v_spd*SPEED_UNIT,vertical+(vertical*parameters.air_resist_y-parameters.weight*SPEED_UNIT)*ticks)

func _ready():
	physics_parameters()
	var audio=preload("res://scripts/sonic_audio.gd")
	for slot in audio.FILES:audio.stream_for(slot)
	charge_voice=AudioStreamPlayer.new();charge_voice.bus=&"SFX";add_child(charge_voice)
	var loop:AudioStreamWAV=audio.stream_for("sonic_charge").duplicate()
	loop.loop_mode=AudioStreamWAV.LOOP_FORWARD;loop.loop_begin=17827;loop.loop_end=27444
	charge_voice.stream=loop
	blue_effect=preload("res://scripts/sonic_effects.gd").new();add_child(blue_effect)

func input(event:InputEvent):
	release_input(event)
	if event.is_echo() or not available():return
	if event.is_action_pressed("jump") or event.is_action_pressed("light_attack"):
		if hero.is_on_floor():jump_requested=true;jump_held=true
		else:start_homing()
	if event.is_action_pressed("heavy_attack") or event.is_action_pressed("equip"):start_spin()
	if event.is_action_pressed("surge"):start_homing()
	if event.is_action_pressed("dodge"):cancel(true)

func release_input(event:InputEvent):
	if event.is_action_released("jump") or event.is_action_released("light_attack"):jump_held=false
	if event.is_action_released("heavy_attack") or event.is_action_released("equip"):
		if mode=="charge" and available():release_spin()
		elif mode=="charge":cancel()

func available()->bool:
	return active and is_instance_valid(hero) and hero.hp>0 and game.playing and not game.paused and not game.transitioning and not get_tree().paused and not game.siege_building()

func sound(slot:String):game.sound(slot,1.0,false,ticket,19)

func begin_attack(action:String):
	hits.clear();ticket=hero.attack_chain.begin("sonic_"+action,action)
	hero.attack_ticket=ticket

func start_spin():
	if not available() or not hero.is_on_floor() or mode=="charge":return
	# Retail work.f starts at max(forward speed, 2), then gains .4 per tick.
	charge=maxf(2.0,hero.velocity.dot(hero.facing)/SPEED_UNIT)
	mode="charge";attack_time=0;target=null
	begin_attack("spin_dash")
	if not game.sound_library.is_muted_for(19,"sonic_charge"):
		charge_voice.volume_db=linear_to_db(.55*game.sound_library.gain_for(19,"sonic_charge"));charge_voice.play()

func release_spin():
	if mode!="charge":return
	charge_voice.stop()
	mode="roll"
	hero.velocity.x=hero.facing.x*SPEED_UNIT*charge*skill_factor("travel_speed",ticket)
	hero.velocity.z=hero.facing.z*SPEED_UNIT*charge*skill_factor("travel_speed",ticket)
	sound("sonic_dash")

func can_homing()->bool:
	var used=hero.active_ability.homing_used if hero.character_id==19 else homing_used
	return available() and not hero.is_on_floor() and not used and mode!="homing"

func start_homing():
	if not can_homing():return
	homing_used=true;mode="homing";attack_time=0;miss_ticks=0;jump_held=false
	if hero.character_id==19:hero.active_ability.homing_used=true
	begin_attack("homing")
	var enemy=homing_target()
	target=weakref(enemy) if is_instance_valid(enemy) else null
	if target==null:
		hero.velocity.x=hero.facing.x*5*SPEED_UNIT*skill_factor("travel_speed",ticket);hero.velocity.z=hero.facing.z*5*SPEED_UNIT*skill_factor("travel_speed",ticket)
	sound("sonic_homing")

func homing_target()->Ninja:
	var origin=hero.global_position+Vector3.UP
	var best:Ninja
	var closest=pow(100*UNIT,2)
	for enemy in AttackChain.enemy_candidates(game,origin,100*UNIT):
		if not is_instance_valid(enemy) or enemy.dead:continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		var point=AttackChain.aim_point(enemy,origin)
		var offset=point-origin
		if offset.length_squared()>=closest:continue
		var flat=Vector3(offset.x,0,offset.z)
		if flat.length_squared()>.0001 and hero.facing.angle_to(flat)>TAU*0x5000/65536.0:continue
		if not AttackChain.clear_line(hero,origin,point):continue
		closest=offset.length_squared();best=enemy
	return best

# shortcut: planar retail steering; host contacts still own steep slopes and walls.
func steer(input_dir:Vector3,horizontal:Vector3,grounded:bool,ticks:float)->Vector3:
	var angle=hero.facing.signed_angle_to(input_dir,Vector3.UP)
	var turn=clampf(angle,-PI/16,PI/16) if absf(angle)>PI/4 else angle*(.25 if absf(angle)>PI/8 else .125)
	if horizontal.length_squared()<.0001:turn=angle
	turn*=ticks
	hero.facing=hero.facing.rotated(Vector3.UP,turn).normalized()
	return horizontal.rotated(Vector3.UP,turn*(.99 if grounded else .1))

func accelerate(horizontal:Vector3,input_dir:Vector3,grounded:bool,ticks:float)->Vector3:
	var speed=horizontal.dot(hero.facing)/SPEED_UNIT
	var strength=minf(1.0,input_dir.length())
	var acceleration=0.0
	if strength>.01:
		var angle=hero.facing.signed_angle_to(input_dir,Vector3.UP)
		braking=grounded and speed>parameters.run_speed and absf(angle)>TAU*.375
		if braking:acceleration=parameters.run_break
		else:
			horizontal=steer(input_dir,horizontal,grounded,ticks)
			speed=horizontal.dot(hero.facing)/SPEED_UNIT
			acceleration=parameters.run_accel*strength if grounded else parameters.air_accel*strength*(2 if hero.velocity.y<0 else 1)
			if grounded and speed<parameters.max_x_spd:
				if speed<parameters.jog_speed and strength<=.5 and speed>=parameters.jog_speed*.4:acceleration=0
				elif speed<parameters.run_speed and speed>=parameters.jog_speed and strength<=.7:acceleration=0
				elif speed>=parameters.run_speed and speed<parameters.rush_speed and strength<=.9:acceleration*=.3
			if grounded and speed>=parameters.max_x_spd:acceleration*=.4
			if not grounded and absf(angle)>PI/8:acceleration=parameters.air_break*strength if speed>parameters.run_speed and absf(angle)>TAU*.375 else 0.0
	elif grounded:acceleration=parameters.slow_down if speed>0 else -parameters.slow_down if speed<0 else 0.0
	var drag=parameters.air_resist_air*speed
	if grounded:
		drag=parameters.air_resist*speed if strength<=.01 and speed>parameters.run_speed else parameters.air_resist*maxf(0,speed-parameters.max_x_spd)*(1.7 if strength>.01 else 1.0)
	var next=speed+(acceleration+drag)*ticks
	if (strength<=.01 or braking) and signf(next)!=signf(speed):next=0
	var side=horizontal-hero.facing*(speed*SPEED_UNIT)
	return hero.facing*(next*SPEED_UNIT)+side*pow(1+parameters.air_resist_z,ticks)

func tick_timers(_delta:float):pass
func tick(delta:float,_after_pose:bool=false):
	if hero.is_on_floor():
		homing_used=false
		if mode=="jump":mode="idle"
	if spell_owner!=null and not is_attacking():blue_effect.advance(delta,hero,"idle",0)
func blocks_movement()->bool:return false
func protects_player()->bool:return false
func is_attacking()->bool:return mode in ["charge","roll","homing"]
func spinning()->bool:return mode in ["charge","roll","homing","jump"]

func physics_step(delta:float):
	if not available():cancel();return
	var input_dir=hero.ai_move if hero.ai_controlled else Vector3(hero.smoke_move.x,0,hero.smoke_move.y) if hero.smoke_mode else Vector3.ZERO
	if not hero.ai_controlled and not hero.smoke_mode:
		var move=Input.get_vector("move_left","move_right","move_forward","move_back")
		input_dir=Vector3(move.x,0,move.y).rotated(Vector3.UP,game.camera_rig.yaw)
	var grounded=hero.is_on_floor()
	var velocity=hero.velocity
	var horizontal=Vector3(velocity.x,0,velocity.z)
	var ticks=delta*HZ
	var was_braking=braking
	braking=false
	if grounded:
		homing_used=false
		if mode=="jump":mode="idle"
	elif mode=="charge":mode="jump";charge_voice.stop();jump_held=false
	if mode=="charge":
		if charge<10:charge=minf(10,charge+.4*ticks)
		horizontal=horizontal.move_toward(Vector3.ZERO,-parameters.run_break*SPEED_UNIT*ticks)
		if input_dir.length_squared()>.01:hero.facing=input_dir.normalized()
	elif mode=="homing":
		attack_time+=delta
		var enemy=target.get_ref() if target!=null else null
		var point=AttackChain.aim_point(enemy,hero.global_position+Vector3.UP) if is_instance_valid(enemy) else Vector3.ZERO
		if is_instance_valid(enemy) and not enemy.dead and point.distance_squared_to(hero.global_position+Vector3.UP)<pow(100*UNIT,2) and AttackChain.clear_line(hero,hero.global_position+Vector3.UP,point):
			var direction=(point-(hero.global_position+Vector3.UP)).normalized()
			var flat=Vector3(direction.x,0,direction.z)
			if flat.length_squared()>.0001:
				hero.facing=hero.facing.rotated(Vector3.UP,clampf(hero.facing.signed_angle_to(flat,Vector3.UP),-PI/16*ticks,PI/16*ticks))
			velocity=(hero.facing*sqrt(maxf(0,1-direction.y*direction.y))+Vector3.UP*direction.y)*5*SPEED_UNIT*skill_factor("travel_speed",ticket)
			horizontal=Vector3(velocity.x,0,velocity.z)
		else:
			target=null;miss_ticks+=ticks;horizontal*=pow(.9,ticks)
			velocity.y+=(velocity.y*parameters.air_resist_y-parameters.weight*SPEED_UNIT)*ticks
		if miss_ticks>=6 or attack_time>=6:mode="fall";target=null
	elif mode=="roll":
		if input_dir.length_squared()>.01:horizontal=steer(input_dir,horizontal,grounded,ticks)
		horizontal*=pow(1.0+parameters.air_resist,ticks)
		if grounded:
			var gravity=Vector3.DOWN*parameters.weight*SPEED_UNIT*ticks
			horizontal+=gravity.slide(hero.get_floor_normal())
		if horizontal.length()<parameters.jog_speed*SPEED_UNIT:mode="idle"
	else:
		if Input.is_action_pressed("walk_modifier") or hero.skullpion_poison_left>0:input_dir*=.3
		horizontal=accelerate(horizontal,input_dir,grounded,ticks)
		if grounded:horizontal+=(Vector3.DOWN*parameters.weight*SPEED_UNIT*ticks).slide(hero.get_floor_normal())
	if braking and not was_braking:sound("sonic_brake")
	if jump_requested:
		jump_requested=false
		if grounded:
			velocity.y=parameters.jmp_y_spd*SPEED_UNIT*hero.combat_tuning("jump_height");mode="jump";grounded=false;jump_ticks=0
			charge_voice.stop()
			begin_attack("jump");sound("jump");hero.jumps_used=1
	if spell_owner==null and hero.jump_style.active() and mode in ["idle","fall"]:
		hero.velocity=Vector3(horizontal.x,velocity.y,horizontal.z)
		hero.jump_style.step(delta)
		if hero.flying:hero.jump_style.steer_flight(delta,input_dir)
		velocity=hero.velocity;horizontal=Vector3(velocity.x,0,velocity.z)
	elif mode!="homing" and not grounded and miss_ticks==0:
		velocity.y=jump_velocity(velocity.y/hero.combat_tuning("jump_height"),ticks,mode=="jump" and jump_held,jump_ticks)*hero.combat_tuning("jump_height")
		if mode=="jump" and jump_held and jump_ticks<parameters.jump2_timer:jump_ticks+=ticks
	if mode!="homing":miss_ticks=0
	if grounded and velocity.y<0:velocity.y=0
	horizontal=horizontal.limit_length(parameters.lim_h_spd*SPEED_UNIT)
	velocity.x=horizontal.x;velocity.z=horizontal.z;hero.velocity=velocity
	var before=hero.global_position
	# Use the shared CharacterBody so bridges, hills, walls and portals retain ownership.
	hero.move_and_slide()
	if mode in ["roll","homing","jump"]:contact(before+Vector3.UP,hero.global_position+Vector3.UP)
	if hero.is_on_wall():
		if hero.character_id==19 and (mode in ["roll","homing"] or -velocity.dot(hero.get_wall_normal())>parameters.crash_speed*SPEED_UNIT):sound("sonic_wall_hit")
		if mode in ["roll","homing"]:mode="jump" if not hero.is_on_floor() else "idle";target=null
	if hero.is_on_floor() and not grounded:
		mode="idle";homing_used=false;sound("land")
	blue_effect.advance(delta,hero,mode,charge)
	hero.model.locomotion_velocity=(hero.global_position-before)/maxf(delta,.000001)
	if spell_owner==null:
		hero.invuln=maxf(0,hero.invuln-delta)
		hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
		hero.model.animate(delta,horizontal.length(),hero.is_on_floor(),hero.velocity.y,0,false,0,false)
		if hero.model.locomotion.step_events!=hero.last_foot_events:
			hero.last_foot_events=hero.model.locomotion.step_events
			if not spinning():hero.play_sound("step",.22)
		hero.model.visible=not(hero.invuln>0 and int(hero.invuln*20)%2==0)
		hero.was_floor=hero.is_on_floor();hero._finish_movement_bounds()

func contact(from:Vector3,to:Vector3):
	var damage=(48.0 if mode=="homing" else 30.0)*hero.damage_multiplier()
	BreakableBuilding.hit_segment(game,from,to+hero.facing*.7*hero.growth_multiplier(),damage,ticket,hits)
	var hit=AttackChain.nearest_contact(game,hero,from,to,.65*hero.growth_multiplier()*skill_factor("hit_area",ticket),hits)
	if hit.is_empty():return
	var enemy:Ninja=hit.enemy;hits[enemy.get_instance_id()]=true
	var direction=hero.velocity.normalized()
	enemy.take_hit(damage,direction,false,ticket)
	if not hero.ai_controlled:game.confirm_impact(enemy,hit.point,direction,1,false)
	if mode in ["homing","jump"]:
		hero.velocity=hero.facing*4.0+Vector3.UP*parameters.jmp_y_spd*SPEED_UNIT*.65
		mode="jump";homing_used=false;target=null;jump_held=false
		if hero.character_id==19:hero.active_ability.homing_used=false

func cancel(_preserve_power:bool=false):
	if is_instance_valid(charge_voice):charge_voice.stop()
	if is_instance_valid(blue_effect):blue_effect.clear()
	mode="idle";charge=0;attack_time=0;target=null;hits.clear();ticket.clear()
	jump_held=false;jump_requested=false;braking=false;jump_ticks=0;miss_ticks=0
func interrupt_for_dodge():cancel(true)
func hit():cancel(true)
