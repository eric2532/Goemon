class_name Hero
extends CharacterBody3D

var game: Node
var character_id=1
var character_models: Dictionary={}
var character_abilities: Dictionary={}
var musashi: MusashiCombat
var active_ability: Node
const BASIC_ATTACK_RANGE_MULTIPLIER = 3.0
const ROSTER={1: {"name":"Goemon", "model":preload("res://scripts/hero_model.gd")},2: {"name":"Edo", "model":preload("res://assets/characters/musashi/model/musashi_model.gd"),"combat":preload("res://assets/characters/musashi/combat/musashi_combat.gd")}}
const RogueRoster=preload("res://scripts/rogue_roster.gd")
var model: HeroModel
var hp=100.0
var max_hp=100.0
var progression=preload("res://scripts/level_progression.gd").new()
var facing=Vector3.FORWARD
var attack_left=0.0
var attack_duration=0.42
var attack_heavy=false
var hit_done=false
var combo=0
var combo_window=0.0
var queued=false
var invuln=0.0
var dodge_time=0.0
var dodge_cooldown=0.0
var coyote=0.0
var jump_buffer=0.0
const WALL_JUMP_GRACE=0.12
const WALL_JUMP_RECOVERY=0.22
const WALL_JUMP_PUSH=9.0
var wall_jump_normal=Vector3.ZERO
var wall_jump_origin=Vector3.ZERO
var wall_jump_grace=0.0
var wall_jump_recovery=0.0
var trail_time=0.0
var foot_time=0.0
var last_foot_events=0
var soft_target=true
var was_floor=false
var last_vertical=0.0
var weapon_slot=1
var jumps_used=0
var air_turn=0.0
var primary_down=false
var charge_elapsed=0.0
var attack_charged=false
var charge_power=1.0
var surge_left=0.0
var aura: SurgeAura
var charge_ring: Node3D
var impact_pause=0.0
var jump_windup=0.0
var struck_targets: Dictionary={}
var swing_played=false
var heavy_buffer=0.0
var combo_step_done=false
var sky_strike: SkyStrike
var chain_pipe_combat: ChainPipeCombat
var forward_dash: GoemonDash
var scarf_equipped=false
var gold_cloak=false
var flying=false
var flight_lean=0.0
var quick_attacks
var rogue_controls
var rogue_pipe_combo
var wide_swing=false
var run_upgrades={"damage":0,"vitality":0,"tempo":0}
var buildings_broken=0
const GROWTH_PER_BUILDING=.02
const MAX_GROWTH=2.0
var attack_chain=preload("res://scripts/attack_chain.gd").new()
var attack_ticket: Dictionary={}
const MAX_ATTACK_SPEED_STACKS=4
var attack_speed_stacks=0
var elemental_orbs={"ice":0,"fire":0}
var powerups={"damage":0.0,"range":0.0,"attack_speed":0.0}
var smoke_mode=false
var smoke_move=Vector2.ZERO

func _ready():
	quick_attacks=preload("res://scripts/goemon_quick_attacks.gd").new(self)
	rogue_controls=preload("res://scripts/rogue_battle_controls.gd").new(self)
	rogue_pipe_combo=preload("res://scripts/goemon_rogue_combo.gd").new();rogue_pipe_combo.hero=self;add_child(rogue_pipe_combo)
	sky_strike=SkyStrike.new(self)
	chain_pipe_combat=ChainPipeCombat.new(self)
	forward_dash=GoemonDash.new(self)
	collision_layer=2
	collision_mask=1
	floor_snap_length=0.55
	floor_max_angle=deg_to_rad(48)
	var shape=CollisionShape3D.new()
	var capsule=CapsuleShape3D.new()
	capsule.radius=0.38
	capsule.height=1.85
	shape.shape=capsule
	shape.position.y=0.95
	add_child(shape)
	model=HeroModel.new()
	model.skin_id=HeroSkins.valid_id(game.settings.goemon_skin)
	add_child(model)
	character_models[1]=model
	aura=SurgeAura.new()
	add_child(aura)
	aura.hide()
	charge_ring=Node3D.new();add_child(charge_ring)
	charge_ring.hide()
	max_hp=game.tuning.max_hp*progression.health_multiplier()*(1.0+.1*run_upgrades.vitality)
	hp=max_hp
	# Load registered visuals during startup so selection does not load a GLB mid-fight.
	for id in ROSTER:ensure_character(id)

func _input(event):
	# Release must arrive even when a menu consumes the pointer event.
	if rogue_controls!=null:rogue_controls.release(event)
	if is_rogue_character() and active_ability!=null:active_ability.release_input(event)

