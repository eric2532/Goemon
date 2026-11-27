class_name Hero
extends CharacterBody3D

# Shared character attacks accept explicit intent from native army copies.
var ai_controlled=false
var mirror_copy=false
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
var warm_legacy_roster=true
var musashi: MusashiCombat
var body_shape: CollisionShape3D
var spell_loadout: Node
var accessory_bonuses:Dictionary={}
var jump_style=preload("res://scripts/jump_style.gd").new(self)
var active_ability: Node
var master_chief_combat: Node
const BASIC_ATTACK_RANGE_MULTIPLIER = 1.0
const MELEE_CONTACT_MULTIPLIER = 1.12
const CROSSGATE_MELEE_REACH = 1.25
const CROSSGATE_MELEE_SPEED = 1.2
const ATTACK_SPEED_CAP = 3.0
const BASE_MAGIC_DAMAGE = 50.0
const GUARD_REPLY_WINDOW = .9
const CROSSGATE_FIST_REACH = 1.25
const CROSSGATE_FIST_SPEED = 1.25
const BEN_DESCENT_SPEED=12.0
const BEN_FLIGHT_ASCENT_SPEED=15.0
const BEN_FLIGHT_BOOST_ASCENT_SPEED=24.0
var melee_assist=preload("res://scripts/melee_assist.gd").new()
const Proportions=preload("res://scripts/character_proportions.gd")
const OriginalGoemon=preload("res://scripts/recovered_goemon_combat_profile.gd")
static var ROSTER=with_crossgate_fighters({33:{"name":"Mountain King","character":33,"model":preload("res://scripts/warcraft_model.gd"),"combat":preload("res://scripts/mountain_king_combat.gd")},31:{"name":"Blademaster","character":31,"model":preload("res://scripts/warcraft_model.gd"),"combat":preload("res://scripts/warcraft_combat.gd")},32:{"name":"Illidan","character":32,"model":preload("res://scripts/warcraft_model.gd"),"combat":preload("res://scripts/warcraft_combat.gd")},30:{"name":"Dark Lumina 3","role":18,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/dark_lumina_3_combat.gd")},29:{"name":"Dark Lumina 2","role":17,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},28:{"name":"Kojiro","model":preload("res://scripts/kojiro_model.gd"),"combat":preload("res://scripts/kojiro_combat.gd")},1: {"name":"Goemon", "model":preload("res://scripts/recovered_goemon_model.gd")},2: {"name":"Edo", "model":preload("res://assets/characters/musashi/model/musashi_model.gd"),"combat":preload("res://assets/characters/musashi/combat/musashi_combat.gd")},13: {"name":"Musashi","model":preload("res://scripts/recovered_musashi_model.gd"),"combat":preload("res://scripts/recovered_musashi_combat.gd")},14:{"name":"Ed","model":preload("res://scripts/recovered_ed_model.gd"),"combat":preload("res://scripts/recovered_leader_combat.gd")},15:{"name":"Ben","model":preload("res://scripts/recovered_ben_model.gd"),"combat":preload("res://scripts/recovered_leader_combat.gd")},16:{"name":"Sasuke","model":preload("res://scripts/recovered_sasuke_model.gd"),"combat":preload("res://scripts/recovered_sasuke_combat.gd")},17:{"name":"Yae","model":preload("res://scripts/recovered_yae_model.gd"),"combat":preload("res://scripts/recovered_yae_combat.gd")},18:{"name":"Master Chief","model":preload("res://scripts/master_chief_model.gd"),"combat":preload("res://scripts/master_chief_combat.gd")},19:{"name":"Sonic","model":preload("res://scripts/sonic_model.gd"),"combat":preload("res://scripts/sonic_combat.gd")},20:{"name":"Red Soldier","role":0,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},21:{"name":"Blue Gunner","role":1,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},22:{"name":"Green Spearman","role":3,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},23:{"name":"Vambee","role":6,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},24:{"name":"Haya Wolf","role":9,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},25:{"name":"Vambee Torso","role":14,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},26:{"name":"Slow Guy","role":16,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")},27:{"name":"Skullpion","role":4,"model":preload("res://scripts/recovered_enemy_model.gd"),"combat":preload("res://scripts/recovered_enemy_combat.gd")}})
const RogueRoster=preload("res://scripts/rogue_roster.gd")
const GroundResponse=preload("res://scripts/ground_movement_response.gd")
var model: HeroModel
var hp=100.0
var max_hp=100.0
const BASE_MANA=50.0
const MANA_REGEN=2.0
var mana=BASE_MANA
var max_mana=BASE_MANA
var progression=preload("res://scripts/level_progression.gd").new()
var team_progression
var facing=Vector3.FORWARD
var room_ladder
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
var skullpion_poison_left=0.0
var confusion_left=0.0
var cursed_afflictions=PackedFloat32Array([0,0,0,0,0,0])
var cursed_poison_tick=0.0
var cursed_status_source=0
var cursed_status_active=false
var combat_hold_left=0.0
var combat_hold_source=-1
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
const FOOTSTEP_INTERVAL=.30
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
const FOOD_BUFF_SECONDS=600.0
const FOOD_MULTIPLIERS={"damage_mult":1.3,"max_hp":1.3,"attack_speed":1.2,"movement_speed":1.2,"jelly_damage":1.5,"jelly_magic":1.5,"jelly_speed":1.5}
const FOOD_DEFENSE_PER_STACK=20.0
var food_buffs={"damage_mult":0.0,"max_hp":0.0,"attack_speed":0.0,"movement_speed":0.0,"defense":0.0,"jelly_damage":0.0,"jelly_magic":0.0,"jelly_speed":0.0}
var double_edge_left=0.0
var double_edge_penalty=0.0
var food_buff_stacks={"damage_mult":0,"max_hp":0,"attack_speed":0,"movement_speed":0,"defense":0,"jelly_damage":0,"jelly_magic":0,"jelly_speed":0}
var smoke_mode=false
var defend_held=false
var guard_reply_left=0.0
var crossgate_attack_serial=0
var smoke_move=Vector2.ZERO
var timed_dodge

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
	timed_dodge=preload("res://scripts/forest/timed_dodge.gd").new();timed_dodge.hero=self;add_child(timed_dodge)
	spell_loadout=preload("res://scripts/spells/spell_loadout.gd").new();spell_loadout.hero=self;add_child(spell_loadout)
	original_pipe_combat=preload("res://scripts/recovered_goemon_pipe_combat.gd").new(self)
	weapon_controls=preload("res://scripts/goemon_weapon_controls.gd").new(self)
	attack_chain.hero_owner=weakref(self)
	quick_attacks=preload("res://scripts/goemon_quick_attacks.gd").new(self)
	rogue_controls=preload("res://scripts/rogue_battle_controls.gd").new(self)
	rogue_pipe_combo=preload("res://scripts/goemon_rogue_combo.gd").new();rogue_pipe_combo.hero=self;add_child(rogue_pipe_combo)
	sky_strike=SkyStrike.new(self)
	chain_pipe_combat=ChainPipeCombat.new(self)
	add_child(chain_pipe_combat)
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
	model.scale=Vector3.ONE*combat_tuning("model_scale")
	aura=SurgeAura.new()
	add_child(aura)
	aura.hide()
	charge_ring=Node3D.new();add_child(charge_ring)
	charge_ring.hide()
	max_hp=combat_tuning("max_hp")*progression.health_multiplier()*(1.0+.1*run_upgrades.vitality)
	if character_id==33 and active_ability!=null and active_ability.demon:max_hp+=500
	hp=max_hp
	# The older game modes can switch directly to these fighters during combat.
	if warm_legacy_roster:
		for id in ROSTER:
			if id>=20 or (ai_controlled and id in [18,19]):continue
			ensure_character(id)

func _setup_initial_model():
	model=ROSTER[1].model.new()
	model.skin_id=HeroSkins.valid_id(game.settings.goemon_skin)
	add_child(model)
	character_models[1]=model

static func with_crossgate_fighters(entries:Dictionary)->Dictionary:
	var visual=preload("res://scripts/crossgate_model.gd")
	var melee=preload("res://scripts/crossgate_combat.gd")
	var throwing=preload("res://scripts/maze_combat.gd")
	for id in RogueRoster.CROSSGATE:
		entries[id]={"name":RogueRoster.name_for(id),"character":id,"model":visual,
			"combat":throwing if RogueRoster.has_crossgate_throws(id) else melee}
	return entries

func _notification(what:int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(game) and is_instance_valid(model):
		if combined_power_busy():
			primary_down=false;active_ability.primary_hold_target=null
			active_ability.combined_queued=false;active_ability.combined_queue_target=null
		else:cancel_charge(true)
		reset_auto_attack()

func _input(event):
	if ai_controlled:return
	if event.is_action_released("defend"):defend_held=false
	if spell_loadout!=null:
		if event is InputEventKey and not event.pressed and spell_loadout.number_event(event):return
		spell_loadout.release_input(event)
	if weapon_controls!=null:weapon_controls.release(event)
	# Release must arrive even when a menu consumes the pointer event.
	if rogue_controls!=null:rogue_controls.release(event)
	if active_ability!=null and active_ability.has_method("release_input"):active_ability.release_input(event)

func _unhandled_input(event):
	if ai_controlled:return
	if not game.playing or game.paused or game.transitioning or hp<=0: return
	if combined_power_busy():
		if event.is_action_pressed("light_attack") and not event.is_echo():active_ability.queue_combined_primary()
		get_viewport().set_input_as_handled();return
	if event.is_action_pressed("heavy_attack") and RogueRoster.is_crossgate_fighter(character_id) and game.has_method("issue_hound_order") and game.model.phase=="wave":
		game.issue_hound_order(game.army_runtime.HoundOrder.ATTACK)
		get_viewport().set_input_as_handled();return
	if combat_hold_left>0 or timed_dodge.rescue_left>0:return
	clear_character_cooldowns()
	if event.is_action("timed_dodge",true):
		if event.is_action_pressed("timed_dodge",false,true) and not event.is_echo():
			if timed_dodge.press() and RogueRoster.is_crossgate_fighter(character_id):active_ability.primary_hold_target=null
		get_viewport().set_input_as_handled();return
	if RogueRoster.is_crossgate_fighter(character_id):
		if event.is_action("dodge"):
			get_viewport().set_input_as_handled();return
		if event.is_action_pressed("defend"):
			if not event.is_echo():
				defend_held=true
				active_ability.primary_hold_target=null
				active_ability.state.erase("next_primary_target")
				active_ability.state.erase("next_area_skill")
			get_viewport().set_input_as_handled();return
		if defend_held and not (event.is_action("jump") or event.is_action("character_toggle")):
			if spell_loadout.number_event(event):get_viewport().set_input_as_handled()
			return
	if shin_cast_planted() and event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled();return
	if RogueRoster.has_crossgate_throws(character_id) and active_ability.assassinating():return
	if event.is_action_pressed("auto_attack_toggle") and not event.is_echo():
		if game.camera_combat() and not is_master_chief():set_auto_attack(not auto_attack_enabled)
		get_viewport().set_input_as_handled();return
	if game.siege_building() and (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack") or event.is_action_pressed("weapon_pipe") or event.is_action_pressed("weapon_coin") or event.is_action_pressed("weapon_chain") or event.is_action_pressed("surge") or event.is_action_pressed("sky_strike")):return
	if jump_style.active() and event.is_action("jump"):
		if event.is_action_pressed("jump") and not event.is_echo():jump_buffer=.15
		get_viewport().set_input_as_handled();return
	if spell_loadout.number_event(event):
		get_viewport().set_input_as_handled();return
	if spell_loadout.input(event):
		get_viewport().set_input_as_handled();return
	if weapon_controls.input(event):
		get_viewport().set_input_as_handled();return
	if game.camera_combat() and event.is_action_pressed("assist"):return
	if game.rogue_battle_mode:game.rogue_view.update_aim()
	if game.rogue_roster_mode and event.is_action_pressed("character_toggle") and not event.is_echo():
		game.show_rogue_roster();get_viewport().set_input_as_handled();return
	if is_rogue_character():
		active_ability.input(event)
		return
	if character_id==19:
		if event.is_action_pressed("character_toggle") and not event.is_echo():
			var ids=RogueRoster.selection_ids().filter(func(id):return ROSTER.has(id));select_character(ids[(ids.find(character_id)+1)%ids.size()])
		else:active_ability.input(event)
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
		defend_held=false
		if movement_jump_available():
			jump_buffer=.15
		return
	if event.is_action_pressed("dodge") and not event.is_echo() and dodge_cooldown<=0:
		start_evade()
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
	if event.is_action_pressed("surge") and not event.is_echo(): activate_surge()
	if (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack")) and not event.is_echo():
		if game.rogue_battle_mode:rogue_controls.input(event)
		else:quick_attacks.request_mouse(event.is_action_pressed("heavy_attack"))
	if event.is_action_pressed("equip") and not event.is_echo():forward_dash.start()
	if event.is_action_pressed("assist"):
		soft_target=not soft_target
		game.toast("Soft targeting ON" if soft_target else "Soft targeting OFF")

func start_evade():
	if dodge_cooldown>0:return
	defend_held=false
	interrupt_attack_for_movement()
	if game.camera_combat() or game.rogue_battle_mode:facing=rogue_dodge_direction()
	attack_chain.active_ticket["move_audio"]=game.move_audio.begin(self,"evade")
	dodge_time=.28;dodge_cooldown=.75;invuln=.32;play_sound("dash",1.0,attack_chain.active_ticket)

func rogue_dodge_direction()->Vector3:
	var move=Input.get_vector("move_left","move_right","move_forward","move_back")
	if move.length_squared()>.01:return Vector3(move.x,0,move.y).rotated(Vector3.UP,game.camera_rig.yaw).normalized()
	return combat_attack_direction()

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
func play_sound(kind: String,volume: float=1.0,ticket: Dictionary={},original_override:AudioStream=null):
	if ai_controlled and not game.move_audio.ally_nearby(game,global_position):return
	if kind in ["step","musashi_step_0","musashi_step_1","dark_lumina_2_step"]:
		# Movement upgrades must not turn ground contacts into a burst of audio.
		if foot_time>.000001:return
		foot_time=FOOTSTEP_INTERVAL
	if kind=="land" and character_id==29:
		kind="dark_lumina_2_slam"
		if active_ability!=null and active_ability.is_attacking() and active_ability.action==active_ability.Dark.SLAM:active_ability.state.landing_sound=true
	game.sound(kind,volume,false,attack_ticket if ticket.is_empty() else ticket,character_id,original_override)

func play_swing_sound():
	swing_played=true
	if uses_original_goemon_attack():
		play_sound("heavy_swing" if attack_heavy or combo==3 else "swing");return
	if character_id==1 and weapon_slot==2:return # Coin preparation is sounded at entry; voice at release.
	if uses_rogue_pipe_profile():
		rogue_pipe_combo.release(combo);return
	play_sound("spin_swing" if attack_charged and weapon_slot==1 else ("heavy_swing" if attack_heavy or (weapon_slot==1 and combo==3) else "swing"))

func strike(spell_combat:Node=null):
	var musashi_attack=spell_combat!=null or character_id==13
	var sword_combat=spell_combat if spell_combat!=null else active_ability
	if spell_combat==null and uses_original_goemon_attack():
		var elapsed=attack_duration-attack_left
		original_pipe_combat.tick(elapsed,elapsed)
		return
	var first_sample=not hit_done
	if character_id==1 and weapon_slot==1:melee_assist.contact()
	var bonus=first_sample and weapon_slot==1 and attack_chain.energized()
	var cross=(wide_swing or attack_ticket.get("action","")=="spin") and attack_chain.previous=="heavy"
	hit_done=true
	if first_sample and spell_combat==null:emit_robe_coins(attack_charged and weapon_slot==1)
	if weapon_slot==2 and spell_combat==null:
		game.throw_coin(attack_heavy,attack_charged,charge_power,attack_ticket,false,self)
		return
	if not attack_charged and spell_combat==null:
		# Contact resolves against the same articulated pose shown this frame.
		model.pipe_combo_active=not attack_heavy and not wide_swing
		model.rogue_pipe_combo_active=model.pipe_combo_active and uses_rogue_pipe_profile()
		model.wide_swing_active=wide_swing
		model.pipe_visual_scale=HeroModel.WeaponProportions.SCALE*combat_tuning("pipe_range")/3.5*range_multiplier()*melee_reach_setting()/maxf(.01,growth_multiplier())
		model.animate(0,Vector2(velocity.x,velocity.z).length(),is_on_floor(),velocity.y,attack_left/attack_duration,attack_heavy,combo,false)
		model.sync_skeleton()
	var reach=(2.1 if attack_heavy else 1.8)*contact_size_multiplier()*pickup_multiplier("range")*melee_reach_setting() if spell_combat!=null else melee_strike_reach()
	if musashi_attack and sword_combat.mode in ["rotation","counter"]:
		reach*=sword_combat.SKILL_SCALE
		if spell_combat!=null:reach*=sword_combat.cast_model().rig_visual.global_basis.get_scale().x/(1.8*contact_size_multiplier())
	reach*=skill_factor(attack_ticket,"hit_area")
	var contact_size=contact_size_multiplier()
	var probe_size=contact_size if musashi_attack else 1.0
	var center=global_position+(Vector3.UP*1.1+facing*1.1)*contact_size
	if first_sample and attack_charged:
		play_sound("dash",.45)
	elif first_sample:
		if spell_combat!=null:pass
		elif uses_original_goemon_attack():pass # The recovered weapon draws the source swing.
		elif uses_rogue_pipe_profile():rogue_pipe_combo.slash(combo)
		elif character_id in [13,15,16,17]:pass # Recovered weapons draw their trail from the moving blade.
		elif wide_swing:game.combo_slash(center,facing,2,attack_reach_multiplier()*combat_tuning("pipe_range")*1.26/3.5)
		elif attack_heavy: game.slash(center,facing,true,combo,Color("ffdf83"),attack_reach_multiplier()*combat_tuning("pipe_range")/3.5)
		else: game.combo_slash(global_position+Vector3.UP*1.1*growth_multiplier(),facing,combo,reach/3.5)
	var any_hit=false
	var targets=AttackChain.enemy_candidates(game,global_position,reach+3.5*contact_size)
	for e in targets:
		if not is_instance_valid(e) or e.dead or struck_targets.has(e.get_instance_id()): continue
		var hurt=AttackChain.contact_point(e,global_position+Vector3.UP*1.1*probe_size,e.global_position)
		if musashi_attack and not sword_combat.can_hit_target(e):continue
		var dif=hurt-global_position
		var radial=musashi_attack and sword_combat.mode in ["rotation","counter"]
		var blade_contact=musashi_attack and not radial
		if blade_contact or (dif.length()<reach+e.body_radius and absf(dif.y)<3.5*contact_size and (radial or attack_charged or facing.dot(dif.normalized())>-0.12)):
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
	BreakableBuilding.hit_area(game,global_position+Vector3.UP*contact_size,reach,building_damage*damage_multiplier(),attack_ticket,facing,-1.0 if attack_charged or (musashi_attack and sword_combat.mode in ["rotation","counter"]) else -.12,struck_targets)
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

func try_kagerou_dodge(direction:Vector3)->bool:
	if hp<=0 or not RogueRoster.is_crossgate_fighter(character_id) or not active_ability.kagerou_enabled or active_ability.blocks_movement():return false
	var skill=preload("res://scripts/spells/skill_balance.gd")
	var chance=clampf(float(skill.rules_for(self,"kazi/kagerou").get("chance",1.0))+skill.modifier(self,"kazi/kagerou","chance"),0,1)
	if randf()>=chance:return false
	if model.show_kagerou_dodge(direction):play_sound("cg_kagerou_dodge")
	return true

func try_stat_dodge(direction:Vector3)->bool:
	if not RogueRoster.is_crossgate_fighter(character_id) or ai_controlled:return false
	if model.kagerou_tick>=0 and not model.kagerou_afterimages and not timed_dodge.reacting:return true
	if randf()*100>=effective_dodge_chance():return false
	model.show_kagerou_dodge(direction,false)
	return true

func take_hit(amount: float, direction: Vector3, projectile: bool=false):
	take_hit_from(amount,direction,projectile,0)

func crossgate_combo_protected()->bool:
	return RogueRoster.is_crossgate_fighter(character_id) and active_ability.combo_protected()

func combined_power_busy()->bool:
	return not ai_controlled and game.has_method("issue_hound_order") and is_instance_valid(game.army_runtime) and game.army_runtime.combined_committed

func combined_move_requested()->bool:
	return not ai_controlled and not Input.get_vector("move_left","move_right","move_forward","move_back").is_zero_approx()

func break_combined_recovery():
	if combined_power_busy() and game.army_runtime.combined_contacted and combined_move_requested():game.army_runtime.finish_combined_power(true)

func shin_cast_planted()->bool:
	return combined_power_busy() or (RogueRoster.is_crossgate_fighter(character_id) and active_ability.shin_cast_planted())

func crossgate_guarding()->bool:
	return defend_held and not ai_controlled and RogueRoster.is_crossgate_fighter(character_id) and game.playing and not game.paused and not game.transitioning and hp>0 and is_on_floor() and dodge_time<=0 and jump_buffer<=0 and jump_windup<=0 and combat_hold_left<=0 and attack_left<=0 and active_ability.mode.is_empty() and spell_loadout.current==null

func take_hit_from(amount:float,direction:Vector3,projectile:bool,source_id:int,counter:bool=false,guard_break:bool=false,magical:bool=false,fatal:bool=false,intercepted:bool=false):
	if not intercepted and crossgate_combo_protected():return
	var blocked=not intercepted and crossgate_guarding()
	if guard_break and not blocked:return
	if not intercepted and RogueRoster.is_crossgate_fighter(character_id) and not blocked and amount>0 and hp>0 and not game.tuning.invincible:
		if dodge_time>0 or (invuln<=0 and not sky_strike.active and forward_dash.immunity_left<=0 and not melee_contact_guarded() and not active_ability.protects_player()):
			if dodge_time>0 or try_kagerou_dodge(direction) or try_stat_dodge(direction):
				if not counter:active_ability.counter_after_hit(direction,source_id,true)
				return
	if not intercepted and spell_loadout!=null:
		amount=spell_loadout.filter_damage(amount,direction,projectile)
		if amount<=0:return
	if character_id==17 and projectile and active_ability!=null and active_ability.blocks_projectile(direction):return
	if hp<=0 or game.tuning.invincible:return
	if not intercepted and (sky_strike.active or forward_dash.immunity_left>0 or invuln>0 or melee_contact_guarded() or (active_ability!=null and active_ability.protects_player())):return
	if character_id in [13,33]:
		amount=active_ability.filter_damage(amount,direction,projectile)
		if amount<=0:return
	if not intercepted and is_rogue_character():
		amount=active_ability.filter_damage(amount,direction,projectile)
		if amount<=0:return
	var previous_hp=hp
	if blocked:
		var travel=Vector3(direction.x,0,direction.z)
		if not travel.is_zero_approx():facing=-travel.normalized()
		if not guard_break:amount*=.25
	var defense_factor=1.0-double_edge_penalty if double_edge_left>0 else 1.0
	amount*=team_progression.stat_incoming_multiplier(extra_defense(magical),defense_factor,magical) if uses_level_stats() else 100.0/(100.0+extra_defense(magical)*defense_factor)
	var remaining_hp=0.0 if fatal else maxf(0,hp-amount*game.tuning.enemy_damage)
	var retaliating=not counter and not guard_break and RogueRoster.is_crossgate_fighter(character_id) and remaining_hp>0 and remaining_hp<previous_hp and active_ability.counter_after_hit(direction,source_id)
	if not retaliating and not blocked:
		if spell_loadout!=null:spell_loadout.interrupt()
		if active_ability!=null:active_ability.hit()
	hp=remaining_hp
	if hp<previous_hp:
		if cursed_afflictions[1]>0:
			cursed_afflictions[1]=0
			if combat_hold_source==-3:
				combat_hold_left=cursed_afflictions[2]
				if combat_hold_left<=0:combat_hold_source=-1
		guard_reply_left=GUARD_REPLY_WINDOW if blocked and not guard_break and hp>0 else 0.0
		if guard_break:
			defend_held=false
			if hp>0:combat_hold_source=source_id;combat_hold_left=.3
	if not counter and not guard_break and hp>0 and hp<previous_hp and RogueRoster.is_crossgate_fighter(character_id) and not retaliating:active_ability.counter_after_hit(direction,source_id,true)
	invuln=0.0 if retaliating else 0.85
	if not retaliating and not blocked:velocity+=direction*7+Vector3.UP*3
	if is_rogue_character():active_ability.receive_knockback(direction)
	game.camera_rig.impulse=0.18
	if hp<previous_hp and is_instance_valid(game.get("crowd")) and is_instance_valid(game.crowd.army):
		game.crowd.army.presentation.player_hit_feedback(self,previous_hp-hp)
	else:game.burst(global_position+Vector3.UP,Color("ff6a55"),12)
	if blocked and not guard_break and hp>0:
		game.crowd.army.presentation.block_feedback(global_position+Vector3.UP*model.standing_height()*.55)
	elif not guard_break or hp<=0:play_sound("wc_demon_death" if character_id==32 and hp<=0 and active_ability.demon else "death" if character_id in [16,17,28,29,30,31,32,33] and hp<=0 else "hurt",1.8)
	if hp<=0:
		if (character_id in [16,17,28,29,31,32,33] or RogueRoster.is_crossgate_fighter(character_id)) and active_ability!=null:active_ability.die()
		game.defeat()

func _physics_process(delta):
	var original_pipe_tick:Dictionary={}
	if not game.playing or game.paused or game.transitioning or hp<=0: return
	guard_reply_left=maxf(0.0,guard_reply_left-delta)
	confusion_left=maxf(0.0,confusion_left-delta)
	if cursed_status_active:tick_cursed_afflictions(delta)
	timed_dodge.tick(delta)
	if timed_dodge.rescue_left>0:
		timed_dodge.tick_rescue(delta)
		return
	double_edge_left=maxf(0.0,double_edge_left-delta)
	tick_food_buffs(delta)
	if uses_level_stats():hp=minf(max_hp,hp+health_regeneration()*delta)
	if uses_mana():tick_mana(delta)
	if is_instance_valid(room_ladder) and room_ladder.step(self,delta):return
	if RogueRoster.is_crossgate_fighter(character_id):
		model.tick_kagerou_dodge(delta)
		active_ability.tick_shin_counter(delta)
		active_ability.tick_primary_combo(delta)
	foot_time=maxf(0,foot_time-delta)
	clear_character_cooldowns()
	if jump_style.active():
		jump_buffer=maxf(0,jump_buffer-delta);jump_style.update_flight()
	if combat_hold_left>0:
		combat_hold_left=maxf(0,combat_hold_left-delta);invuln=maxf(0,invuln-delta)
		velocity.x=0;velocity.z=0
		if not is_on_floor():velocity.y-=30*delta
		move_and_slide();model.animate(delta,0,is_on_floor(),velocity.y,0,false,0,false)
		if combat_hold_left<=0:combat_hold_source=-1
		return
	skullpion_poison_left=maxf(0,skullpion_poison_left-delta)
	melee_assist.tick(self,delta)
	if game.siege_building():
		cancel_charge(true);attack_left=0;queued=false;quick_attacks.stop_coins()
	if spell_loadout.tick(delta):return
	if game.rogue_battle_mode:game.rogue_view.update_aim()
	auto_lock_refresh=maxf(0,auto_lock_refresh-delta)
	if auto_attack_enabled:auto_aim_target()
	weapon_controls.tick(delta)
	auto_attack_clock=maxf(0,auto_attack_clock-delta*attack_speed_multiplier())
	if auto_attack_running() and auto_attack_clock<=0 and not weapon_controls.charging:
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
		_update_footsteps(Vector2(velocity.x,velocity.z).length())
		return
	if character_id==19:
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
		break_combined_recovery()
		active_ability.tick(delta,false)
		break_combined_recovery()
		if active_ability.blocks_movement():return
	if shin_cast_planted():
		jump_buffer=0;jump_windup=0
		invuln=maxf(0,invuln-delta)
		velocity=Vector3.ZERO if is_on_floor() else Vector3(0,minf(0,velocity.y)-30*delta,0)
		move_and_slide()
		model.locomotion_velocity=Vector3.ZERO
		model.visible=true
		model.animate(delta,0,is_on_floor(),velocity.y,0,false,0,false)
		_finish_movement_bounds()
		return
	if character_id==13:
		_physics_musashi(delta)
		return
	heavy_buffer=maxf(0,heavy_buffer-attack_delta)
	charge_ring.hide()
	invuln=maxf(0,invuln-delta)
	dodge_time=maxf(0,dodge_time-delta)
	dodge_cooldown=maxf(0,dodge_cooldown-delta)
	combo_window=maxf(0,combo_window-delta)
	if not jump_style.active():jump_buffer=maxf(0,jump_buffer-delta)
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
	if confusion_left>0:input=-input
	if cursed_afflictions[3]>0:input=input.rotated(sin(cursed_afflictions[3]*5.0)*.65)*.65
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
	if crossgate_guarding():speed=minf(speed,2.2)
	if character_id==13:
		if active_ability.guarding():speed=minf(speed,2.16)
		elif active_ability.mode in ["rotation","counter"]:speed=0
	speed*=movement_multiplier()
	if flying:speed=jump_style.flight_speed()
	var forest_melee=game.has_method("forest_enemy_visible") and character_id==1 and weapon_slot==1
	var attack_slows_movement=attack_left>0 and not (RogueRoster.is_crossgate_archer(character_id) or (RogueRoster.has_crossgate_throws(character_id) and active_ability.is_throwing_kunai()))
	if forest_melee and attack_left>0 and not hit_done:
		var angle=melee_assist.steer(self,atan2(facing.x,facing.z),delta)
		facing=Vector3(sin(angle),0,cos(angle))
	if attack_slows_movement and not forest_melee:
		if uses_rogue_pipe_profile():
			# Rogue slows only the windup, leaving recovery free to reposition.
			if attack_duration-attack_left<rogue_pipe_combo.CONTACT_TIME:speed*=0.5
		else:speed*=0.42
	var accel=GroundResponse.acceleration(Vector3(velocity.x,0,velocity.z),dir,response_speed) if is_on_floor() else (40.0 if jumps_used>=2 else 24.0)*movement_multiplier()
	var strike_planted=_grounded_pipe_plant(attack_delta)
	if is_on_floor() and (attack_slows_movement or attack_motion_pending or velocity.y>0) and (not forest_melee or velocity.y>0):
		# Pipe lunges and the takeoff tick of a hit reaction share this velocity.
		# Preserve their authored travel while ordinary grounded control is quicker.
		var reversing=dir.length()>.1 and Vector3(velocity.x,0,velocity.z).normalized().dot(dir.normalized())<-.45
		accel=(58.0 if reversing else (48.0 if dir.length()<.1 else 38.0))*movement_multiplier()
	if flying:accel=90.0*progression.movement_multiplier()
	if forward_dash.active:
		attack_motion_pending=false
		var dash_speed=GoemonDash.SPEED*forward_dash.tempo*minf(1.0,forward_dash.remaining/delta)*skill_factor(forward_dash.attack_ticket,"travel_speed")
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
	if crossgate_guarding() or (character_id==13 and active_ability.guarding()) or (RogueRoster.is_crossgate_fighter(character_id) and active_ability.controls_primary_facing()):pass
	elif (is_master_chief() or is_meta_shooter()) and dodge_time<=0:
		facing=Vector3.FORWARD.rotated(Vector3.UP,yaw)
	elif combat_aiming() and (character_id==2 or weapon_slot==2 or attack_left<=0):
		facing=combat_attack_direction()
	elif not forward_dash.active and not chain_pipe_combat.active and dodge_time<=0 and wall_jump_recovery<=0 and dir.length()>0.1 and (attack_left<=0 or (jumps_used>=2 and not game.camera_combat() and not game.rogue_battle_mode)):
		# Free movement turns into camera-relative travel in every direction.
		# Attacks and committed abilities keep their existing aim.
		facing=dir.normalized()
	model.rotation.y=lerp_angle(model.rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*(24 if attack_left>0 else (GroundResponse.TURN_RESPONSE if is_on_floor() else 14))))
	if not jump_style.active() and jump_buffer>0:
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
			if character_id in [27,29]:velocity.y=active_ability.LEAP_SPEED*sqrt(combat_tuning("jump_height"))*progression.jump_velocity_multiplier()
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
			if character_id in [27,29]:velocity.y=active_ability.LEAP_SPEED*sqrt(combat_tuning("jump_height"))*progression.jump_velocity_multiplier()
			coyote=0
			game.burst(global_position,Color("e8dab0"),7)
			play_sound("jump")
	var ordinary_drop=not flying
	if character_id==16 and active_ability!=null and active_ability.controls_vertical_motion():
		ordinary_drop=false
		velocity.y=active_ability.vertical_velocity(delta)
	elif character_id==15 and active_ability!=null and active_ability.bomb_controls_flight():
		ordinary_drop=false
		velocity.y=active_ability.bomb_vertical_velocity(delta,lifting,boosting)
	elif jump_style.active():
		jump_style.step(delta,dodge_time<=0 and not forward_dash.active)
	elif flying and character_id==15 and not lifting:
		velocity.y=-BEN_DESCENT_SPEED
	elif flying:
		velocity.y=move_toward(velocity.y,(BEN_FLIGHT_BOOST_ASCENT_SPEED if boosting else BEN_FLIGHT_ASCENT_SPEED) if character_id==15 else ((32.0 if boosting else 18.0) if lifting else -10.0),120.0*delta if character_id==15 else 60.0*delta)
	elif character_id in [27,29]:
		ordinary_drop=not active_ability.is_attacking()
		active_ability.step_leap(delta,dir)
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
	if (character_id in [14,15,16,17,28,31,32,33] or RogueRoster.is_crossgate_fighter(character_id) or RogueRoster.is_enemy(character_id)) and active_ability!=null:
		var authored_motion: Vector3=active_ability.ground_attack_velocity()
		if authored_motion!=Vector3.INF:
			velocity.x=authored_motion.x;velocity.z=authored_motion.z
			if active_ability.mode=="smoke_assault":
				ordinary_drop=false
				velocity.y=authored_motion.y
	var before_move=global_position
	if ordinary_drop:move_with_jump_drop()
	else:move_and_slide()
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
	if air_turn>0 and character_id not in [13,14,15,16,17,18,19,28,31,32,33] and not RogueRoster.is_crossgate_fighter(character_id) and not RogueRoster.is_enemy(character_id):
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
	model.visible=not ((is_master_chief() or is_meta_shooter()) and is_instance_valid(game.camera_rig) and game.camera_rig.first_person_mode)
	_update_footsteps(horizontal)
	_finish_movement_bounds()
	if character_id==2:musashi.after_pose()

func move_with_jump_drop():
	if ai_controlled or velocity.y>=0 or is_on_floor():
		move_and_slide()
		return
	var scale_y=combat_tuning("jump_drop_speed")
	if scale_y==1.0:
		move_and_slide()
		return
	# Scale this tick's descent once. Keep the controller's momentum for the next tick.
	velocity.y*=scale_y
	move_and_slide()
	if velocity.y<0:velocity.y/=scale_y

func _update_footsteps(horizontal:float):
	if model.locomotion.step_events==last_foot_events:return
	last_foot_events=model.locomotion.step_events
	if not is_on_floor() or horizontal<=(.25 if character_id==17 else 1.0):return
	if not is_rogue_character():game.burst(global_position,Color("e0d2a4"),2,0.55)
	if character_id in [31,32,33] and last_foot_events%2==0:return
	if character_id!=29:play_sound("step",.65 if character_id in SoundLibrary.GOEMON_FOOTSTEP_IDS else .22)

func _physics_musashi(delta:float):
	# Run tuning scales horizontal source travel; jump, combat and source clocks
	# stay isolated from cape, coyote, wall-hop, sprint and progression modifiers.
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
	var jump_requested=jump_buffer>0
	if not jump_style.active():jump_buffer=0
	jump_windup=0;air_turn=0
	var before=global_position;var grounded=is_on_floor();var vertical_before=velocity.y
	active_ability.locomotion.physics_step(delta,direction,jump_requested,not ai_controlled and Input.is_action_pressed("jump"),(not ai_controlled and Input.is_action_pressed("walk_modifier")) or skullpion_poison_left>0,guard)
	if not active_ability.is_attacking() and not guard:facing=active_ability.locomotion.facing
	model.rotation.y=atan2(-facing.x,-facing.z)
	model.native_motion=true
	model.locomotion_velocity=(global_position-before)/maxf(delta,.000001)
	if is_on_floor() and not grounded and vertical_before<0:play_sound("land")
	model.animate(delta,Vector2(velocity.x,velocity.z).length(),is_on_floor(),velocity.y,attack_left/attack_duration,attack_heavy,combo,false)
	model.visible=true
	was_floor=is_on_floor()
	_finish_movement_bounds()

func _finish_movement_bounds():
	if constrain_forest_bounds():return
	if game.descent_mode:
		# Keep long falls over the physical ground map without returning uphill.
		var bounds=game.world.playable_bounds.grow(-(25.0 if character_id==27 else 4.032*preload("res://scripts/forest/dark_lumina_kit.gd").SCALE if character_id==29 else 2.0)*growth_multiplier())
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
	var water_floor:float=game.world.water_support_height(global_position)
	if is_finite(water_floor) and global_position.y<water_floor-.10:
		global_position.y=water_floor+.02
		velocity.y=maxf(velocity.y,0.0)
	if game.world.model.falan_area!="interior" and (not game.world.model.terrain_detail.is_empty() or not game.world.model.falan_area.is_empty()) and game.world.submerged(global_position):
		global_position=game.checkpoint;velocity=Vector3.ZERO;jumps_used=0;reset_wall_jump();reset_physics_interpolation();game.camera_rig.reset_follow()
		return true
	var bounds=game.world.playable_bounds.grow(-(25.0 if character_id==27 else 4.032*preload("res://scripts/forest/dark_lumina_kit.gd").SCALE if character_id==29 else 2.0)*growth_multiplier())
	var edge_x=clampf(global_position.x,bounds.position.x,bounds.end.x)
	var edge_z=clampf(global_position.z,bounds.position.y,bounds.end.y)
	if edge_x!=global_position.x:global_position.x=edge_x;velocity.x=0
	if edge_z!=global_position.z:global_position.z=edge_z;velocity.z=0
	var floor_y:float=room_ladder.to_global(room_ladder.BOTTOM_EXIT).y if is_instance_valid(room_ladder) else minf(0.,game.world.height_at(global_position.x,global_position.z))
	if global_position.y<floor_y-5.0:
		global_position.y=floor_y+.15;velocity=Vector3.ZERO;jumps_used=0;reset_wall_jump();game.camera_rig.reset_follow()
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
	if character_id in [27,29] and not jump_style.active():velocity.y=active_ability.LEAP_SPEED*sqrt(combat_tuning("jump_height"))*progression.jump_velocity_multiplier()
	facing=horizontal.normalized()
	jump_buffer=0;coyote=0;air_turn=0
	# Wall hops work after all air jumps are spent, but never refill their budget.
	jumps_used=maxi(1,jumps_used)
	wall_jump_grace=0
	wall_jump_recovery=WALL_JUMP_RECOVERY
	if model.locomotion is HeroLocomotion:model.locomotion.air_age=0
	game.burst(global_position-wall_jump_normal*0.38+Vector3.UP*0.7,Color("e7d3a3"),7)
	play_sound("land")

func swap_weapon():
	if hp<=0:return
	if RogueRoster.is_crossgate_fighter(character_id) and preload("res://scripts/forest/equipment.gd").cycle(self):return
	if character_id==1:
		if weapon_controls.available():select_weapon(1+weapon_slot%3)
	elif is_master_chief():master_chief_combat.select_slot(1+master_chief_combat.weapon_slot%5)
	elif active_ability!=null and active_ability.has_method("swap_weapon"):active_ability.swap_weapon()

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
	defend_held=false
	guard_reply_left=0.0
	if jump_style.active():jump_buffer=0;jump_windup=0
	if spell_loadout!=null:spell_loadout.cancel(preserve_power)
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
	if character_id==28:return Proportions.KOJIRO_SIZE
	return Proportions.MUSASHI_SIZE if character_id==13 else 1.0

func skill_factor(ticket:Dictionary,key:String)->float:
	return preload("res://scripts/spells/skill_balance.gd").factor(ticket,key)

func contact_size_multiplier()->float:
	return character_size_multiplier()*growth_multiplier()

func hit_effect_scale()->float:
	var body_size=character_size_multiplier()
	if character_id==15:body_size=Proportions.BEN_HEIGHT/Proportions.GOEMON_HEIGHT
	elif character_id==2:body_size=Proportions.EDO_HEIGHT/Proportions.GOEMON_HEIGHT
	return body_size*(model.global_basis.y.length() if is_instance_valid(model) else growth_multiplier())

func _fit_character_capsule():
	if not is_instance_valid(body_shape):return
	if character_id in [27,29]:
		var bounds:AABB=model.bounds()
		body_shape.shape=BoxShape3D.new();body_shape.shape.size=bounds.size
		body_shape.position=bounds.get_center()
		return
	if not body_shape.shape is CapsuleShape3D:body_shape.shape=CapsuleShape3D.new()
	if RogueRoster.is_enemy(character_id):
		var bounds:AABB=model.bounds()
		body_shape.shape.radius=minf(bounds.size.x,bounds.size.z)*.5
		body_shape.shape.height=maxf(bounds.size.y,body_shape.shape.radius*2)
		body_shape.position=Vector3(0,body_shape.shape.height*.5,0)
		return
	var size=character_size_multiplier()
	body_shape.shape.radius=.38*size
	body_shape.shape.height=1.85*size
	body_shape.position.y=.95*size

func _clear_large_character_spawn():
	if not game.has_method("forest_enemy_visible"):return
	# A boss selected beside a castle needs a clear footprint before movement starts.
	var query=PhysicsShapeQueryParameters3D.new();query.shape=body_shape.shape;query.collision_mask=1;query.exclude=[get_rid()]
	var origin=global_position
	var bounds:Rect2=game.world.playable_bounds.grow(-(25.0 if character_id==27 else 4.032*preload("res://scripts/forest/dark_lumina_kit.gd").SCALE)*growth_multiplier())
	for ring in range(5):
		for sector in (1 if ring==0 else 12):
			var point=origin+Vector3(sin(sector*TAU/12),0,cos(sector*TAU/12))*ring*20
			if not bounds.has_point(Vector2(point.x,point.z)):continue
			point.y=game.world.height_at(point.x,point.z)+.08
			query.transform=global_transform*body_shape.transform;query.transform.origin=point+body_shape.position*growth_multiplier()
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				global_position=point;velocity=Vector3.ZERO;return

func growth_multiplier()->float:return minf(MAX_GROWTH,1.0+buildings_broken*GROWTH_PER_BUILDING)

func grow_from_building():
	buildings_broken+=1
	scale=Vector3.ONE*growth_multiplier()
	game.toast("BUILDING BROKEN · Size and reach ×%.2f" % growth_multiplier())

func range_multiplier()->float:
	return growth_multiplier()*(combat_tuning("surge_range") if surge_left>0 else 1.0)*pickup_multiplier("range")*float(accessory_bonuses.get("range",1.0))

func melee_range_multiplier()->float:
	var fist_reach=CROSSGATE_FIST_REACH if RogueRoster.is_crossgate_fighter(character_id) and model!=null and model.current_weapon()=="unarmed" else 1.0
	return fist_reach*range_multiplier()*melee_reach_setting()*(CROSSGATE_MELEE_REACH if RogueRoster.is_crossgate_fighter(character_id) else 1.0)*(combat_tuning("surge_range") if attack_charged and surge_left<=0 else 1.0)

func melee_reach_setting()->float:
	return combat_tuning("melee_reach")*(spell_loadout.melee_multiplier() if spell_loadout!=null and not spell_loadout.dispatching else 1.0)*(team_progression.multiplier("player_range") if team_progression!=null and game.player==self else 1.0)

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
	if RogueRoster.is_crossgate_fighter(character_id):return active_ability.melee_visual_reach()
	if character_id in [16,17] and active_ability!=null:return active_ability.melee_reach()
	if character_id==15:return 2.9*preload("res://scripts/character_proportions.gd").BEN_MODEL_SCALE*growth_multiplier()*pickup_multiplier("range")*melee_reach_setting()
	if character_id==13:return (2.1 if attack_heavy else 1.8)*contact_size_multiplier()*pickup_multiplier("range")*melee_reach_setting()
	var reach=HeroModel.WeaponProportions.SCALE*combat_tuning("pipe_range")*(1.65 if attack_charged else (1.26 if attack_heavy else 1.0))*attack_reach_multiplier()
	if not attack_charged:
		reach=minf(reach,model.visible_pipe_reach()+.12*growth_multiplier())
	return reach*melee_contact_multiplier()

func emit_robe_coins(radial: bool=false):
	if character_id!=1 or not scarf_equipped:return
	game.throw_robe_coins(facing,radial,weapon_slot==2,self)

func movement_multiplier()->float:
	var spell_speed=spell_loadout.movement_multiplier() if spell_loadout!=null else 1.0
	spell_speed*=food_multiplier("movement_speed")*float(accessory_bonuses.get("movement_speed",1.0))
	if is_master_chief():return progression.movement_multiplier()*spell_speed*(.55 if skullpion_poison_left>0 else 1.0)
	return (preload("res://scripts/forest/forest_enemy_roles.gd").BOSS_MOVE_SPEED if character_id==27 else preload("res://scripts/forest/dark_lumina_kit.gd").MOVE_SPEED if character_id==29 else preload("res://scripts/forest/dark_lumina_3_kit.gd").MOVE_SPEED if character_id==30 else 1.0)*progression.movement_multiplier()*spell_speed*(3.0 if scarf_equipped else 1.0)*(.55 if skullpion_poison_left>0 else 1.0)

func maximum_jumps()->int:
	if jump_style.active():return jump_style.maximum_jumps()
	if character_id==13:return 2
	if is_master_chief():return 1
	if scarf_equipped:return 4
	if character_id==8:return 1
	return 2

func can_fly()->bool:
	if not ai_controlled and game.has_method("forest_enemy_visible"):return false
	return (spell_loadout!=null and spell_loadout.flight_enabled) or (jump_style.selected=="ben" if jump_style.active() else character_id==15 or (character_id==32 and active_ability!=null and active_ability.demon) or (character_id==30 and not (active_ability!=null and active_ability.is_attacking() and active_ability.move==4))) or (not is_master_chief() and gold_cloak and scarf_equipped)

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
	if is_instance_valid(model.chain_pipe):model.chain_pipe.powered=character_id!=1
	aura.visible=character_id!=1
	if character_id!=1:game.burst(global_position+Vector3.UP,Color("ffe69b"),24)
	var audio_ticket=attack_chain.make_ticket("surge")
	audio_ticket["move_audio"]=game.move_audio.begin(self,"surge","surge")
	play_sound("spark",1.0,audio_ticket)
	game.toast("GOLDEN GOEMON · Flaming ryo · Pipe and chain ready" if character_id==1 else "GOLDEN SURGE · Wind spin / Giant toss / Explosive chain + Fire sweep")

func end_surge():
	if weapon_controls!=null:weapon_controls.cancel()
	surge_left=0
	model.set_surge(false)
	if is_instance_valid(model.chain_pipe):model.chain_pipe.powered=false
	sync_food_glow()

func clear_character_cooldowns():
	if ai_controlled or not game.settings.get("disable_character_cooldowns",false):return
	dodge_cooldown=0.0
	if active_ability!=null:active_ability.clear_cooldowns()
	if spell_loadout!=null:spell_loadout.clear_cooldowns()

func select_character(id: int):
	if timed_dodge!=null:timed_dodge.reset()
	combat_hold_left=0;combat_hold_source=-1
	if ai_controlled and (id in [18,19,28] or RogueRoster.is_enemy(id)):return
	if id==character_id:
		if RogueRoster.is_crossgate_fighter(id):preload("res://scripts/forest/equipment.gd").apply(self)
		spell_loadout.prepare()
		clear_character_cooldowns()
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
	if RogueRoster.is_crossgate_fighter(character_id):model.reset_jump_pose()
	model.hide();model.set_process(false)
	attack_left=0;attack_motion_pending=false;attack_charged=false;heavy_buffer=0;combo=0;queued=false;impact_pause=0;air_turn=0
	ensure_character(id)
	character_id=id;model=character_models[id];model.rotation=rotation_before;model.show();model.set_process(true)
	accessory_bonuses=preload("res://scripts/forest/equipment.gd").bonuses(game.settings.get("gear_loadouts",{}),preload("res://scripts/forest/equipment.gd").character_key(id),game.settings) if RogueRoster.is_crossgate_fighter(id) else {}
	model.scale=Vector3.ONE*combat_tuning("model_scale")
	_fit_character_capsule()
	if id in [27,29]:_clear_large_character_spawn()
	model.set_cloak(scarf_equipped,gold_cloak)
	if id==2:
		var horizontal=Vector2(velocity.x,velocity.z).limit_length(combat_tuning("sprint_speed")*movement_multiplier())
		velocity.x=horizontal.x;velocity.z=horizontal.y
	active_ability=character_abilities.get(id)
	if RogueRoster.is_crossgate_fighter(id):preload("res://scripts/forest/equipment.gd").apply_model(model)
	if active_ability!=null:
		active_ability.active=true;active_ability.cancel()
		if id==13:active_ability.locomotion.reset();active_ability.locomotion.facing=facing
		if id==2:musashi=active_ability
	spell_loadout.prepare()
	clear_character_cooldowns()
	refresh_max_health()
	hp=max_hp*health_fraction
	sync_food_glow()
	last_foot_events=model.locomotion.step_events
	foot_time=0
	if not ai_controlled and game.rogue_roster_mode and id in RogueRoster.PLAYABLE_IDS:game.selected_rogue_id=id
	if ai_controlled:return
	if is_instance_valid(game.camera_rig):game.camera_rig.sync_character_view()
	if not game.character_control_hints:
		game.toast(RogueRoster.name_for(id) if is_rogue_character() else ROSTER[id].name)
	else:
		var labels=PackedStringArray()
		for i in spell_loadout.numbered_slots.size():
			var slot:Array=spell_loadout.numbered_slots[i]
			if not slot.is_empty():labels.append("%d %s"%[i+1,slot[0]])
		game.toast((RogueRoster.name_for(id) if is_rogue_character() else ROSTER[id].name)+" · "+" · ".join(labels)+" · Q Fighters")

func is_master_chief()->bool:
	return character_id==18 and not ai_controlled

func is_meta_shooter()->bool:
	return character_id==32 and not ai_controlled and active_ability!=null and active_ability.demon

func is_rogue_character()->bool:
	return RogueRoster.is_rogue(character_id)

func rogue_untargetable()->bool:
	return (spell_loadout!=null and spell_loadout.untargetable()) or (is_rogue_character() and active_ability!=null and active_ability.untargetable())

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
	if entry.has("role"):visual.role=entry.role
	if entry.has("character"):visual.character=entry.character
	if id==RogueRoster.KAZI_ID:visual.kaz_skin=preload("res://scripts/kaz_skins.gd").model_skin(game.settings.kaz_skin)
	if RogueRoster.has_variant_skins(id):visual.variant_skin=game.settings[RogueRoster.CROSSGATE[id].skin_setting]
	if RogueRoster.is_shin(id):visual.shin_skin=game.settings[RogueRoster.ShinSkins.setting(RogueRoster.CROSSGATE[id].skin_set=="special")]
	add_child(visual);character_models[id]=visual
	if entry.has("combat"):
		var ability=entry.combat.new();ability.hero=self;ability.game=game
		if entry.has("role"):ability.role=entry.role
		add_child(ability)
		character_abilities[id]=ability;visual.combat=ability
		if id==18:master_chief_combat=ability
	character_models[id].hide()
	character_models[id].set_process(false)

func pickup_multiplier(kind: String)->float:
	if powerups.get(kind,0.0)<=0:return 1.0
	if kind=="attack_speed":return 1.0+.5*maxi(1,attack_speed_stacks)
	return {"damage":1.5,"range":1.5,"attack_speed":1.5}.get(kind,1.0)
func base_damage_multiplier()->float:
	var form_damage=10.0 if character_id==32 and active_ability!=null and active_ability.demon else 1.0
	return form_damage*(6.0 if character_id==15 else (3.0 if character_id in [1,14,16,17] else 1.0))*combat_tuning("damage_mult")*pickup_multiplier("damage")*(1.0+.1*run_upgrades.damage)*(team_progression.multiplier("character_damage") if team_progression!=null else 1.0)*(spell_loadout.damage_multiplier() if spell_loadout!=null else 1.0)
func base_character_attack_multiplier()->float:
	return game.balance_value(character_id,"damage_mult")*(team_progression.stat_damage_multiplier() if uses_level_stats() else 1.0)
func damage_multiplier()->float:
	return base_damage_multiplier()*(team_progression.stat_damage_multiplier() if uses_level_stats() else 1.0)
func magic_damage_multiplier()->float:
	return base_damage_multiplier()*(team_progression.stat_magic_multiplier() if uses_level_stats() else 1.0)*food_multiplier("jelly_magic")
func base_magic_damage()->float:
	return BASE_MAGIC_DAMAGE*magic_damage_multiplier()
func magic_spell_damage(spell_base:float)->float:
	var amount=spell_base*base_damage_multiplier()+base_magic_damage()
	return amount
func base_attack_speed_multiplier()->float:
	var melee_speed=CROSSGATE_MELEE_SPEED if RogueRoster.is_crossgate_fighter(character_id) and model!=null and model.current_weapon() not in ["bow","kunai","boomerang"] else 1.0
	if RogueRoster.is_crossgate_fighter(character_id) and model!=null and model.current_weapon()=="unarmed":melee_speed*=CROSSGATE_FIST_SPEED
	return melee_speed*combat_tuning("attack_speed")*progression.attack_multiplier()*pickup_multiplier("attack_speed")*(1.0+.05*run_upgrades.tempo)*(team_progression.multiplier("character_speed") if team_progression!=null else 1.0)*(team_progression.stat_attack_multiplier() if uses_level_stats() else 1.0)
func attack_speed_multiplier()->float:
	var chain_rate=active_ability.ranger_fire_rate_multiplier() if is_rogue_character() and active_ability!=null and active_ability.class_id=="ranger" else attack_chain.multiplier()
	return minf(ATTACK_SPEED_CAP,base_attack_speed_multiplier()*chain_rate*(spell_loadout.attack_multiplier() if spell_loadout!=null and not spell_loadout.dispatching else 1.0))

func uses_level_stats()->bool:return team_progression!=null and game.player==self
func uses_mana()->bool:return not ai_controlled and uses_level_stats() and RogueRoster.is_crossgate_fighter(character_id)

func can_pay_skill(id:String,notify:bool=false)->bool:
	if not uses_mana() or mana+0.0001>=spell_loadout.Catalog.mana_cost(id):return true
	if notify:game.toast("Not enough mana")
	return false

func spend_skill_mana(id:String,notify:bool=true)->bool:
	if not can_pay_skill(id,notify):return false
	if uses_mana():mana=maxf(0.0,mana-spell_loadout.Catalog.mana_cost(id))
	return true

func refund_skill_mana(id:String):
	if uses_mana():mana=minf(max_mana,mana+spell_loadout.Catalog.mana_cost(id))

func tick_mana(delta:float):
	var drain:float=spell_loadout.Catalog.KAGEROU_MANA_PER_SECOND if active_ability.kagerou_enabled else 0.0
	mana=clampf(mana+(MANA_REGEN-drain)*delta,0.0,max_mana)
	if drain>0 and mana<=0:active_ability.disable_kagerou()

func level_health_bonus()->float:return team_progression.stat_health_bonus() if uses_level_stats() else 0.0

func refresh_max_health(heal_growth: bool=false):
	var previous=max_hp
	max_hp=combat_tuning("max_hp")*progression.health_multiplier()*(1.0+.1*run_upgrades.vitality)
	max_hp+=level_health_bonus()
	if character_id==33 and active_ability!=null and active_ability.demon:max_hp+=500
	max_hp*=food_multiplier("max_hp")
	max_hp+=float(accessory_bonuses.get("health",0.0))
	hp=minf(max_hp,hp+(maxf(0,max_hp-previous) if heal_growth else 0.0))

func award_kill():
	if team_progression!=null:
		game.award_team_kill();return
	if not game.playing or game.paused or game.transitioning or hp<=0:return
	if progression.award_kills()>0:
		refresh_max_health(true)
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
	clear_food_buffs()

func food_multiplier(kind:String)->float:
	return 1.0+(FOOD_MULTIPLIERS.get(kind,1.0)-1.0)*food_buff_stacks[kind] if food_buffs.get(kind,0.0)>0 else 1.0

func food_defense()->float:return FOOD_DEFENSE_PER_STACK*food_buff_stacks.defense

func extra_defense(magical:bool=false)->float:
	return food_defense()+(0.0 if magical else float(accessory_bonuses.get("defense",0.0)))

func apply_food_buff(kind:String)->bool:
	if not food_buffs.has(kind) or hp<=0:return false
	food_buff_stacks[kind]+=1
	food_buffs[kind]=300.0 if kind in ["jelly_damage","jelly_magic","jelly_speed"] else FOOD_BUFF_SECONDS
	if kind=="max_hp":refresh_max_health(true)
	sync_food_glow()
	return true

func tick_food_buffs(delta:float):
	var health_was_active=food_buffs.max_hp>0
	for kind in food_buffs:
		food_buffs[kind]=maxf(0,food_buffs[kind]-maxf(0,delta))
		if food_buffs[kind]<=0:food_buff_stacks[kind]=0
	if health_was_active and food_buffs.max_hp<=0:refresh_max_health()
	sync_food_glow()

func clear_food_buffs():
	var health_was_active=food_buffs.max_hp>0
	for kind in food_buffs:food_buffs[kind]=0.0;food_buff_stacks[kind]=0
	if health_was_active:refresh_max_health()
	sync_food_glow()

func sync_food_glow():
	if not is_instance_valid(aura):return
	aura.set_food_glow(Vector3(float(food_buffs.jelly_damage>0),float(food_buffs.jelly_magic>0),float(food_buffs.jelly_speed>0)))
	aura.visible=hp>0 and (not aura.food_colors.is_empty() or (surge_left>0 and character_id!=1))

# Auto intent stays separate from real mouse state and all native attack timing.
func auto_attack_running()->bool:
	if combined_power_busy():return false
	if (defend_held or guard_reply_left>0) and RogueRoster.is_crossgate_fighter(character_id):return false
	if is_master_chief():return false
	if ai_controlled:return auto_attack_enabled and is_instance_valid(ai_target) and not ai_target.dead and hp>0 and game.model.phase=="wave"
	if not auto_attack_enabled or not game.camera_combat() or not game.playing or game.paused or game.transitioning or hp<=0:return false
	if game.siege_building() or Input.is_action_pressed("weapon_chain"):return false
	if Input.is_action_pressed("heavy_attack") and not (RogueRoster.is_crossgate_fighter(character_id) and game.has_method("issue_hound_order")):return false
	if dodge_time>0 or impact_pause>0 or forward_dash.active or sky_strike.active:return false
	if active_ability!=null and active_ability.blocks_movement():return false
	if RogueRoster.is_crossgate_fighter(character_id) and active_ability.uses_primary_targeting():return active_ability.locked_primary_enemy()!=null
	if RogueRoster.is_crossgate_fighter(character_id) and model.current_weapon() not in ["bow","kunai","boomerang"] and accessory_bonuses.get("primary","")!="fire":
		var target=auto_aim_target()
		return target!=null and game.aimed_enemy_in_melee_range({"collider":target,"position":AttackChain.aim_point(target)})
	return true

func auto_aim_origin()->Vector3:
	if character_id==2 and is_instance_valid(model):return model.hand_position("R")
	return global_position+Vector3.UP*(1.05 if is_rogue_character() else 1.25)*growth_multiplier()

func auto_aim_target(muzzle: Vector3=Vector3.INF)->Ninja:
	if ai_controlled:return ai_target if is_instance_valid(ai_target) and not ai_target.dead else null
	if not auto_attack_enabled or not game.camera_combat() or not game.playing or game.paused or game.transitioning or hp<=0:return null
	if RogueRoster.is_crossgate_fighter(character_id) and active_ability.uses_primary_targeting():return active_ability.locked_primary_enemy()
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
	var manual_lock=RogueRoster.is_crossgate_fighter(character_id) and active_ability.uses_primary_targeting()
	game.toast(("AUTO ATTACK ON · Tab to select an enemy" if manual_lock else "AUTO LOCK ON · Closest visible enemy · J to stop") if enabled else "AUTO ATTACK OFF · J to enable")

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
	var value=game.balance_value(character_id,key) if ai_controlled else game.hero_tuning(key)
	if key in ["counter_chance","critical_chance","dodge_chance"]:value=clampf(value+float(accessory_bonuses.get(key,0.0)),0,100)
	if key in ["critical_chance","dodge_chance","counter_chance"] and uses_level_stats():value=clampf(value+team_progression.stat_chance_bonus(key),0,100)
	if key=="critical_chance":value=minf(100.0,value+pet_passive_bonus(key))
	if key=="accuracy":
		value+=float(accessory_bonuses.get(key,0.0))
		if uses_level_stats():value+=team_progression.stat_chance_bonus(key)
		if RogueRoster.is_crossgate_fighter(character_id) and model!=null and model.current_weapon()=="axe":value-=10.0
	if key=="damage_mult":value*=food_multiplier(key)+food_multiplier("jelly_damage")-1.0
	if key=="attack_speed":value*=food_multiplier(key)+food_multiplier("jelly_speed")-1.0
	return value*sqrt(game.balance_value(character_id,"jump_height")) if key in ["jump_speed","second_jump_speed"] else value

func effective_dodge_chance()->float:
	return minf(combat_tuning("dodge_chance")+pet_passive_bonus("dodge_chance"),100.0)

func pet_passive_bonus(stat:String)->float:
	if ai_controlled or not uses_level_stats() or not RogueRoster.is_crossgate_fighter(character_id):return 0.0
	return team_progression.party_passive_bonus(game.settings.forest_pet_loadout,stat)

func health_regeneration()->float:
	return team_progression.stat_regeneration()+pet_passive_bonus("regeneration") if uses_level_stats() else 0.0

func movement_jump_available()->bool:
	return is_on_floor() or coyote>0 or jumps_used<maximum_jumps() or wall_jump_grace>0

func has_offensive_action()->bool:
	if spell_loadout!=null and spell_loadout.current!=null:return true
	if attack_left>0 or attack_motion_pending or impact_pause>0 or primary_down or charge_elapsed>0 or heavy_buffer>0:return true
	if sky_strike.active or forward_dash.active or chain_pipe_combat.active or quick_attacks.active or not quick_attacks.pending.is_empty():return true
	return active_ability!=null and (active_ability.has_offensive_action() if is_rogue_character() else ((character_id in [13,14,15,16,17,18,19,28,31,32,33] or RogueRoster.is_crossgate_fighter(character_id) or RogueRoster.is_enemy(character_id)) and active_ability.is_attacking()))

func interrupt_attack_for_movement(preserve_motion: bool=false):
	guard_reply_left=0.0
	if spell_loadout!=null:spell_loadout.interrupt()
	if weapon_controls!=null:weapon_controls.cancel()
	if RogueRoster.is_crossgate_fighter(character_id):active_ability.stop_primary_approach()
	# A normal running jump retains its momentum. Cancels strip attack impulses.
	if character_id==19 and active_ability.mode=="jump":active_ability.cancel()
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

func apply_cursed_affliction(index:int,seconds:float,source_id:int):
	if index<0 or index>=6 or seconds<=0 or not is_finite(seconds):return
	if hp<=0 or invuln>0 or game.tuning.invincible or crossgate_combo_protected():return
	if character_id==33 and active_ability.spell_immune():return
	cursed_afflictions[index]=maxf(cursed_afflictions[index],seconds);cursed_status_active=true;cursed_status_source=source_id
	if index==4:confusion_left=maxf(confusion_left,seconds)
	if index in [1,2,5]:
		cancel_charge();spell_loadout.interrupt()
	if index in [1,2]:combat_hold_source=-3;combat_hold_left=maxf(combat_hold_left,seconds)

func tick_cursed_afflictions(delta:float):
	var poison=minf(delta,cursed_afflictions[0]);cursed_status_active=false
	for i in 6:
		cursed_afflictions[i]=maxf(0,cursed_afflictions[i]-delta)
		cursed_status_active=cursed_status_active or cursed_afflictions[i]>0
	if poison>0:
		cursed_poison_tick+=poison
		if cursed_poison_tick>=1:
			cursed_poison_tick-=1
			take_hit_from(max_hp*.025,Vector3.ZERO,false,cursed_status_source,false,false,true)
	else:cursed_poison_tick=0
	if cursed_afflictions[5]>0:spell_loadout.seal_for(cursed_afflictions[5])
	if maxf(cursed_afflictions[1],cursed_afflictions[2])>0:
		combat_hold_source=-3;combat_hold_left=maxf(combat_hold_left,maxf(cursed_afflictions[1],cursed_afflictions[2]))

func clear_cursed_afflictions():
	cursed_afflictions.fill(0);cursed_poison_tick=0;cursed_status_active=false
	if combat_hold_source==-3:combat_hold_source=-1;combat_hold_left=0
