class_name Hero
extends CharacterBody3D

# Gate allies use the same physical character and kit, with explicit AI intent.
var ai_controlled=false
var ai_move=Vector3.ZERO
var ai_aim=Vector3.ZERO
var ai_target: Ninja
var game: Node
var auto_attack_enabled=false
var auto_attack_clock=0.0
var auto_lock_target: Ninja
var auto_lock_refresh=0.0
var auto_lock_had_target=false
var character_id=1
var character_models: Dictionary={}
var character_abilities: Dictionary={}
var musashi: MusashiCombat
var body_shape: CollisionShape3D
var active_ability: Node
var master_chief_combat: Node
const BASIC_ATTACK_RANGE_MULTIPLIER = 1.0
const MELEE_CONTACT_MULTIPLIER = 1.12
var melee_assist=preload("res://scripts/melee_assist.gd").new()
const Proportions=preload("res://scripts/character_proportions.gd")
const OriginalGoemon=preload("res://scripts/recovered_goemon_combat_profile.gd")
const ROSTER={1: {"name":"Goemon", "model":preload("res://scripts/recovered_goemon_model.gd")},2: {"name":"Edo", "model":preload("res://assets/characters/musashi/model/musashi_model.gd"),"combat":preload("res://assets/characters/musashi/combat/musashi_combat.gd")},13: {"name":"Musashi","model":preload("res://scripts/recovered_musashi_model.gd"),"combat":preload("res://scripts/recovered_musashi_combat.gd")},14:{"name":"Ed","model":preload("res://scripts/recovered_ed_model.gd"),"combat":preload("res://scripts/recovered_leader_combat.gd")},15:{"name":"Ben","model":preload("res://scripts/recovered_ben_model.gd"),"combat":preload("res://scripts/recovered_leader_combat.gd")},16:{"name":"Sasuke","model":preload("res://scripts/recovered_sasuke_model.gd"),"combat":preload("res://scripts/recovered_sasuke_combat.gd")},17:{"name":"Yae","model":preload("res://scripts/recovered_yae_model.gd"),"combat":preload("res://scripts/recovered_yae_combat.gd")},18:{"name":"Master Chief","model":preload("res://scripts/master_chief_model.gd"),"combat":preload("res://scripts/master_chief_combat.gd")}}
const RogueRoster=preload("res://scripts/rogue_roster.gd")
const GroundResponse=preload("res://scripts/ground_movement_response.gd")
var model: HeroModel
var hp=100.0
var max_hp=100.0
var progression=preload("res://scripts/level_progression.gd").new()
var facing=Vector3.FORWARD
const COMBAT_AIM_HOLD=.28
var combat_aim_left=0.0

var attack_left=0.0
var original_pipe_combat:RefCounted
var weapon_controls:RefCounted
var attack_motion_pending=false
const MeleeResponse=preload("res://scripts/melee_responsiveness.gd")
var attack_duration=0.42
var original_coin_action=0x7C
var pipe_contact_phase=-1.0
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

func hold_combat_aim():
	if game.has_method("forest_enemy_visible"):combat_aim_left=COMBAT_AIM_HOLD
func tick_combat_aim(delta: float):
	combat_aim_left=maxf(0,combat_aim_left-delta)
	if dodge_time>0 or forward_dash.active or sky_strike.active:combat_aim_left=0;return
	if character_id==2 and (musashi.is_attacking() or musashi.beam_held):hold_combat_aim()
	if character_id==1 and weapon_slot==2 and attack_left>0:hold_combat_aim()
	if is_rogue_character():
		var data: Dictionary=active_ability.player
		if data.roll>0 or data.travel!=null or data.get("dive")!=null:combat_aim_left=0;return
		if data.charging or (active_ability.class_id in ["mage","ranger"] and data.attack!=null):hold_combat_aim()
func combat_aiming()->bool:
	if not game.has_method("forest_enemy_visible") or combat_aim_left<=0:return false
	if dodge_time>0 or forward_dash.active or sky_strike.active:return false
	return true

func _ready():
	original_pipe_combat=preload("res://scripts/recovered_goemon_pipe_combat.gd").new(self)
	weapon_controls=preload("res://scripts/goemon_weapon_controls.gd").new(self)
	attack_chain.hero_owner=weakref(self)
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
	var shape=CollisionShape3D.new();body_shape=shape
	var capsule=CapsuleShape3D.new()
	capsule.radius=0.38
	capsule.height=1.85
	shape.shape=capsule
	shape.position.y=0.95
	add_child(shape)
	_setup_initial_model()
	aura=SurgeAura.new()
	add_child(aura)
	aura.hide()
	charge_ring=Node3D.new();add_child(charge_ring)
	charge_ring.hide()
	max_hp=combat_tuning("max_hp")*progression.health_multiplier()*(1.0+.1*run_upgrades.vitality)
	hp=max_hp
	# Load registered visuals during startup so selection does not load a GLB mid-fight.
	for id in ROSTER:
		if ai_controlled and id==18:continue
		ensure_character(id)

func _setup_initial_model():
	model=ROSTER[1].model.new()
	model.skin_id=HeroSkins.valid_id(game.settings.goemon_skin)
	add_child(model)
	character_models[1]=model

func _input(event):
	if ai_controlled:return
	if weapon_controls!=null:weapon_controls.release(event)
	# Release must arrive even when a menu consumes the pointer event.
	if rogue_controls!=null:rogue_controls.release(event)
	if active_ability!=null and active_ability.has_method("release_input"):active_ability.release_input(event)