func _unhandled_input(event):
	if not game.playing or game.paused or game.transitioning or hp<=0: return
	if game.siege_building() and not event.is_action_pressed("pause"):return
	if game.camera_combat() and event.is_action_pressed("assist"):return
	if game.rogue_battle_mode:game.rogue_view.update_aim()
	if game.rogue_roster_mode and event.is_action_pressed("character_toggle") and not event.is_echo():
		game.show_rogue_roster();get_viewport().set_input_as_handled();return
	if is_rogue_character():
		active_ability.input(event)
		return
	if character_id==1 and event.is_action_pressed("weapon_coin") and not event.is_echo():
		quick_attacks.request(2);return
	if attack_chain.unleashed() and sky_strike.active:sky_strike.cancel()
	if forward_dash.active and not attack_chain.unleashed() and not event.is_action_pressed("character_toggle"):return
	if event.is_action_pressed("sky_strike") and not event.is_echo() and character_id==1:
		sky_strike.request();return
	if sky_strike.active and not event.is_action_pressed("character_toggle"):return
	if event.is_action_pressed("jump") and not event.is_echo() and not (character_id==2 and musashi.is_casting_meteors()): jump_buffer=0.15
	if event.is_action_pressed("character_toggle") and not event.is_echo():
		var ids=ROSTER.keys();select_character(ids[(ids.find(character_id)+1)%ids.size()])
	if active_ability!=null:
		active_ability.input(event)
		if active_ability.blocks_movement():return
		if event.is_action_pressed("assist"):soft_target=not soft_target
		if event.is_action_pressed("dodge") and dodge_cooldown<=0:
			active_ability.interrupt_for_dodge();attack_left=0
			if game.rogue_battle_mode:facing=rogue_dodge_direction()
			dodge_time=.28;dodge_cooldown=.75;invuln=.32;game.sound("dash")
		return
	for number in [1,3]:
		if event.is_action_pressed({1:"weapon_pipe",2:"weapon_coin",3:"weapon_chain"}[number]) and not event.is_echo():
			quick_attacks.request(number);return
	if event.is_action_pressed("scarf_toggle") and not event.is_echo():set_scarf_equipped(not scarf_equipped or gold_cloak)
	if event.is_action_pressed("gold_cloak") and not event.is_echo():set_gold_cloak(not gold_cloak)
	if event.is_action_pressed("surge") and not event.is_echo(): activate_surge()
	if (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack")) and not event.is_echo():
		if game.rogue_battle_mode:rogue_controls.input(event)
		else:quick_attacks.request_mouse(event.is_action_pressed("heavy_attack"))
	if event.is_action_pressed("equip") and not event.is_echo():forward_dash.start()
	if event.is_action_pressed("assist"):
		soft_target=not soft_target
		game.toast("Soft targeting ON" if soft_target else "Soft targeting OFF")
	if event.is_action_pressed("dodge") and dodge_cooldown<=0:
		if game.rogue_battle_mode:
			rogue_controls.reset(true)
			facing=rogue_dodge_direction()
		attack_left=0
		heavy_buffer=0
		combo=0
		cancel_charge(false,game.rogue_battle_mode)
		dodge_time=0.28
		dodge_cooldown=0.75
		invuln=0.32
		game.sound("dash")

func rogue_dodge_direction()->Vector3:
	var move=Input.get_vector("move_left","move_right","move_forward","move_back")
	return Vector3(move.x,0,move.y).rotated(Vector3.UP,game.camera_rig.yaw).normalized() if move.length_squared()>.01 else game.attack_direction()

func start_attack(heavy: bool, stage: int=1, charged: bool=false, power: float=1.0,action: String=""):
	if game.rogue_battle_mode or game.camera_combat():facing=game.attack_direction()
	attack_ticket=attack_chain.begin(action if not action.is_empty() else ("coin" if weapon_slot==2 else ("heavy" if heavy else "pipe")))
	wide_swing=action=="wide"
	if weapon_slot==1 and not model.equipped: model.equipped=true
	attack_heavy=heavy
	attack_charged=charged and (surge_left>0 or action=="spin")
	charge_power=power
	combo=stage
	attack_duration=0.74 if heavy else PipeCombo.DURATIONS[clampi(combo-1,0,2)]
	if weapon_slot==2: attack_duration=0.64 if heavy else 0.32
	if uses_rogue_pipe_profile():
		attack_duration=rogue_pipe_combo.duration(stage)
		rogue_pipe_combo.prepare()
		velocity+=facing*(2.5 if stage==3 else 1.25)
	attack_left=attack_duration
	hit_done=false
	struck_targets.clear()
	swing_played=false
	combo_step_done=false
	queued=false
	combo_window=rogue_pipe_combo.COMBO_WINDOW if uses_rogue_pipe_profile() else 0.8
	if attack_charged and weapon_slot==1:
		var wind=SpinWind.new();wind.hero=self;add_child(wind)
	if weapon_slot==2:
		facing=game.attack_direction()
	if soft_target and weapon_slot==1 and not game.rogue_battle_mode:
		var best: Node3D=null
		var dist=game.tuning.pipe_range*attack_reach_multiplier()+1.5
		for e in game.enemies:
			if not is_instance_valid(e) or e.dead: continue
			var dif=e.global_position-global_position
			if dif.length()<dist and facing.dot(dif.normalized())>-0.3:
				best=e
				dist=dif.length()
		if best:
			facing=(best.global_position-global_position).normalized()
			facing.y=0
	# A live chain enters the contact pose immediately instead of replaying windup.
	if attack_chain.unleashed() and not game.rogue_battle_mode:
		impact_pause=0;combo_step_done=true;play_swing_sound();strike();attack_left=0
	elif weapon_slot==1 and attack_chain.energized() and not game.rogue_battle_mode:
		attack_left=attack_duration*(1.0-(.47 if heavy else PipeCombo.CONTACT[combo-1]))
		impact_pause=0
		play_swing_sound()
		combo_step_done=true
		velocity+=facing*((4.5 if heavy else 2.5)+(0.0 if heavy else (4.2 if combo==1 else (3.0 if combo==2 else 5.4))))
		strike()

func uses_rogue_pipe_profile()->bool:
	return game.rogue_roster_mode and game.rogue_battle_mode and character_id==1 and weapon_slot==1 and not attack_heavy and not attack_charged and not wide_swing and attack_ticket.get("action","")=="pipe"

func play_swing_sound():
	swing_played=true
	if uses_rogue_pipe_profile():
		rogue_pipe_combo.release(combo);return
	game.sound("spin_swing" if attack_charged and weapon_slot==1 else ("heavy_swing" if attack_heavy or (weapon_slot==1 and combo==3) else "swing"))

func strike():
	var first_sample=not hit_done
	var bonus=first_sample and weapon_slot==1 and attack_chain.energized()
	var cross=(wide_swing or attack_ticket.get("action","")=="spin") and attack_chain.previous=="heavy"
	hit_done=true
	if first_sample:emit_robe_coins(attack_charged and weapon_slot==1)
	if weapon_slot==2:
		game.throw_coin(attack_heavy,attack_charged,charge_power)
		return
	var center=global_position+(Vector3.UP*1.1+facing*1.1)*growth_multiplier()
	if first_sample and attack_charged:
		game.sound("dash",.45)
	elif first_sample:
		if uses_rogue_pipe_profile():rogue_pipe_combo.slash(combo)
		elif wide_swing:game.combo_slash(center,facing,2,attack_reach_multiplier()*game.tuning.pipe_range*1.26/3.5)
		elif attack_heavy: game.slash(center,facing,true,combo,Color("ffdf83"),attack_reach_multiplier()*game.tuning.pipe_range/3.5)
		else: game.combo_slash(center,facing,combo,attack_reach_multiplier()*game.tuning.pipe_range/3.5)
	var any_hit=false
	for e in game.enemies:
		if not is_instance_valid(e) or e.dead or struck_targets.has(e.get_instance_id()): continue
		var dif=e.global_position-global_position
		var reach=game.tuning.pipe_range*(1.65 if attack_charged else (1.26 if attack_heavy else 1.0))*attack_reach_multiplier()
		if dif.length()<reach+e.body_radius and absf(dif.y)<3.5*growth_multiplier() and (attack_charged or facing.dot(dif.normalized())>-0.12):
			var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,e.global_position+Vector3.UP,1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			var damage=game.tuning.charged_damage*charge_power if attack_charged else (48 if attack_heavy else (30 if combo==3 else 22))
			struck_targets[e.get_instance_id()]=true
			var hit_dir=(dif.normalized()+facing.cross(Vector3.UP)*(0.32 if combo!=2 else -0.32)).normalized()
			e.take_hit(damage*damage_multiplier(),hit_dir,attack_heavy or (weapon_slot==1 and combo==3),attack_ticket)
			var contact=e.global_position+Vector3.UP*(1.5 if e.boss else 1.1)-dif.normalized()*e.body_radius
			if uses_rogue_pipe_profile():rogue_pipe_combo.impact(e,contact,hit_dir,combo)
			else:game.confirm_impact(e,contact,hit_dir,2 if attack_heavy or combo==3 else (1 if combo==2 else 0),false)
			any_hit=true
	var building_damage=game.tuning.charged_damage*charge_power if attack_charged else (48 if attack_heavy else (30 if combo==3 else 22))
	BreakableBuilding.hit_area(game,global_position+Vector3.UP*growth_multiplier(),game.tuning.pipe_range*(1.65 if attack_charged else (1.26 if attack_heavy else 1.0))*attack_reach_multiplier(),building_damage*damage_multiplier(),attack_ticket,facing,-1.0 if attack_charged else -.12,struck_targets)
	if first_sample and not any_hit:
		var environment_ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,center+facing*1.2,1)
		var surface=get_world_3d().direct_space_state.intersect_ray(environment_ray)
		if not surface.is_empty():
			game.impact_effect(surface.position,-facing,0)
			game.sound("environment_hit",0.35)
	if any_hit:
		game.chain+=1
		game.chain_timer=3.0
	if bonus:ComboEnergy.melee_attack(self,attack_ticket,5.0*melee_range_multiplier(),cross)

func take_hit(amount: float, direction: Vector3, projectile: bool=false):
	if sky_strike.active or forward_dash.immunity_left>0 or invuln>0 or hp<=0 or game.tuning.invincible or (active_ability!=null and active_ability.protects_player()): return
	if is_rogue_character():
		amount=active_ability.filter_damage(amount,direction,projectile)
		if amount<=0:return
	if active_ability!=null:active_ability.hit()
	hp=maxf(0,hp-amount*game.tuning.enemy_damage)
	invuln=0.85
	velocity+=direction*7+Vector3.UP*3
	if is_rogue_character():active_ability.receive_knockback(direction)
	game.camera_rig.impulse=0.18
	game.burst(global_position+Vector3.UP,Color("ff6a55"),12)
	game.sound("hurt")
	if hp<=0: game.defeat()

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning or hp<=0: return
	if game.siege_building():
		cancel_charge(true);attack_left=0;queued=false;quick_attacks.stop_coins()
	if game.rogue_battle_mode:game.rogue_view.update_aim()
	attack_chain.tick(delta,attack_left>0 or sky_strike.active or forward_dash.active or (active_ability!=null and active_ability.blocks_movement()))
	if attack_chain.milestone>attack_chain.announced_milestone:
		attack_chain.announced_milestone=attack_chain.milestone
		var title={25:"HEATED",50:"BLAZING",100:"UNLEASHED"}[attack_chain.milestone]
		game.toast("%d LINKS · %s" % [attack_chain.milestone,title])
		game.burst(global_position+Vector3.UP,Color("ff6680"),12,1.2)
		game.sound("spark",.5)
	forward_dash.immunity_left=maxf(0,forward_dash.immunity_left-delta)
	for kind in powerups:powerups[kind]=maxf(0,powerups[kind]-delta)
	if powerups.attack_speed<=0:attack_speed_stacks=0
	if is_rogue_character():
		active_ability.physics_step(delta)
		return
	var attack_delta=delta*attack_speed_multiplier()
	if surge_left>0:
		surge_left=maxf(0,surge_left-delta)
		if surge_left==0:end_surge()
	if sky_strike.active:
		sky_strike.tick(delta);return
	quick_attacks.tick_coins(delta)
	if active_ability!=null:active_ability.tick_timers(delta)
	if impact_pause>0:
		impact_pause=maxf(0,impact_pause-(delta if uses_rogue_pipe_profile() else attack_delta))
		return
	if game.rogue_battle_mode:rogue_controls.tick(delta)
	if character_id==1 and chain_pipe_combat.active:chain_pipe_combat.tick(delta)
	if active_ability!=null:
		active_ability.tick(delta,false)
		if active_ability.blocks_movement():return
	heavy_buffer=maxf(0,heavy_buffer-attack_delta)
	charge_ring.hide()
	invuln=maxf(0,invuln-delta)
	dodge_time=maxf(0,dodge_time-delta)
	dodge_cooldown=maxf(0,dodge_cooldown-delta)
	combo_window=maxf(0,combo_window-delta)
	jump_buffer=maxf(0,jump_buffer-delta)
	wall_jump_grace=maxf(0,wall_jump_grace-delta)
	wall_jump_recovery=maxf(0,wall_jump_recovery-delta)
	if global_position.distance_to(wall_jump_origin)>2.0:wall_jump_grace=0
	if is_on_floor():
		reset_wall_jump()
		coyote=0.13
		jumps_used=0
		air_turn=0
	else: coyote-=delta
	var input=smoke_move if smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back")
	if character_id==2 and musashi.is_casting_meteors():input=Vector2.ZERO
	var yaw=game.camera_rig.yaw
	var dir=Vector3(input.x,0,input.y).rotated(Vector3.UP,yaw)
	var boosting=Input.is_action_pressed("sprint")
	var walking=Input.is_action_pressed("walk_modifier")
	var lifting=can_fly() and Input.is_action_pressed("jump")
	flying=can_fly() and (lifting or not is_on_floor())
	if flying:jump_buffer=0;jump_windup=0;air_turn=0;reset_wall_jump()
	var speed=game.tuning.sprint_speed if boosting else game.tuning.walk_speed
	if walking: speed=minf(speed,2.2)
	speed*=movement_multiplier()
	if flying:speed=(64.0 if boosting else 36.0)*progression.movement_multiplier()
	if attack_left>0:
		if uses_rogue_pipe_profile():
			# Rogue slows only the windup, leaving recovery free to reposition.
			if attack_duration-attack_left<rogue_pipe_combo.CONTACT_TIME:speed*=0.5
		else:speed*=0.42
	var reversing=dir.length()>0.1 and Vector3(velocity.x,0,velocity.z).normalized().dot(dir.normalized())< -0.45
	var accel=((58.0 if reversing else (48.0 if dir.length()<0.1 else 38.0)) if is_on_floor() else (40.0 if jumps_used>=2 else 24.0))*movement_multiplier()
	if flying:accel=90.0*progression.movement_multiplier()
	if forward_dash.active:
		var dash_speed=GoemonDash.SPEED*forward_dash.tempo*minf(1.0,forward_dash.remaining/delta)
		velocity.x=forward_dash.direction.x*dash_speed
		velocity.z=forward_dash.direction.z*dash_speed
	elif dodge_time>0:
		velocity.x=facing.x*23
		velocity.z=facing.z*23
	else:
		# Ease steering back in after push-off, even with the cloak's 3x acceleration.
		if wall_jump_recovery>0:
			accel=minf(accel,24.0)*lerpf(0.08,1.0,smoothstep(0,WALL_JUMP_RECOVERY,WALL_JUMP_RECOVERY-wall_jump_recovery))
		var horizontal_velocity=Vector2(velocity.x,velocity.z).move_toward(Vector2(dir.x,dir.z)*speed,accel*delta)
		velocity.x=horizontal_velocity.x
		velocity.z=horizontal_velocity.y
	if not forward_dash.active and not chain_pipe_combat.active and dodge_time<=0 and wall_jump_recovery<=0 and dir.length()>0.1 and (attack_left<=0 or (jumps_used>=2 and not game.camera_combat() and not game.rogue_battle_mode)):
		# Free movement turns into camera-relative travel in every direction.
		# Attacks and committed abilities keep their existing aim.
		facing=dir.normalized()
	model.rotation.y=lerp_angle(model.rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*(24 if attack_left>0 else 14)))
	if jump_buffer>0:
		if not is_on_floor() and wall_jump_grace>0 and wall_jump_recovery<=0 and jump_windup<=0 and dodge_time<=0 and not forward_dash.active:
			perform_wall_jump()
		elif coyote>0 and jumps_used==0 and jump_windup<=0:
			jump_windup=0.035
			jump_buffer=0
		elif not is_on_floor() and jumps_used<maximum_jumps() and jump_windup<=0:
			# Leaving a ledge already spends the grounded jump; equipment toggles
			# never reset this counter or grant unlimited extra jumps in midair.
			jumps_used=maxi(2,jumps_used+1)
			velocity.y=game.tuning.second_jump_speed*progression.jump_velocity_multiplier()
			jump_buffer=0
			air_turn=0.42
			if dir.length()>0.1:
				facing=dir.normalized()
				var air_speed=maxf(10.2*movement_multiplier(),Vector2(velocity.x,velocity.z).length())
				velocity.x=dir.x*air_speed
				velocity.z=dir.z*air_speed
			game.burst(global_position,Color("a6eff2"),14)
			game.sound("jump")
	model.locomotion.jump_compression=clampf(jump_windup/0.035,0,1)
	if jump_windup>0:
		jump_windup=maxf(0,jump_windup-delta)
		if jump_windup<=0:
			jumps_used=1
			velocity.y=game.tuning.jump_speed*progression.jump_velocity_multiplier()
			coyote=0
			game.burst(global_position,Color("e8dab0"),7)
			game.sound("jump")
	if flying:
		velocity.y=move_toward(velocity.y,(32.0 if boosting else 18.0) if lifting else -10.0,60.0*delta)
	elif not is_on_floor(): velocity.y=maxf(velocity.y-30*delta,-55.0) if game.descent_mode else velocity.y-30*delta
	if character_id==1 and weapon_slot!=3 and attack_left>0:
		var previous_progress=1-attack_left/attack_duration
		attack_left=maxf(0,attack_left-attack_delta)
		var progress=1-attack_left/attack_duration
		var rogue_pipe=uses_rogue_pipe_profile()
		var contact_phase=rogue_pipe_combo.contact_phase(combo) if rogue_pipe else (0.47 if attack_heavy else (PipeCombo.CONTACT[combo-1] if weapon_slot==1 else 0.36))
		if not swing_played and (progress>=contact_phase if rogue_pipe else progress>contact_phase-0.13):
			play_swing_sound()
		if not rogue_pipe and not combo_step_done and progress>0.18 and weapon_slot==1 and not attack_heavy:
			combo_step_done=true
			velocity+=facing*(4.2 if combo==1 else (3.0 if combo==2 else 5.4))
		if progress>=contact_phase and previous_progress<contact_phase+(0.0 if rogue_pipe else (PipeCombo.ACTIVE[combo-1] if weapon_slot==1 and not attack_heavy else 0.16)):
			if not hit_done:
				if weapon_slot==1 and not rogue_pipe: velocity+=facing*(4.5 if attack_heavy else 2.5)
				strike()
			elif weapon_slot==1: strike()
		if attack_left<=0:
			if heavy_buffer>0:
				heavy_buffer=0
				start_attack(true)
			elif weapon_slot==1 and not attack_heavy and combo<3 and not game.rogue_battle_mode: start_attack(false,combo+1)
	if character_id==1:quick_attacks.tick()
	last_vertical=velocity.y
	# Step across tiny risers and deck joints without losing momentum.
	if is_on_floor() and dir.length()>0.1:
		var motion=Vector3(velocity.x,0,velocity.z)*delta
		if test_move(global_transform,motion):
			var raised=global_transform
			raised.origin.y+=0.32
			if not test_move(raised,motion): position.y+=0.32
	var before_move=global_position
	move_and_slide()
	remember_wall_contact()
	forward_dash.after_move(before_move,delta)
	model.locomotion_velocity=(global_position-before_move)/maxf(delta,0.0001)
	if is_on_floor() and not was_floor and last_vertical<-5:
		model.landing=minf(1,abs(last_vertical)/16)
		game.camera_rig.kick(Vector3.DOWN,0.035+model.landing*0.045)
		game.burst(global_position,Color("e7d3a3"),10)
		game.sound("land")
	was_floor=is_on_floor()
	var horizontal=Vector2(velocity.x,velocity.z).length()
	model.locomotion.free_feet=air_turn>0 or (attack_charged and attack_left>0 and weapon_slot==1)
	model.charge_requested=false
	model.charge_release=1.0-attack_left/attack_duration if attack_charged and attack_left>0 else -1.0
	model.charge_slot=weapon_slot
	model.pipe_combo_active=character_id==1 and weapon_slot==1 and not attack_heavy and attack_left>0
	model.rogue_pipe_combo_active=uses_rogue_pipe_profile() and attack_left>0
	model.wide_swing_active=wide_swing and attack_left>0
	model.animate(delta,horizontal,is_on_floor(),velocity.y,attack_left/attack_duration,attack_heavy,combo,dodge_time>0 or forward_dash.active)
	flight_lean=lerpf(flight_lean,(-.28 if boosting else -.18) if flying else 0.0,1-exp(-delta*9))
	if character_id==1:model.body.rotation.x+=flight_lean
	air_turn=maxf(0,air_turn-delta)
	if air_turn>0:
		if scarf_equipped and character_id==1:
			var progress=clampf(1-air_turn/.42,0,1)
			var tuck=sin(PI*progress)
			if jumps_used in [2,3]:
				# Rising turns alternate direction on the second and third jumps.
				model.body.rotation.y=TAU*(-1.0 if jumps_used==2 else 1.0)*smoothstep(0,1,progress)
				model.body.rotation.x=-.10*tuck
			elif jumps_used==4:
				# One forward somersault around the torso, not around the feet.
				var angle=-TAU*smoothstep(0,1,progress)
				model.body.rotation.x=angle
				model.body.rotation.y=0
				var pivot=Vector3(0,1.4,0)
				model.body.position+=pivot-Basis(Vector3.RIGHT,angle)*pivot
			else:model.body.rotation.x=-.10*tuck
			for leg in model.legs:leg.rotation.x=-(.65 if jumps_used==4 else .28)*tuck
		else:
			var angle=-TAU*(1-air_turn/0.42)
			model.body.rotation.x=angle
			model.body.rotation.y=0
			var pivot=Vector3(0,1.4,0)
			model.body.position+=pivot-Basis(Vector3.RIGHT,angle)*pivot
			for leg in model.legs: leg.rotation.x=-0.65
	elif character_id==1 and attack_charged and attack_left>0 and weapon_slot==1:
		model.body.rotation.y=TAU*smoothstep(0.12,0.82,1-attack_left/attack_duration)
	if character_id==1 and weapon_slot==2 and attack_left>0 and not attack_charged:
		model.arms[1].rotation.x=-1.5-sin((1-attack_left/attack_duration)*PI)*0.6
		model.arms[1].rotation.y=-0.4
	model.coin.scale=Vector3.ONE*0.78*(game.tuning.surge_coin_size if surge_left>0 else 1.0)
	model.visible=not (invuln>0 and int(invuln*20)%2==0)
	if model.locomotion.step_events!=last_foot_events:
		last_foot_events=model.locomotion.step_events
		if is_on_floor() and horizontal>1.0:
			game.burst(global_position,Color("e0d2a4"),2,0.55)
			game.sound("step",0.22)
	trail_time-=delta
	if horizontal>14 and trail_time<=0:
		trail_time=0.065
		game.wind(global_position+Vector3(0,0.8,0),-facing)
	if game.descent_mode:
		# Keep long falls over the physical ground map without returning uphill.
		var bounds=game.world.playable_bounds.grow(-2)
		var edge_x=clampf(global_position.x,bounds.position.x,bounds.end.x)
		var edge_z=clampf(global_position.z,bounds.position.y,bounds.end.y)
		if edge_x!=global_position.x:global_position.x=edge_x;velocity.x=0
		if edge_z!=global_position.z:global_position.z=edge_z;velocity.z=0
	elif global_position.y<-5 or not game.world.playable_bounds.grow(3).has_point(Vector2(global_position.x,global_position.z)):
		hp=maxf(1,hp-10)
		global_position=game.checkpoint
		velocity=Vector3.ZERO
		jumps_used=0
		reset_wall_jump()
		game.camera_rig.reset_follow()
		game.toast("Returned to the last sanctuary · −10 vitality")