func _unhandled_input(event):
	if ai_controlled:return
	if not game.playing or game.paused or game.transitioning or hp<=0: return
	if event.is_action_pressed("auto_attack_toggle") and not event.is_echo():
		if game.camera_combat() and not is_master_chief():set_auto_attack(not auto_attack_enabled)
		get_viewport().set_input_as_handled();return
	if game.siege_building() and (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack") or event.is_action_pressed("weapon_pipe") or event.is_action_pressed("weapon_coin") or event.is_action_pressed("weapon_chain") or event.is_action_pressed("surge") or event.is_action_pressed("sky_strike")):return
	if weapon_controls.input(event):
		get_viewport().set_input_as_handled();return
	if game.camera_combat() and event.is_action_pressed("assist"):return
	if game.rogue_battle_mode:game.rogue_view.update_aim()
	if game.rogue_roster_mode and event.is_action_pressed("character_toggle") and not event.is_echo():
		game.show_rogue_roster();get_viewport().set_input_as_handled();return
	if is_rogue_character():
		active_ability.input(event)
		return
	if is_master_chief():
		if event.is_action_pressed("character_toggle") and not event.is_echo():
			var ids=RogueRoster.selection_ids().filter(func(id):return ROSTER.has(id));select_character(ids[(ids.find(character_id)+1)%ids.size()])
		elif event.is_action_pressed("jump") and not event.is_echo() and movement_jump_available():jump_buffer=.15
		else:active_ability.input(event)
		return
	if character_id==13:
		if event.is_action_pressed("character_toggle") and not event.is_echo():
			var ids=RogueRoster.selection_ids().filter(func(id):return ROSTER.has(id));select_character(ids[(ids.find(character_id)+1)%ids.size()])
		elif event.is_action_pressed("jump") and not event.is_echo():
			if movement_jump_available():jump_buffer=.15
		else:active_ability.input(event)
		return
	if event.is_action_pressed("jump") and not event.is_echo():
		if movement_jump_available():
			jump_buffer=.15
		return
	if event.is_action_pressed("dodge") and not event.is_echo() and dodge_cooldown<=0:
		interrupt_attack_for_movement()
		if game.camera_combat() or game.rogue_battle_mode:facing=rogue_dodge_direction()
		attack_chain.active_ticket["move_audio"]=game.move_audio.begin(self,"evade")
		dodge_time=.28;dodge_cooldown=.75;invuln=.32;play_sound("dash",1.0,attack_chain.active_ticket)
		return
	if character_id==1 and event.is_action_pressed("weapon_coin") and not event.is_echo():
		quick_attacks.request(2);return
	if attack_chain.unleashed() and sky_strike.active:sky_strike.cancel()
	if forward_dash.active and not attack_chain.unleashed() and not event.is_action_pressed("character_toggle"):return
	if event.is_action_pressed("sky_strike") and not event.is_echo() and character_id==1:
		sky_strike.request();return
	if sky_strike.active and not event.is_action_pressed("character_toggle"):return
	if event.is_action_pressed("character_toggle") and not event.is_echo():
		var ids=RogueRoster.selection_ids().filter(func(id):return ROSTER.has(id));select_character(ids[(ids.find(character_id)+1)%ids.size()])
	if active_ability!=null:
		active_ability.input(event)
		if active_ability.blocks_movement():return
		if event.is_action_pressed("assist"):soft_target=not soft_target
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

func rogue_dodge_direction()->Vector3:
	var move=Input.get_vector("move_left","move_right","move_forward","move_back")
	return Vector3(move.x,0,move.y).rotated(Vector3.UP,game.camera_rig.yaw).normalized() if move.length_squared()>.01 else combat_attack_direction()

func start_attack(heavy: bool, stage: int=1, charged: bool=false, power: float=1.0,action: String=""):
	if character_id==1 and weapon_slot!=2:combat_aim_left=0
	if weapon_slot==1:attack_motion_pending=true
	if game.rogue_battle_mode or game.camera_combat():facing=combat_attack_direction()
	var move_key=""
	if character_id==1:
		move_key=("coin_charged" if charged else ("coin_heavy" if heavy else "coin")) if weapon_slot==2 else (action if not action.is_empty() else ("heavy" if heavy else "primary_%d"%clampi(stage,1,3)))
		if weapon_slot==1 and charged:move_key="spin"
	attack_ticket=attack_chain.begin(action if not action.is_empty() else ("coin" if weapon_slot==2 else ("heavy" if heavy else "pipe")),move_key)
	wide_swing=action=="wide"
	if weapon_slot==1 and not model.equipped: model.equipped=true
	attack_heavy=heavy
	attack_charged=charged and (surge_left>0 or action=="spin")
	charge_power=power
	combo=stage
	attack_duration=0.74 if heavy else PipeCombo.DURATIONS[clampi(combo-1,0,2)]
	if weapon_slot==2: attack_duration=0.64 if heavy else 0.32
	if uses_rogue_pipe_profile() and not uses_original_goemon_attack():
		attack_duration=rogue_pipe_combo.duration(stage)
		rogue_pipe_combo.prepare()
		velocity+=facing*(2.5 if stage==3 else 1.25)
	if uses_original_goemon_attack():attack_duration=OriginalGoemon.duration(3 if attack_heavy else combo)
	elif character_id==1 and weapon_slot==2:
		original_coin_action=OriginalGoemon.coin_action(is_on_floor(),Vector2(velocity.x,velocity.z).length()>.25)+(3 if attack_charged else 0)
		attack_duration=OriginalGoemon.action_duration(original_coin_action)
	pipe_contact_phase=-1.0
	if not uses_original_goemon_attack() and game.has_method("forest_enemy_visible") and character_id==1 and weapon_slot==1 and not attack_heavy and not attack_charged and not wide_swing:
		pipe_contact_phase=MeleeResponse.contact_time(attack_duration*PipeCombo.CONTACT[clampi(combo-1,0,2)])/attack_duration
	model.pipe_contact_phase=pipe_contact_phase
	attack_left=attack_duration
	hit_done=false
	struck_targets.clear()
	if character_id==1 and weapon_slot==2:
		attack_ticket["original_goemon_coin_entry"]=true
		if not attack_charged:play_sound("move_coin_heavy_weapon" if attack_heavy else "move_coin_weapon",1.0,attack_ticket)
	swing_played=false
	combo_step_done=false
	queued=false
	combo_window=rogue_pipe_combo.COMBO_WINDOW if uses_rogue_pipe_profile() else 0.8
	if attack_charged and weapon_slot==1:
		var wind=SpinWind.new();wind.hero=self;add_child(wind)
	if weapon_slot==2:
		facing=combat_attack_direction()
	if soft_target and weapon_slot==1 and not game.rogue_battle_mode and not game.has_method("forest_enemy_visible"):
		var best: Node3D=null
		var dist=combat_tuning("pipe_range")*attack_reach_multiplier()+1.5
		for e in game.enemies:
			if not is_instance_valid(e) or e.dead: continue
			var dif=e.global_position-global_position
			if dif.length()<dist and facing.dot(dif.normalized())>-0.3:
				best=e
				dist=dif.length()
		if best:
			facing=(best.global_position-global_position).normalized()
			facing.y=0
	if character_id==1 and weapon_slot==1:
		melee_assist.begin(self,atan2(facing.x,facing.z),melee_strike_reach())
		var angle=melee_assist.steer(self,atan2(facing.x,facing.z),.012)
		facing=Vector3(sin(angle),0,cos(angle))
	# A live chain enters the contact pose immediately instead of replaying windup.
	if uses_original_goemon_attack():
		original_pipe_combat.begin()
		game.move_audio.release(game,attack_ticket)
	if attack_chain.unleashed() and not game.rogue_battle_mode:
		impact_pause=0;combo_step_done=true;play_swing_sound();strike();attack_left=0
	elif weapon_slot==1 and attack_chain.energized() and not game.rogue_battle_mode:
		attack_left=attack_duration*(1.0-attack_contact_phase())
		impact_pause=0
		play_swing_sound()
		combo_step_done=true
		velocity+=facing*((4.5 if heavy else 2.5)+(0.0 if heavy else (4.2 if combo==1 else (3.0 if combo==2 else 5.4))))
		strike()

func uses_original_goemon_attack()->bool:
	return character_id==1 and weapon_slot==1 and not attack_charged and not wide_swing

func uses_rogue_pipe_profile()->bool:
	return game.rogue_roster_mode and game.rogue_battle_mode and character_id==1 and weapon_slot==1 and not attack_heavy and not attack_charged and not wide_swing and attack_ticket.get("action","")=="pipe"

# Hero-owned audio carries its source even when this Hero is an allied defender.
func play_sound(kind: String,volume: float=1.0,ticket: Dictionary={}):
	game.sound(kind,volume,false,attack_ticket if ticket.is_empty() else ticket,character_id)

func play_swing_sound():
	swing_played=true
	if uses_original_goemon_attack():
		play_sound("heavy_swing" if attack_heavy or combo==3 else "swing");return
	if character_id==1 and weapon_slot==2:return # Coin preparation is sounded at entry; voice at release.
	if uses_rogue_pipe_profile():
		rogue_pipe_combo.release(combo);return
	play_sound("spin_swing" if attack_charged and weapon_slot==1 else ("heavy_swing" if attack_heavy or (weapon_slot==1 and combo==3) else "swing"))

func strike():
	if uses_original_goemon_attack():
		var elapsed=attack_duration-attack_left
		original_pipe_combat.tick(elapsed,elapsed)
		return
	var first_sample=not hit_done
	if character_id==1 and weapon_slot==1:melee_assist.contact()
	var bonus=first_sample and weapon_slot==1 and attack_chain.energized()
	var cross=(wide_swing or attack_ticket.get("action","")=="spin") and attack_chain.previous=="heavy"
	hit_done=true
	if first_sample:emit_robe_coins(attack_charged and weapon_slot==1)
	if weapon_slot==2:
		game.throw_coin(attack_heavy,attack_charged,charge_power)
		return
	if not attack_charged:
		# Contact resolves against the same articulated pose shown this frame.
		model.pipe_combo_active=not attack_heavy and not wide_swing
		model.rogue_pipe_combo_active=model.pipe_combo_active and uses_rogue_pipe_profile()
		model.wide_swing_active=wide_swing
		model.pipe_visual_scale=HeroModel.WeaponProportions.SCALE*combat_tuning("pipe_range")/3.5*range_multiplier()*melee_reach_setting()/maxf(.01,growth_multiplier())
		model.animate(0,Vector2(velocity.x,velocity.z).length(),is_on_floor(),velocity.y,attack_left/attack_duration,attack_heavy,combo,false)
		model.sync_skeleton()
	var reach=melee_strike_reach()
	var contact_size=contact_size_multiplier()
	var probe_size=contact_size if character_id==13 else 1.0
	var center=global_position+(Vector3.UP*1.1+facing*1.1)*contact_size
	if first_sample and attack_charged:
		play_sound("dash",.45)
	elif first_sample:
		if uses_original_goemon_attack():pass # The recovered weapon draws the source swing.
		elif uses_rogue_pipe_profile():rogue_pipe_combo.slash(combo)
		elif character_id in [13,15,16,17]:pass # Recovered weapons draw their trail from the moving blade.
		elif wide_swing:game.combo_slash(center,facing,2,attack_reach_multiplier()*combat_tuning("pipe_range")*1.26/3.5)
		elif attack_heavy: game.slash(center,facing,true,combo,Color("ffdf83"),attack_reach_multiplier()*combat_tuning("pipe_range")/3.5)
		else: game.combo_slash(global_position+Vector3.UP*1.1*growth_multiplier(),facing,combo,reach/3.5)
	var any_hit=false
	for e in game.enemies:
		if not is_instance_valid(e) or e.dead or struck_targets.has(e.get_instance_id()): continue
		var hurt=AttackChain.contact_point(e,global_position+Vector3.UP*1.1*probe_size,e.global_position)
		if character_id==13 and not active_ability.can_hit_target(e):continue
		var dif=hurt-global_position
		var radial=character_id==13 and active_ability.mode in ["rotation","counter"]
		if dif.length()<reach+e.body_radius and absf(dif.y)<3.5*contact_size and (radial or attack_charged or facing.dot(dif.normalized())>-0.12):
			var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*probe_size,AttackChain.contact_point(e,global_position+Vector3.UP*probe_size,e.global_position+Vector3.UP),1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			var damage=combat_tuning("charged_damage")*charge_power if attack_charged else (48 if attack_heavy else (30 if combo==3 else 22))
			struck_targets[e.get_instance_id()]=true
			var hit_dir=(dif.normalized()+facing.cross(Vector3.UP)*(0.32 if combo!=2 else -0.32)).normalized()
			e.take_hit(damage*damage_multiplier(),hit_dir,attack_heavy or (weapon_slot==1 and combo==3),attack_ticket)
			var contact=AttackChain.contact_point(e,global_position+Vector3.UP*1.1*probe_size,e.global_position+Vector3.UP*(1.5 if e.boss else 1.1)-dif.normalized()*e.body_radius)
			if uses_rogue_pipe_profile() and not uses_original_goemon_attack():rogue_pipe_combo.impact(e,contact,hit_dir,combo)
			elif ai_controlled:game.confirm_ally_impact(e,contact,hit_dir,2 if attack_heavy or combo==3 else (1 if combo==2 else 0),false,character_id)
			else:game.confirm_impact(e,contact,hit_dir,2 if attack_heavy or combo==3 else (1 if combo==2 else 0),false)
			any_hit=true
	var building_damage=combat_tuning("charged_damage")*charge_power if attack_charged else (48 if attack_heavy else (30 if combo==3 else 22))
	BreakableBuilding.hit_area(game,global_position+Vector3.UP*contact_size,reach,building_damage*damage_multiplier(),attack_ticket,facing,-1.0 if attack_charged or (character_id==13 and active_ability.mode in ["rotation","counter"]) else -.12,struck_targets)
	if first_sample and not any_hit:
		var environment_ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*probe_size,center+facing*1.2,1)
		var surface=get_world_3d().direct_space_state.intersect_ray(environment_ray)
		if not surface.is_empty():
			game.impact_effect(surface.position,-facing,0)
			play_sound("environment_hit",0.35)
	if any_hit and not ai_controlled:
		game.chain+=1
		game.chain_timer=3.0
	if bonus:ComboEnergy.melee_attack(self,attack_ticket,5.0*melee_range_multiplier(),cross)