func reset_wall_jump():
	wall_jump_grace=0
	wall_jump_recovery=0
	wall_jump_normal=Vector3.ZERO
	wall_jump_origin=global_position

func remember_wall_contact():
	if is_on_floor():
		reset_wall_jump()
		return
	if wall_jump_recovery>0 or forward_dash.active or dodge_time>0:return
	for i in range(get_slide_collision_count()):
		var normal=get_slide_collision(i).get_normal()
		# Only near-vertical walls qualify, never floors, walkable slopes or ceilings.
		if absf(normal.y)>0.25:continue
		wall_jump_normal=Vector3(normal.x,0,normal.z).normalized()
		wall_jump_origin=global_position
		wall_jump_grace=WALL_JUMP_GRACE
		break

func perform_wall_jump():
	var horizontal=Vector3(velocity.x,0,velocity.z)
	# Keep travel along the wall while replacing inward motion with a clean kick.
	horizontal=horizontal.slide(wall_jump_normal)+wall_jump_normal*maxf(WALL_JUMP_PUSH,horizontal.dot(wall_jump_normal))
	velocity=horizontal+Vector3.UP*game.tuning.second_jump_speed*progression.jump_velocity_multiplier()
	facing=horizontal.normalized()
	jump_buffer=0;coyote=0;air_turn=0
	# Wall hops work after all air jumps are spent, but never refill their budget.
	jumps_used=maxi(1,jumps_used)
	wall_jump_grace=0
	wall_jump_recovery=WALL_JUMP_RECOVERY
	if model.locomotion is HeroLocomotion:model.locomotion.air_age=0
	game.burst(global_position-wall_jump_normal*0.38+Vector3.UP*0.7,Color("e7d3a3"),7)
	game.sound("land")

func select_weapon(slot: int):
	if slot not in [1,2,3]:return
	if character_id==2:
		musashi.select_weapon(true)
		return
	cancel_charge()
	heavy_buffer=0
	weapon_slot=slot
	attack_left=0
	queued=false
	combo_window=0
	set_weapon_visual(slot)
	game.toast({1:"Golden pipe",2:"Gold cash coins",3:"Chain pipe"}[slot])

func set_weapon_visual(slot: int):
	model.equipped=slot in [1,3]
	model.chain_selected=slot==3
	model.chain_pipe.visible=slot==3
	model.pipe.visible=slot==1
	model.coin.visible=slot==2


func cancel_charge(preserve_power: bool=false,preserve_battle_hold: bool=false):
	if rogue_pipe_combo!=null:rogue_pipe_combo.clear()
	if is_instance_valid(model):model.rogue_pipe_combo_active=false
	if rogue_controls!=null:rogue_controls.reset(preserve_battle_hold)
	if forward_dash!=null:forward_dash.cancel()
	if chain_pipe_combat!=null:chain_pipe_combat.cancel()
	if quick_attacks!=null:quick_attacks.cancel()
	if sky_strike!=null:sky_strike.cancel()
	if active_ability!=null:active_ability.cancel(preserve_power)
	primary_down=false
	charge_elapsed=0
	if is_instance_valid(charge_ring): charge_ring.hide()