func take_hit(amount: float, direction: Vector3, projectile: bool=false):
	if character_id==17 and projectile and active_ability!=null and active_ability.blocks_projectile(direction):return
	if sky_strike.active or forward_dash.immunity_left>0 or invuln>0 or melee_contact_guarded() or hp<=0 or game.tuning.invincible or (active_ability!=null and active_ability.protects_player()): return
	if character_id==13:
		amount=active_ability.filter_damage(amount,direction,projectile)
		if amount<=0:return
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
	play_sound("death" if character_id in [16,17] and hp<=0 else "hurt")
	if hp<=0:
		if character_id in [16,17] and active_ability!=null:active_ability.die()
		game.defeat()

func _physics_process(delta):
	var original_pipe_tick:Dictionary={}
	if not game.playing or game.paused or game.transitioning or hp<=0: return
	melee_assist.tick(self,delta)
	if game.siege_building():
		cancel_charge(true);attack_left=0;queued=false;quick_attacks.stop_coins()
	if game.rogue_battle_mode:game.rogue_view.update_aim()
	auto_lock_refresh=maxf(0,auto_lock_refresh-delta)
	if auto_attack_enabled:auto_aim_target()
	weapon_controls.tick(delta)
	auto_attack_clock=maxf(0,auto_attack_clock-delta*attack_speed_multiplier())
	if auto_attack_running() and auto_attack_clock<=0 and not weapon_controls.charging and not (character_id==1 and weapon_slot==2 and surge_left>0):
		if character_id==1 and attack_left<=0 and not quick_attacks.active and quick_attacks.pending.is_empty() and not chain_pipe_combat.active:
			quick_attacks.request_mouse(false)
			auto_attack_clock=maxf(.12,attack_duration)
		elif character_id==2 and musashi.available() and not musashi.heavy_queued:
			musashi.primary_attack()
			auto_attack_clock=maxf(.12,attack_duration)
	attack_chain.tick(delta,attack_left>0 or sky_strike.active or forward_dash.active or (active_ability!=null and active_ability.blocks_movement()))
	if not ai_controlled and attack_chain.milestone>attack_chain.announced_milestone:
		attack_chain.announced_milestone=attack_chain.milestone
		var title={25:"HEATED",50:"BLAZING",100:"UNLEASHED"}[attack_chain.milestone]
		game.toast("%d LINKS · %s" % [attack_chain.milestone,title])
		game.burst(global_position+Vector3.UP,Color("ff6680"),12,1.2)
		play_sound("spark",.5)
	forward_dash.immunity_left=maxf(0,forward_dash.immunity_left-delta)
	for kind in powerups:powerups[kind]=maxf(0,powerups[kind]-delta)
	if powerups.attack_speed<=0:attack_speed_stacks=0
	if is_rogue_character():
		active_ability.physics_step(delta)
		return
	tick_combat_aim(delta)
	var attack_delta=delta*attack_speed_multiplier()
	if surge_left>0:
		surge_left=maxf(0,surge_left-delta)
		if surge_left==0:end_surge()
	if sky_strike.active:
		sky_strike.tick(delta);constrain_forest_bounds();return
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
	if character_id==13:
		_physics_musashi(delta)
		return
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
	var input=Vector2(ai_move.x,ai_move.z) if ai_controlled else (smoke_move if smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back"))
	if character_id==2 and musashi.is_casting_meteors():input=Vector2.ZERO
	var yaw=0.0 if ai_controlled else game.camera_rig.yaw
	var dir=Vector3(input.x,0,input.y).rotated(Vector3.UP,yaw)
	var boosting=not ai_controlled and Input.is_action_pressed("sprint")
	var walking=not ai_controlled and Input.is_action_pressed("walk_modifier")
	var lifting=can_fly() and not ai_controlled and Input.is_action_pressed("jump")
	flying=can_fly() and (lifting or not is_on_floor())
	if flying:jump_buffer=0;jump_windup=0;air_turn=0;reset_wall_jump()
	var speed=combat_tuning("sprint_speed") if boosting else combat_tuning("walk_speed")
	var response_speed=speed*movement_multiplier()
	if walking: speed=minf(speed,2.2)
	if character_id==13:
		if active_ability.guarding():speed=minf(speed,2.16)
		elif active_ability.mode in ["rotation","counter"]:speed=0
	speed*=movement_multiplier()
	if flying:speed=((12.0 if boosting else 7.0) if character_id==15 else (64.0 if boosting else 36.0))*progression.movement_multiplier()
	var forest_melee=game.has_method("forest_enemy_visible") and character_id==1 and weapon_slot==1
	if forest_melee and attack_left>0 and not hit_done:
		var angle=melee_assist.steer(self,atan2(facing.x,facing.z),delta)
		facing=Vector3(sin(angle),0,cos(angle))
	if attack_left>0 and not forest_melee:
		if uses_rogue_pipe_profile():
			# Rogue slows only the windup, leaving recovery free to reposition.
			if attack_duration-attack_left<rogue_pipe_combo.CONTACT_TIME:speed*=0.5
		else:speed*=0.42
	var accel=GroundResponse.acceleration(Vector3(velocity.x,0,velocity.z),dir,response_speed) if is_on_floor() else (40.0 if jumps_used>=2 else 24.0)*movement_multiplier()
	var strike_planted=_grounded_pipe_plant(attack_delta)
	if is_on_floor() and (attack_left>0 or attack_motion_pending or velocity.y>0) and (not forest_melee or velocity.y>0):
		# Pipe lunges and the takeoff tick of a hit reaction share this velocity.
		# Preserve their authored travel while ordinary grounded control is quicker.
		var reversing=dir.length()>.1 and Vector3(velocity.x,0,velocity.z).normalized().dot(dir.normalized())<-.45
		accel=(58.0 if reversing else (48.0 if dir.length()<.1 else 38.0))*movement_multiplier()
	if flying:accel=90.0*progression.movement_multiplier()
	if forward_dash.active:
		attack_motion_pending=false
		var dash_speed=GoemonDash.SPEED*forward_dash.tempo*minf(1.0,forward_dash.remaining/delta)
		velocity.x=forward_dash.direction.x*dash_speed
		velocity.z=forward_dash.direction.z*dash_speed
	elif dodge_time>0:
		attack_motion_pending=false
		velocity.x=facing.x*23
		velocity.z=facing.z*23
	else:
		# Ease steering back in after push-off, even with the cloak's 3x acceleration.
		if wall_jump_recovery>0:
			accel=minf(accel,24.0)*lerpf(0.08,1.0,smoothstep(0,WALL_JUMP_RECOVERY,WALL_JUMP_RECOVERY-wall_jump_recovery))
		var horizontal_velocity=Vector2(velocity.x,velocity.z).move_toward(Vector2(dir.x,dir.z)*speed,accel*delta)
		velocity.x=horizontal_velocity.x
		velocity.z=horizontal_velocity.y
		if forest_melee and attack_left>0 and not hit_done and not strike_planted:
			var assist_motion=melee_assist.motion(self,delta)
			# Keep the bounded step separate from stored locomotion velocity;
			# otherwise each tick adds it again and the hero coasts past the budget.
			if not assist_motion.is_zero_approx():move_and_collide(assist_motion*delta)
		if attack_left<=0 and horizontal_velocity.distance_to(Vector2(dir.x,dir.z)*speed)<.001:
			attack_motion_pending=false
	if character_id==13 and active_ability.guarding():pass
	elif is_master_chief():
		facing=Vector3.FORWARD.rotated(Vector3.UP,yaw)
	elif combat_aiming() and (character_id==2 or weapon_slot==2 or attack_left<=0):
		facing=combat_attack_direction()
	elif not forward_dash.active and not chain_pipe_combat.active and dodge_time<=0 and wall_jump_recovery<=0 and dir.length()>0.1 and (attack_left<=0 or (jumps_used>=2 and not game.camera_combat() and not game.rogue_battle_mode)):
		# Free movement turns into camera-relative travel in every direction.
		# Attacks and committed abilities keep their existing aim.
		facing=dir.normalized()
	model.rotation.y=lerp_angle(model.rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*(24 if attack_left>0 else (GroundResponse.TURN_RESPONSE if is_on_floor() else 14))))
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
			velocity.y=combat_tuning("second_jump_speed")*progression.jump_velocity_multiplier()
			jump_buffer=0
			air_turn=0.42
			if dir.length()>0.1:
				facing=dir.normalized()
				var air_speed=maxf(10.2*movement_multiplier(),Vector2(velocity.x,velocity.z).length())
				velocity.x=dir.x*air_speed
				velocity.z=dir.z*air_speed
			game.burst(global_position,Color("a6eff2"),14)
			play_sound("jump")
	model.locomotion.jump_compression=clampf(jump_windup/0.035,0,1)
	if jump_windup>0:
		jump_windup=maxf(0,jump_windup-delta)
		if jump_windup<=0:
			jumps_used=1
			velocity.y=combat_tuning("jump_speed")*progression.jump_velocity_multiplier()
			coyote=0
			game.burst(global_position,Color("e8dab0"),7)
			play_sound("jump")
	if character_id==16 and active_ability!=null and active_ability.controls_vertical_motion():
		velocity.y=active_ability.vertical_velocity(delta)
	elif character_id==15 and active_ability!=null and active_ability.bomb_controls_flight():
		velocity.y=active_ability.bomb_vertical_velocity(delta,lifting,boosting)
	elif flying:
		velocity.y=move_toward(velocity.y,((8.0 if boosting else 5.0) if lifting else -4.0) if character_id==15 else ((32.0 if boosting else 18.0) if lifting else -10.0),40.0*delta if character_id==15 else 60.0*delta)
	elif not is_on_floor(): velocity.y=maxf(velocity.y-30*delta,-55.0) if game.descent_mode else velocity.y-30*delta
	if character_id==1 and weapon_slot!=3 and attack_left>0:
		var original_from=attack_duration-attack_left
		var previous_progress=1-attack_left/attack_duration
		attack_left=maxf(0,attack_left-attack_delta)
		var progress=1-attack_left/attack_duration
		var rogue_pipe=uses_original_goemon_attack() or uses_rogue_pipe_profile()
		var contact_phase=attack_contact_phase()
		if not swing_played and (progress>=contact_phase if rogue_pipe else progress>contact_phase-0.13):
			play_swing_sound()
		if not rogue_pipe and not combo_step_done and progress>0.18 and weapon_slot==1 and not attack_heavy:
			combo_step_done=true
			velocity+=facing*(4.2 if combo==1 else (3.0 if combo==2 else 5.4))
		if uses_original_goemon_attack():
			original_pipe_tick={"from":original_from,"until":attack_duration-attack_left}
		if not uses_original_goemon_attack() and progress>=contact_phase and previous_progress<contact_phase+(0.0 if rogue_pipe else (PipeCombo.ACTIVE[combo-1] if weapon_slot==1 and not attack_heavy else 0.16)):
			if not hit_done:
				if weapon_slot==1 and not rogue_pipe: velocity+=facing*(4.5 if attack_heavy else 2.5)
				strike()
			elif weapon_slot==1: strike()
		if attack_left<=0 and not uses_original_goemon_attack():
			if heavy_buffer>0:
				heavy_buffer=0
				start_attack(true)
			elif weapon_slot==1 and not attack_heavy and combo<3 and not game.rogue_battle_mode: start_attack(false,combo+1)
	if character_id==1:quick_attacks.tick()
	# An energized follow-up may start directly at contact above. Recheck its
	# clock before movement, while retaining crossings of the previous stroke.
	if (strike_planted or _grounded_pipe_plant(0)) and is_on_floor() and velocity.y<=0 and jump_windup<=0 and weapon_slot==1 and dodge_time<=0 and not forward_dash.active and not chain_pipe_combat.active:
		velocity.x=0;velocity.z=0
	last_vertical=velocity.y
	# Step across tiny risers and deck joints without losing momentum.
	if is_on_floor() and dir.length()>0.1:
		var motion=Vector3(velocity.x,0,velocity.z)*delta
		if test_move(global_transform,motion):
			var raised=global_transform
			raised.origin.y+=0.32
			if not test_move(raised,motion): position.y+=0.32
	if character_id in [14,15,16,17] and active_ability!=null:
		var authored_motion: Vector3=active_ability.ground_attack_velocity()
		if authored_motion!=Vector3.INF:
			velocity.x=authored_motion.x;velocity.z=authored_motion.z
			if active_ability.mode=="smoke_assault":velocity.y=authored_motion.y
	var before_move=global_position
	move_and_slide()
	remember_wall_contact()
	forward_dash.after_move(before_move,delta)
	model.locomotion_velocity=(global_position-before_move)/maxf(delta,0.0001)
	if is_on_floor() and not was_floor and last_vertical<-5:
		model.landing=minf(1,abs(last_vertical)/16)
		if not ai_controlled:game.camera_rig.kick(Vector3.DOWN,0.035+model.landing*0.045)
		game.burst(global_position,Color("e7d3a3"),10)
		play_sound("land")
	was_floor=is_on_floor()
	var horizontal=Vector2(velocity.x,velocity.z).length()
	model.locomotion.free_feet=air_turn>0 or (attack_charged and attack_left>0 and weapon_slot==1)
	# Share the jump silhouette at both boundaries of the existing midair turn.
	# Use the same post-tick progress as the body rotation below.
	if model.locomotion.get("reference_jump_flip")!=null:
		model.locomotion.reference_jump_flip=clampf(1-maxf(0,air_turn-delta)/.42,0,1) if air_turn>0 else -1.0
	model.charge_requested=false
	model.charge_release=1.0-attack_left/attack_duration if attack_charged and attack_left>0 else -1.0
	model.charge_slot=weapon_slot
	model.pipe_combo_active=character_id==1 and weapon_slot==1 and not attack_heavy and attack_left>0
	model.rogue_pipe_combo_active=uses_rogue_pipe_profile() and attack_left>0
	model.wide_swing_active=wide_swing and attack_left>0
	if character_id==1:model.pipe_visual_scale=HeroModel.WeaponProportions.SCALE*combat_tuning("pipe_range")/3.5*range_multiplier()*melee_reach_setting()/maxf(.01,growth_multiplier())
	model.animate(delta,horizontal,is_on_floor(),velocity.y,maxf(.000001,attack_left/attack_duration) if not original_pipe_tick.is_empty() else attack_left/attack_duration,attack_heavy,combo,dodge_time>0 or forward_dash.active)
	flight_lean=lerpf(flight_lean,(-.28 if boosting else -.18) if flying else 0.0,1-exp(-delta*9))
	if character_id==1:model.body.rotation.x+=flight_lean
	air_turn=maxf(0,air_turn-delta)
	if air_turn>0 and character_id not in [13,14,15,16,17,18]:
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
	model.coin.scale=Vector3.ONE*0.78*HeroModel.WeaponProportions.SCALE*(combat_tuning("surge_coin_size") if surge_left>0 else 1.0)
	if character_id in [16,17] and active_ability!=null:
		model.sync_skeleton()
		active_ability.tick(delta,true)
	if not original_pipe_tick.is_empty() and uses_original_goemon_attack():
		original_pipe_combat.tick(original_pipe_tick.from,original_pipe_tick.until)
		if attack_left<=0:
			if heavy_buffer>0:
				heavy_buffer=0;start_attack(true)
			elif not attack_heavy and combo<3 and (not game.rogue_battle_mode or (quick_attacks.active and quick_attacks.action==1)):start_attack(false,combo+1)
	model.visible=not (invuln>0 and int(invuln*20)%2==0) and not (is_master_chief() and is_instance_valid(game.camera_rig) and game.camera_rig.first_person_mode)
	if model.locomotion.step_events!=last_foot_events:
		last_foot_events=model.locomotion.step_events
		if is_on_floor() and horizontal>(.25 if character_id==17 else 1.0):
			game.burst(global_position,Color("e0d2a4"),2,0.55)
			play_sound("step",0.22)
	trail_time-=delta
	if horizontal>14 and trail_time<=0:
		trail_time=0.065
		game.wind(global_position+Vector3(0,0.8,0),-facing)
	_finish_movement_bounds()
	if character_id==2:musashi.after_pose()