func growth_multiplier()->float:return minf(MAX_GROWTH,1.0+buildings_broken*GROWTH_PER_BUILDING)

func grow_from_building():
	buildings_broken+=1
	scale=Vector3.ONE*growth_multiplier()
	game.toast("BUILDING BROKEN · Size and reach ×%.2f" % growth_multiplier())

func range_multiplier()->float:
	return growth_multiplier()*(game.tuning.surge_range if surge_left>0 else 1.0)*pickup_multiplier("range")

func melee_range_multiplier()->float:
	return range_multiplier()*(game.tuning.surge_range if attack_charged and surge_left<=0 else 1.0)

func attack_reach_multiplier()->float:
	var basic = not attack_heavy and not attack_charged and not wide_swing
	return melee_range_multiplier() * (BASIC_ATTACK_RANGE_MULTIPLIER if basic else 1.0)

func emit_robe_coins(radial: bool=false):
	if character_id!=1 or not scarf_equipped:return
	game.throw_robe_coins(facing,radial,weapon_slot==2)

func movement_multiplier()->float:
	return progression.movement_multiplier()*(3.0 if scarf_equipped and character_id==1 else 1.0)

func maximum_jumps()->int:
	return 4 if scarf_equipped and character_id==1 else 2

func can_fly()->bool:return gold_cloak and scarf_equipped and character_id==1

func set_gold_cloak(value: bool):
	if character_id!=1:return
	set_scarf_equipped(value)
	gold_cloak=value
	character_models[1].ronin_scarf.cloth.set_shader_parameter("gold_cloak",value)
	game.toast("GOLD CLOAK · Hold Space to ascend · Shift to boost · Release to descend" if value else "Gold cloak removed")

func set_scarf_equipped(value: bool):
	gold_cloak=false;flying=false
	character_models[1].ronin_scarf.cloth.set_shader_parameter("gold_cloak",false)
	scarf_equipped=value
	character_models[1].ronin_scarf.set_equipped(value)
	# Remove excess momentum immediately when taking the scarf off.
	if not value and character_id==1:
		air_turn=0
		var speed_limit=game.tuning.sprint_speed if Input.is_action_pressed("sprint") else game.tuning.walk_speed
		speed_limit*=movement_multiplier()
		var horizontal=Vector2(velocity.x,velocity.z).limit_length(speed_limit)
		velocity.x=horizontal.x;velocity.z=horizontal.y
	game.toast("RONIN CLOAK · 3× movement · Quad jump · Bonus coins" if value else "Ronin cloak removed · Normal speed · Double jump")

func activate_surge():
	if surge_left>0 and not attack_chain.unleashed(): return
	surge_left=game.tuning.surge_duration
	model.set_surge(true)
	if is_instance_valid(model.chain_pipe):model.chain_pipe.powered=true
	aura.show()
	game.burst(global_position+Vector3.UP,Color("ffe69b"),24)
	game.sound("spark")
	game.toast("GOLDEN SURGE · Wind spin / Giant toss / Explosive chain + Fire sweep")

func end_surge():
	surge_left=0
	model.set_surge(false)
	if is_instance_valid(model.chain_pipe):model.chain_pipe.powered=false
	aura.hide()