func _physics_musashi(delta:float):
	# Keep source speed, acceleration, jump cut and L-Belt double jump isolated
	# from the shared cape, coyote, wall-hop, sprint and progression modifiers.
	invuln=maxf(0,invuln-delta)
	dodge_time=maxf(0,dodge_time-delta);dodge_cooldown=maxf(0,dodge_cooldown-delta)
	var input=Vector2(ai_move.x,ai_move.z) if ai_controlled else (smoke_move if smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back"))
	var direction=Vector3(input.x,0,input.y).rotated(Vector3.UP,0.0 if ai_controlled else game.camera_rig.yaw)
	var guard=active_ability.guarding()
	if guard:active_ability.locomotion.facing=facing
	if active_ability.is_attacking() and is_on_floor() and not active_ability.controls_motion():
		direction=Vector3.ZERO;active_ability.locomotion.source_speed=0;active_ability.locomotion.state="idle"
	if active_ability.mode in ["rotation","counter"]:
		direction=Vector3.ZERO;active_ability.locomotion.discard_jump_input()
	var jump_requested=jump_buffer>0;jump_buffer=0;jump_windup=0;air_turn=0
	var before=global_position;var grounded=is_on_floor();var vertical_before=velocity.y
	active_ability.locomotion.physics_step(delta,direction,jump_requested,not ai_controlled and Input.is_action_pressed("jump"),not ai_controlled and Input.is_action_pressed("walk_modifier"),guard)
	if not active_ability.is_attacking() and not guard:facing=active_ability.locomotion.facing
	model.rotation.y=atan2(-facing.x,-facing.z)
	model.native_motion=true
	model.locomotion_velocity=(global_position-before)/maxf(delta,.000001)
	if is_on_floor() and not grounded and vertical_before<0:play_sound("land")
	model.animate(delta,Vector2(velocity.x,velocity.z).length(),is_on_floor(),velocity.y,attack_left/attack_duration,attack_heavy,combo,false)
	model.visible=not (invuln>0 and int(invuln*20)%2==0)
	was_floor=is_on_floor()
	_finish_movement_bounds()

func _finish_movement_bounds():
	if constrain_forest_bounds():return
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
		velocity=Vector3.ZERO;jumps_used=0;reset_wall_jump()
		if character_id==13:model.locomotion.reset()
		game.camera_rig.reset_follow()
		game.toast("Returned to the last sanctuary · −10 vitality")

func constrain_forest_bounds()->bool:
	if not game.has_method("forest_point_visible"):return false
	var bounds=game.world.playable_bounds.grow(-2)
	var edge_x=clampf(global_position.x,bounds.position.x,bounds.end.x)
	var edge_z=clampf(global_position.z,bounds.position.y,bounds.end.y)
	if edge_x!=global_position.x:global_position.x=edge_x;velocity.x=0
	if edge_z!=global_position.z:global_position.z=edge_z;velocity.z=0
	if global_position.y< -5:
		global_position.y=.15;velocity=Vector3.ZERO;jumps_used=0;reset_wall_jump();game.camera_rig.reset_follow()
		if character_id==13:model.locomotion.reset()
	return true

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
	velocity=horizontal+Vector3.UP*combat_tuning("second_jump_speed")*progression.jump_velocity_multiplier()
	facing=horizontal.normalized()
	jump_buffer=0;coyote=0;air_turn=0
	# Wall hops work after all air jumps are spent, but never refill their budget.
	jumps_used=maxi(1,jumps_used)
	wall_jump_grace=0
	wall_jump_recovery=WALL_JUMP_RECOVERY
	if model.locomotion is HeroLocomotion:model.locomotion.air_age=0
	game.burst(global_position-wall_jump_normal*0.38+Vector3.UP*0.7,Color("e7d3a3"),7)
	play_sound("land")

func select_weapon(slot: int):
	if is_master_chief():master_chief_combat.select_slot(slot);return
	if slot not in [1,2,3]:return
	combat_aim_left=0
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
	if weapon_controls!=null:weapon_controls.cancel()
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

func character_size_multiplier()->float:
	return Proportions.MUSASHI_SIZE if character_id==13 else 1.0

func contact_size_multiplier()->float:
	return character_size_multiplier()*growth_multiplier()

func _fit_character_capsule():
	if not is_instance_valid(body_shape):return
	var size=character_size_multiplier()
	body_shape.shape.radius=.38*size
	body_shape.shape.height=1.85*size
	body_shape.position.y=.95*size

func growth_multiplier()->float:return minf(MAX_GROWTH,1.0+buildings_broken*GROWTH_PER_BUILDING)

func grow_from_building():
	buildings_broken+=1
	scale=Vector3.ONE*growth_multiplier()
	game.toast("BUILDING BROKEN · Size and reach ×%.2f" % growth_multiplier())

func range_multiplier()->float:
	return growth_multiplier()*(combat_tuning("surge_range") if surge_left>0 else 1.0)*pickup_multiplier("range")

func melee_range_multiplier()->float:
	return range_multiplier()*melee_reach_setting()*(combat_tuning("surge_range") if attack_charged and surge_left<=0 else 1.0)

func melee_reach_setting()->float:
	return combat_tuning("melee_reach")

func attack_reach_multiplier()->float:
	var basic = not attack_heavy and not attack_charged and not wide_swing
	return melee_range_multiplier() * (BASIC_ATTACK_RANGE_MULTIPLIER if basic else 1.0)

func melee_contact_multiplier()->float:
	return MELEE_CONTACT_MULTIPLIER if game.has_method("forest_enemy_visible") else 1.0

func attack_contact_phase()->float:
	if uses_original_goemon_attack():return OriginalGoemon.contact_phase(3 if attack_heavy else combo)
	if character_id==1 and weapon_slot==2:return OriginalGoemon.cue_time(original_coin_action,OriginalGoemon.COIN_RELEASE_FRAME)/maxf(.001,attack_duration)
	if uses_rogue_pipe_profile():return rogue_pipe_combo.contact_phase(combo)
	if pipe_contact_phase>=0:return pipe_contact_phase
	return .47 if attack_heavy else (PipeCombo.CONTACT[clampi(combo-1,0,2)] if weapon_slot==1 else .36)

func melee_contact_guarded()->bool:
	return character_id==1 and weapon_slot==1 and attack_left>0 and pipe_contact_phase>=0 and MeleeResponse.contact_guard(attack_duration-attack_left,attack_duration*pipe_contact_phase)

func _grounded_pipe_plant(step: float)->bool:
	if not game.has_method("forest_enemy_visible") or character_id!=1 or weapon_slot!=1 or attack_left<=0:return false
	if not is_on_floor() or velocity.y>0 or jump_buffer>0 or jump_windup>0 or dodge_time>0 or forward_dash.active or chain_pipe_combat.active:return false
	var contact=attack_duration*attack_contact_phase()
	return GroundResponse.strike_planted(attack_duration-attack_left,contact,attack_duration,step)

func melee_strike_reach()->float:
	if character_id in [16,17] and active_ability!=null:return active_ability.melee_reach()
	if character_id==15:return 2.9*preload("res://scripts/character_proportions.gd").BEN_MODEL_SCALE*growth_multiplier()*pickup_multiplier("range")*melee_reach_setting()
	if character_id==13:return (2.1 if attack_heavy else 1.8)*contact_size_multiplier()*pickup_multiplier("range")*melee_reach_setting()
	var reach=HeroModel.WeaponProportions.SCALE*combat_tuning("pipe_range")*(1.65 if attack_charged else (1.26 if attack_heavy else 1.0))*attack_reach_multiplier()
	if not attack_charged:
		reach=minf(reach,model.visible_pipe_reach()+.12*growth_multiplier())
	return reach*melee_contact_multiplier()

func emit_robe_coins(radial: bool=false):
	if character_id!=1 or not scarf_equipped:return
	game.throw_robe_coins(facing,radial,weapon_slot==2)

func movement_multiplier()->float:
	if is_master_chief():return progression.movement_multiplier()
	return progression.movement_multiplier()*(3.0 if scarf_equipped else 1.0)

func maximum_jumps()->int:
	if character_id==13:return 2
	if is_master_chief():return 1
	if scarf_equipped:return 4
	if character_id==8:return 1
	return 2

func can_fly()->bool:return not is_master_chief() and (character_id==15 or (gold_cloak and scarf_equipped))

func set_gold_cloak(value: bool):
	set_scarf_equipped(value)
	gold_cloak=value
	model.set_cloak(scarf_equipped,gold_cloak)
	game.toast("GOLD CLOAK · Hold Space to ascend · Shift to boost · Release to descend" if value else "Gold cloak removed")

func set_scarf_equipped(value: bool):
	gold_cloak=false;flying=false
	scarf_equipped=value
	model.set_cloak(value,false)
	# Remove excess momentum immediately when taking the scarf off.
	if not value:
		air_turn=0
		var speed_limit=combat_tuning("sprint_speed") if Input.is_action_pressed("sprint") else combat_tuning("walk_speed")
		speed_limit*=movement_multiplier()
		var horizontal=Vector2(velocity.x,velocity.z).limit_length(speed_limit)
		velocity.x=horizontal.x;velocity.z=horizontal.y
		if is_rogue_character():active_ability.locomotion_velocity=active_ability.locomotion_velocity.limit_length(speed_limit)
	game.toast("RED CAPE · 3× movement · Four jumps" if value else "Cape removed · Normal movement")

func activate_surge():
	if surge_left>0 and not attack_chain.unleashed(): return
	surge_left=combat_tuning("surge_duration")
	model.set_surge(true)
	if is_instance_valid(model.chain_pipe):model.chain_pipe.powered=true
	aura.visible=character_id!=1
	if character_id!=1:game.burst(global_position+Vector3.UP,Color("ffe69b"),24)
	var audio_ticket=attack_chain.make_ticket("surge")
	audio_ticket["move_audio"]=game.move_audio.begin(self,"surge","surge")
	play_sound("spark",1.0,audio_ticket)
	game.toast("GOLDEN GOEMON · Hold 2 to charge ryo, release to throw" if character_id==1 else "GOLDEN SURGE · Wind spin / Giant toss / Explosive chain + Fire sweep")

func end_surge():
	if weapon_controls!=null:weapon_controls.cancel()
	surge_left=0
	model.set_surge(false)
	if is_instance_valid(model.chain_pipe):model.chain_pipe.powered=false
	aura.hide()

func select_character(id: int):
	if ai_controlled and id==18:return
	if id==character_id:
		if not ai_controlled and game.rogue_roster_mode and id in RogueRoster.PLAYABLE_IDS:game.selected_rogue_id=id
		return
	if not ROSTER.has(id) and not (game.rogue_roster_mode and RogueRoster.is_rogue(id)):return
	combat_aim_left=0
	reset_auto_attack()
	melee_assist.reset()
	var health_fraction=hp/maxf(1.0,max_hp)
	quick_attacks.stop_coins()
	cancel_charge()
	if surge_left>0:end_surge()
	if character_abilities.has(character_id):character_abilities[character_id].active=false
	var rotation_before=model.rotation
	model.hide();model.set_process(false)
	attack_left=0;attack_motion_pending=false;attack_charged=false;heavy_buffer=0;combo=0;queued=false;impact_pause=0;air_turn=0
	ensure_character(id)
	character_id=id;model=character_models[id];model.rotation=rotation_before;model.show();model.set_process(true)
	_fit_character_capsule()
	model.set_cloak(scarf_equipped,gold_cloak)
	if id==2:
		var horizontal=Vector2(velocity.x,velocity.z).limit_length(combat_tuning("sprint_speed")*movement_multiplier())
		velocity.x=horizontal.x;velocity.z=horizontal.y
	active_ability=character_abilities.get(id)
	if active_ability!=null:
		active_ability.active=true;active_ability.cancel()
		if id==13:active_ability.locomotion.reset();active_ability.locomotion.facing=facing
		if id==2:musashi=active_ability
	refresh_max_health()
	hp=max_hp*health_fraction
	last_foot_events=model.locomotion.step_events
	if not ai_controlled and game.rogue_roster_mode and id in RogueRoster.PLAYABLE_IDS:game.selected_rogue_id=id
	if ai_controlled:return
	if is_instance_valid(game.camera_rig):game.camera_rig.sync_character_view()
	if not game.character_control_hints:
		game.toast(RogueRoster.name_for(id) if is_rogue_character() else ROSTER[id].name)
	elif id in [14,15]:
		game.toast("Ed · Hold LMB Beam · RMB Fireballs · E Smoke Assault · C Evade" if id==14 else "Ben · LMB Polearm · Hold RMB Bombs · Tap E Stars / Hold E Axes · Hold Space Fly · C Evade")
	elif id==18:
		game.toast("Master Chief · 1 Rockets · 2 Pistol · 3 Shotgun · 4 Assault rifle · Hold LMB Fire · Infinite ammo · Q Fighters")
	elif id==17:
		game.toast("Yae · LMB Gold katana · RMB Bazooka / Hold Lock-on · Hold E Sword Shield · C Evade · Q Fighters")
	elif id==16:
		game.toast("Sasuke · LMB Gold kunai · RMB Bomb · E Ice / Hold Charge · T Hair · R Super Jump · Q Fighters")
	elif id==13:
		game.toast("Musashi · LMB Fusion · RMB Lumina · 1 Spin · 2 Mighty Strike · Space Double jump")
	elif is_rogue_character():
		game.toast(RogueRoster.name_for(id)+(" · LMB Attack · RMB / 3 Secondary · C Evade · E Utility · R Skill · Q Heroes" if game.camera_combat() else " · LMB Attack · RMB / 3 Secondary · C / E Utility · R Skill · Q Fighters"))
	elif game.rogue_roster_mode and id==1:
		game.toast("Goemon · Q Fighters · Hold LMB Combo · RMB Heavy · C Evade · E Dash · R Surge")
	else:game.toast(ROSTER[id].name+" · Q Switch character · "+("LMB Triple fireball · RMB Giant fireball · T Meteor rain · R Beam" if id==2 else ("1 Pipe combo · 2 Throw ryo · 3 Chain throw · Golden: hold 2 to charge" if id==1 else "1 Wind spin · 2 Auto coins ON/OFF · 3 Long sweep · C Evade")))

func is_master_chief()->bool:
	return character_id==18 and not ai_controlled

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
	var visual=entry.model.new()
	if id==13:visual.outfit_mask=int(game.settings.get("musashi_equipment_mask",31))
	add_child(visual);character_models[id]=visual
	if entry.has("combat"):
		var ability=entry.combat.new();ability.hero=self;ability.game=game;add_child(ability)
		character_abilities[id]=ability;visual.combat=ability
		if id==18:master_chief_combat=ability
	character_models[id].hide()
	character_models[id].set_process(false)

func pickup_multiplier(kind: String)->float:
	if powerups.get(kind,0.0)<=0:return 1.0
	if kind=="attack_speed":return 1.0+.5*maxi(1,attack_speed_stacks)
	return {"damage":1.5,"range":1.5,"attack_speed":1.5}.get(kind,1.0)
func damage_multiplier()->float:
	return (6.0 if character_id==15 else (3.0 if character_id in [1,14,16,17] else 1.0))*combat_tuning("damage_mult")*pickup_multiplier("damage")*(1.0+.1*run_upgrades.damage)
func base_attack_speed_multiplier()->float:
	return progression.attack_multiplier()*pickup_multiplier("attack_speed")*(1.0+.05*run_upgrades.tempo)
func attack_speed_multiplier()->float:
	var chain_rate=active_ability.ranger_fire_rate_multiplier() if is_rogue_character() and active_ability!=null and active_ability.class_id=="ranger" else attack_chain.multiplier()
	return base_attack_speed_multiplier()*chain_rate

func refresh_max_health(heal_growth: bool=false):
	var previous=max_hp
	max_hp=combat_tuning("max_hp")*progression.health_multiplier()*(1.0+.1*run_upgrades.vitality)
	hp=minf(max_hp,hp+(maxf(0,max_hp-previous) if heal_growth else 0.0))

func award_kill():
	if not game.playing or game.paused or game.transitioning or hp<=0:return
	if progression.award_kills()>0:
		refresh_max_health(true)
		game.toast("LEVEL %d%s · HP %d · Attack +%.1f%% · Move +%.1f%% · Jump +%.1f%%" % [progression.level," · MAX" if progression.level==progression.MAX_LEVEL else "",roundi(max_hp),(progression.attack_multiplier()-1)*100,(progression.movement_multiplier()-1)*100,(progression.jump_height_multiplier()-1)*100])
		play_sound("spark",.5)
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

# Auto intent stays separate from real mouse state and all native attack timing.
func auto_attack_running()->bool:
	if is_master_chief():return false
	if ai_controlled:return auto_attack_enabled and is_instance_valid(ai_target) and not ai_target.dead and hp>0 and game.model.phase=="wave"
	if not auto_attack_enabled or not game.camera_combat() or not game.playing or game.paused or game.transitioning or hp<=0:return false
	if game.siege_building() or Input.is_action_pressed("heavy_attack") or Input.is_action_pressed("weapon_chain"):return false
	if dodge_time>0 or impact_pause>0 or forward_dash.active or sky_strike.active:return false
	if active_ability!=null and active_ability.blocks_movement():return false
	return true

func auto_aim_origin()->Vector3:
	if character_id==2 and is_instance_valid(model):return model.hand_position("R")
	return global_position+Vector3.UP*(1.05 if is_rogue_character() else 1.25)*growth_multiplier()

func auto_aim_target(muzzle: Vector3=Vector3.INF)->Ninja:
	if ai_controlled:return ai_target if is_instance_valid(ai_target) and not ai_target.dead else null
	if not auto_attack_enabled or not game.camera_combat() or not game.playing or game.paused or game.transitioning or hp<=0:return null
	var lost=auto_lock_had_target and (not is_instance_valid(auto_lock_target) or auto_lock_target.dead or not game.camera_rig.camera.is_position_in_frustum(AttackChain.aim_point(auto_lock_target)) or (game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(auto_lock_target)))
	if auto_lock_refresh<=0 or lost:
		auto_lock_target=AttackChain.screen_target(self,auto_aim_origin(),120.0,true)
		auto_lock_refresh=.15
		auto_lock_had_target=is_instance_valid(auto_lock_target)
	if muzzle.is_finite() and is_instance_valid(auto_lock_target):
		var ray=PhysicsRayQueryParameters3D.create(muzzle,AttackChain.aim_point(auto_lock_target),1)
		ray.exclude=[get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			auto_lock_target=AttackChain.screen_target(self,muzzle,120.0,true)
			auto_lock_had_target=is_instance_valid(auto_lock_target)
	return auto_lock_target

func set_auto_attack(enabled: bool):
	auto_attack_enabled=enabled
	auto_attack_clock=0
	auto_lock_target=null;auto_lock_refresh=0;auto_lock_had_target=false
	if enabled:auto_aim_target()
	if not enabled and character_id==2 and is_instance_valid(musashi) and not Input.is_action_pressed("light_attack"):
		musashi.release_primary()
	game.toast("AUTO LOCK ON · Closest visible enemy · J to stop" if enabled else "AUTO ATTACK OFF · J to enable")

func reset_auto_attack():
	auto_lock_target=null;auto_lock_refresh=0;auto_lock_had_target=false
	auto_attack_enabled=false
	auto_attack_clock=0

func combat_attack_direction()->Vector3:
	if ai_controlled:
		var direction=ai_aim-global_position;direction.y=0
		return direction.normalized() if direction.length_squared()>.001 else facing
	return game.attack_direction()

func combat_tuning(key: String)->float:
	return game.balance_value(character_id,key) if ai_controlled else game.hero_tuning(key)

func movement_jump_available()->bool:
	return is_on_floor() or coyote>0 or jumps_used<maximum_jumps() or wall_jump_grace>0

func has_offensive_action()->bool:
	if attack_left>0 or attack_motion_pending or impact_pause>0 or primary_down or charge_elapsed>0 or heavy_buffer>0:return true
	if sky_strike.active or forward_dash.active or chain_pipe_combat.active or quick_attacks.active or not quick_attacks.pending.is_empty():return true
	return active_ability!=null and (active_ability.has_offensive_action() if is_rogue_character() else (character_id in [13,14,15,16,17,18] and active_ability.is_attacking()))

func interrupt_attack_for_movement(preserve_motion: bool=false):
	if weapon_controls!=null:weapon_controls.cancel()
	# A normal running jump retains its momentum. Cancels strip attack impulses.
	if not has_offensive_action():return
	var locked_motion=sky_strike.active or forward_dash.active
	var movement_velocity=Vector3(velocity.x,0,velocity.z)
	if is_rogue_character():
		locked_motion=active_ability.player.travel!=null or active_ability.player.dive!=null or active_ability.offensive_roll()
		movement_velocity=active_ability.locomotion_velocity
	# End unfinished offense, preserving released projectiles, buffs and cooldowns.
	melee_assist.reset();quick_attacks.cancel();rogue_controls.reset()
	var current_position=global_position
	sky_strike.cancel();global_position=current_position
	chain_pipe_combat.cancel();forward_dash.cancel()
	if active_ability!=null:
		if is_rogue_character():active_ability.interrupt_attack_for_movement()
		else:active_ability.interrupt_for_dodge()
	attack_left=0;attack_motion_pending=false;heavy_buffer=0;queued=false;combo=0;combo_window=0
	primary_down=false;charge_elapsed=0;attack_charged=false;wide_swing=false
	impact_pause=0;combat_aim_left=0
	charge_ring.hide();model.charge_requested=false
	model.pipe_combo_active=false;model.rogue_pipe_combo_active=false;model.wide_swing_active=false
	velocity.x=0;velocity.z=0
	if preserve_motion and not locked_motion:
		velocity.x=movement_velocity.x;velocity.z=movement_velocity.z
		if is_rogue_character():active_ability.locomotion_velocity=movement_velocity