func select_character(id: int):
	if id==character_id:
		if game.rogue_roster_mode and (id in [1,2] or is_rogue_character()):game.selected_rogue_id=id
		return
	if not ROSTER.has(id) and not (game.rogue_roster_mode and RogueRoster.is_rogue(id)):return
	var health_fraction=hp/maxf(1.0,max_hp)
	var was_rogue=is_rogue_character()
	quick_attacks.stop_coins()
	cancel_charge()
	if surge_left>0:end_surge()
	if character_abilities.has(character_id):character_abilities[character_id].active=false
	var rotation_before=model.rotation
	model.hide();model.set_process(false)
	attack_left=0;attack_charged=false;heavy_buffer=0;combo=0;queued=false;impact_pause=0;air_turn=0
	ensure_character(id)
	character_id=id;model=character_models[id];model.rotation=rotation_before;model.show();model.set_process(true)
	if id==2:
		var horizontal=Vector2(velocity.x,velocity.z).limit_length(game.tuning.sprint_speed*movement_multiplier())
		velocity.x=horizontal.x;velocity.z=horizontal.y
	active_ability=character_abilities.get(id)
	if active_ability!=null:
		active_ability.active=true;active_ability.cancel()
		if id==2:musashi=active_ability
	if was_rogue or is_rogue_character():
		refresh_max_health()
		hp=max_hp*health_fraction
	last_foot_events=model.locomotion.step_events
	if game.rogue_roster_mode and (id in [1,2] or is_rogue_character()):game.selected_rogue_id=id
	if is_rogue_character():
		game.toast(RogueRoster.name_for(id)+(" · LMB Attack · RMB / 3 Secondary · C Evade · E Utility · R Skill · Q Heroes" if game.camera_combat() else " · LMB Attack · RMB / 3 Secondary · C / E Utility · R Skill · Q Fighters"))
	elif game.rogue_roster_mode and id==1:
		game.toast("Goemon · Q Fighters · Hold LMB Combo · RMB Heavy · C Evade · E Dash · R Surge")
	else:game.toast(ROSTER[id].name+" · Q Switch character · "+("LMB Triple fireball · RMB Giant fireball · T Meteor rain · R Beam" if id==2 else "1 Wind spin · 2 Auto coins ON/OFF · 3 Long sweep · C Evade"))

func is_rogue_character()->bool:
	return RogueRoster.is_rogue(character_id)

func rogue_untargetable()->bool:
	return is_rogue_character() and active_ability!=null and active_ability.untargetable()

func ensure_character(id: int):
	if character_models.has(id):return
	if RogueRoster.is_rogue(id):
		var visual=load("res://scripts/rogue_hero_model.gd").new()
		visual.class_id=RogueRoster.class_id(id);add_child(visual);character_models[id]=visual
		var ability=load("res://scripts/rogue_roster_combat.gd").new()
		ability.hero=self;ability.game=game;add_child(ability)
		character_abilities[id]=ability;visual.combat=ability
		ability.configure(self,visual.class_id);ability.sync_actor(visual.actor)
		visual.hide();visual.set_process(false)
		return
	var entry=ROSTER[id]
	var visual=entry.model.new();add_child(visual);character_models[id]=visual
	if entry.has("combat"):
		var ability=entry.combat.new();ability.hero=self;ability.game=game;add_child(ability)
		character_abilities[id]=ability;visual.combat=ability
	character_models[id].hide()
	character_models[id].set_process(false)

func pickup_multiplier(kind: String)->float:
	if powerups.get(kind,0.0)<=0:return 1.0
	if kind=="attack_speed":return 1.0+.5*maxi(1,attack_speed_stacks)
	return {"damage":1.5,"range":1.5,"attack_speed":1.5}.get(kind,1.0)
func damage_multiplier()->float:
	return game.tuning.damage_mult*pickup_multiplier("damage")*(1.0+.1*run_upgrades.damage)
func base_attack_speed_multiplier()->float:
	return progression.attack_multiplier()*pickup_multiplier("attack_speed")*(1.0+.05*run_upgrades.tempo)
func attack_speed_multiplier()->float:
	return base_attack_speed_multiplier()*attack_chain.multiplier()

func refresh_max_health(heal_growth: bool=false):
	var previous=max_hp
	max_hp=game.tuning.max_hp*progression.health_multiplier()*(1.0+.1*run_upgrades.vitality)
	if is_rogue_character():max_hp=max_hp*float(RogueRoster.data(character_id).get("maxHealth",100))/100.0
	hp=minf(max_hp,hp+(maxf(0,max_hp-previous) if heal_growth else 0.0))

func award_kill():
	if not game.playing or game.paused or game.transitioning or hp<=0:return
	if progression.award_kills()>0:
		refresh_max_health(true)
		game.toast("LEVEL %d%s · HP %d · Attack +%.1f%% · Move +%.1f%% · Jump +%.1f%%" % [progression.level," · MAX" if progression.level==progression.MAX_LEVEL else "",roundi(max_hp),(progression.attack_multiplier()-1)*100,(progression.movement_multiplier()-1)*100,(progression.jump_height_multiplier()-1)*100])
		game.sound("spark",.5)
		game.burst(global_position+Vector3.UP,Color("f6d485"),12)

func collect_powerup(kind: String):
	if elemental_orbs.has(kind):
		elemental_orbs[kind]+=1
		if elemental_orbs[kind]>=5:
			elemental_orbs[kind]-=5
			game.orb_system.queue_burst(kind)
		return
	if not powerups.has(kind):return
	if kind=="attack_speed":
		attack_speed_stacks=mini(MAX_ATTACK_SPEED_STACKS,(attack_speed_stacks if powerups.attack_speed>0 else 0)+1)
	powerups[kind]=EnergyPickup.DURATION
	if kind=="attack_speed":
		game.toast("ATTACK SPEED ×%.1f · %d / %d stacks · 20 seconds" % [attack_speed_multiplier(),attack_speed_stacks,MAX_ATTACK_SPEED_STACKS])
		return
	game.toast(EnergyPickup.LABELS[kind]+" · 20 seconds")
func clear_powerups():
	quick_attacks.stop_coins()
	attack_chain.reset()
	for kind in elemental_orbs:elemental_orbs[kind]=0
	if is_instance_valid(game.orb_system):game.orb_system.pending.clear()
	attack_speed_stacks=0
	for kind in powerups:powerups[kind]=0.0
