class_name MusashiCombat
extends Node
signal state_changed(value: int)
# Keep legacy state IDs stable for the animation adapter.
enum State {IDLE,MOVING,PUNCH_1,PUNCH_2,PUNCH_3,HEAVY_HOOK,CHARGING_HOOK,FIREBALL,CHARGING_FIREBALL,FIRE_SHIELD,HIT_REACTION,BEAM,METEOR_CAST}
var attack_ticket: Dictionary={}
var shield_ticket: Dictionary={}
var hero: Hero
var game: Node
var balance: MusashiBalance=preload("res://assets/characters/musashi/combat/default_balance.tres")
var state=State.IDLE
var elapsed=0.0
var duration=0.0
var stage=0
var power=0.0
var contact_done=false
var charge_effect: FireEnergy
var shield: FireShieldVisual
var shield_left=0.0
var shield_cooldown=0.0
var shield_tick_left=0.0
var ranged_mode=true # Compatibility with older callers: Edo is always ranged.
var active=false
var beam: EdoFireBeam
var beam_guard=false
var beam_held=false
var beam_action="light_attack"
var teleport: SmokeTeleport
var primary_held=false
var heavy_queued=false
var large_cast=false
var meteor_pending=0

func _ready():teleport=SmokeTeleport.new(hero,self)
func blocks_movement()->bool:return teleport!=null and teleport.active
func change(next: int):state=next;elapsed=0;state_changed.emit(state)
func is_charging()->bool:return false
func is_attacking()->bool:return state in [State.FIREBALL,State.METEOR_CAST]
func is_casting_meteors()->bool:return state==State.METEOR_CAST
func empowered()->bool:return shield_left>0
func available()->bool:return state in [State.IDLE,State.MOVING,State.FIRE_SHIELD]
func progress()->float:return clampf(elapsed/maxf(duration,.001),0,1)
func charge_ratio()->float:return 0.0

func input(event: InputEvent):
	if event.is_action_released("light_attack"):primary_held=false
	if beam_held and event.is_action_released(beam_action):stop_hold_beam();return
	if hero.attack_chain.unleashed() and not event.is_echo():
		for number in [1,2,3]:
			if event.is_action_pressed({1:"weapon_pipe",2:"weapon_coin",3:"weapon_chain"}[number]):
				if number==3:begin_meteors()
				else:cast_fireball(number==2)
				return
	if event.is_action_pressed("weapon_pipe") or event.is_action_pressed("weapon_coin"):return
	if blocks_movement():return
	if event.is_action_pressed("equip") and not event.is_echo():teleport.start();return
	if hero.dodge_time>0 and not hero.attack_chain.unleashed():return
	if event.is_action_pressed("surge") and not event.is_echo() and ((shield_left<=0 and shield_cooldown<=0) or hero.attack_chain.unleashed()):
		activate_shield();return
	if event.is_action_pressed("sky_strike") and not event.is_echo():request_meteors();return
	if event.is_action_pressed("light_attack") and not event.is_echo():
		primary_held=true
		if available() or hero.attack_chain.unleashed():primary_attack()
	if event.is_action_pressed("heavy_attack") and not event.is_echo():
		if state==State.BEAM:stop_hold_beam()
		if available() or hero.attack_chain.unleashed():cast_fireball(true)
		elif is_attacking():heavy_queued=true

func primary_attack():
	if empowered():start_beam("light_attack")
	else:cast_fireball(false)
func request_meteors():
	if is_casting_meteors() and not hero.attack_chain.unleashed():meteor_pending=mini(meteor_pending+1,8);return
	begin_meteors()
func begin_meteors():
	attack_ticket=hero.attack_chain.begin("meteors")
	cancel_beam();clear_charge();primary_held=false;heavy_queued=false;contact_done=false
	duration=balance.meteor_cast_duration;change(State.METEOR_CAST)
	hero.attack_duration=duration;hero.attack_left=duration;hero.impact_pause=0
	hero.jump_buffer=0;hero.jump_windup=0;hero.velocity.x=0;hero.velocity.z=0
	hero.facing=game.attack_direction()
	charge_effect=FireEnergy.new();charge_effect.charged=true;game.add_child(charge_effect)
	charge_effect.global_position=hero.model.hand_position("R");charge_effect.scale=Vector3.ONE*1.6
	game.sound("edo_meteor_cast",.7)
	if hero.attack_chain.unleashed():
		contact_done=true;release_meteors();meteor_pending=0;hero.attack_left=0;change(State.IDLE)
func release_meteors():
	clear_charge()
	var rain=EdoMeteorRain.new();rain.game=game;rain.hero=hero;rain.attack_ticket=attack_ticket
	rain.damage=balance.meteor_damage*hero.damage_multiplier()
	rain.radius=balance.meteor_radius*hero.pickup_multiplier("range")*hero.growth_multiplier()
	rain.targets=EdoMeteorRain.choose_targets(hero,randi_range(balance.meteor_min_count,balance.meteor_max_count),balance.meteor_target_range*hero.growth_multiplier())
	game.add_child(rain)
	game.burst(hero.global_position+hero.facing*.7+Vector3.UP*.2,Color("ffac48"),18,.8)
	game.sound("edo_meteor_strike",.6);game.camera_rig.kick(Vector3.DOWN,.07)
func cast_fireball(large: bool=false):
	attack_ticket=hero.attack_chain.begin("giant_fireball" if large else "fireball")
	large_cast=large;power=1.0 if large else 0.0;stage=0
	heavy_queued=false;contact_done=false
	duration=balance.large_fireball_duration if large else balance.volley_duration
	change(State.FIREBALL);hero.attack_duration=duration;hero.attack_left=duration
	hero.facing=game.attack_direction()
	if hero.attack_chain.unleashed():
		cancel_beam();primary_held=false;contact_done=true;launch()
		game.sound("edo_giant" if large_cast else "edo_volley",.65)
		hero.attack_left=0;change(State.IDLE)
# Legacy editor scripts may still call this; there is no charging input anymore.
func begin_charge(_next: int):cast_fireball(true)
func clear_charge():
	if is_instance_valid(charge_effect):charge_effect.queue_free()
	charge_effect=null

func tick_timers(delta: float):
	if not active:return
	var attack_delta=delta*hero.attack_speed_multiplier()
	shield_cooldown=maxf(0,shield_cooldown-attack_delta)
	if shield_left>0 or beam_guard:
		var was_empowered=empowered()
		shield_left=maxf(0,shield_left-delta);shield_tick_left-=attack_delta
		if was_empowered and not empowered() and beam_held and beam_action=="light_attack":stop_hold_beam()
		while shield_tick_left<=0 and protects_player():
			shield_tick_left+=maxf(.05,balance.shield_tick);shield_damage()
		if shield_left<=0 and not beam_guard:end_shield()
func tick(delta: float,update_timers: bool=true):
	if not active:return
	if update_timers:tick_timers(delta)
	if blocks_movement():
		teleport.tick(delta)
		if teleport.active:return
	elapsed+=delta*hero.attack_speed_multiplier() if is_attacking() else delta
	if state==State.BEAM:
		if beam_held and not Input.is_action_pressed(beam_action):stop_hold_beam();return
		if is_instance_valid(beam):
			hero.facing=game.attack_direction();hero.attack_left=1.0
		else:hero.attack_left=0;end_beam_guard();change(State.IDLE)
	elif is_casting_meteors():
		hero.attack_left=maxf(0,duration-elapsed)
		if is_instance_valid(charge_effect):charge_effect.global_position=hero.model.hand_position("R")
		if progress()>=.62 and not contact_done:contact_done=true;release_meteors()
		if elapsed>=duration:
			hero.attack_left=0;change(State.IDLE)
			if meteor_pending>0:meteor_pending-=1;begin_meteors()
			elif heavy_queued:cast_fireball(true)
			elif primary_held and Input.is_action_pressed("light_attack"):primary_attack()
	elif is_attacking():
		hero.attack_left=maxf(0,duration-elapsed)
		if progress()>=.27 and not contact_done:
			contact_done=true;launch();game.sound("edo_giant" if large_cast else "edo_volley",.75 if large_cast else .55)
		if elapsed>=duration:
			hero.attack_left=0;change(State.IDLE)
			if heavy_queued:cast_fireball(true)
			elif primary_held and Input.is_action_pressed("light_attack"):primary_attack()
	elif state==State.HIT_REACTION:
		if elapsed>.24:change(State.IDLE)
	else:
		state=State.FIRE_SHIELD if empowered() else (State.MOVING if Vector2(hero.velocity.x,hero.velocity.z).length()>1 else State.IDLE)
		if primary_held and Input.is_action_pressed("light_attack") and hero.dodge_time<=0:primary_attack()

func launch():
	var from=hero.model.hand_position("R")
	var dir=game.projectile_direction(from)
	var score=-100.0
	if (hero.soft_target or hero.growth_multiplier()>1.01) and not game.rogue_battle_mode and not game.camera_combat():
		for e in game.enemies:
			if not is_instance_valid(e) or e.dead:continue
			var aim=e.global_position+Vector3.UP*(1.5 if e.boss else 1.1);var dif=aim-from
			var align=dir.dot(Vector3(dif.x,0,dif.z).normalized())
			if dif.length()>30 or align<.7:continue
			if not hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,aim,1)).is_empty():continue
			if align*30-dif.length()*.35>score:score=align*30-dif.length()*.35;dir=dif.normalized()
	var count=1 if large_cast else 3
	for i in range(count):
		var ball=load("res://assets/vfx/fireball/fireball.tscn").instantiate()
		ball.game=game;ball.balance=balance;ball.heavy=large_cast;ball.attack_ticket=attack_ticket
		ball.damage=(balance.charged_fireball_damage if large_cast else balance.fireball_damage)*hero.damage_multiplier()
		ball.hit_radius=(balance.charged_fireball_radius if large_cast else balance.fireball_radius)*hero.pickup_multiplier("range")*hero.growth_multiplier()
		ball.velocity=dir.rotated(Vector3.UP,(i-(count-1)*.5)*.12)*(balance.charged_projectile_speed if large_cast else balance.projectile_speed)*hero.attack_speed_multiplier()
		ball.lifetime=balance.projectile_lifetime*hero.growth_multiplier()/hero.attack_speed_multiplier()
		game.add_child(ball);ball.global_position=from

func start_beam(action: String="light_attack"):
	if beam_held and hero.attack_chain.unleashed() and is_instance_valid(beam):
		beam.attack_ticket=hero.attack_chain.begin("beam");beam.damage_tick();return
	if beam_held or blocks_movement():return
	if not empowered():return
	attack_ticket=hero.attack_chain.begin("beam")
	beam_action=action
	cancel_beam();clear_charge();heavy_queued=false
	if action!="light_attack":primary_held=false
	hero.facing=game.attack_direction()
	beam=load("res://assets/vfx/fire_beam/fire_beam.tscn").instantiate()
	beam.game=game;beam.hero=hero;beam.ability=self;beam.balance=balance.duplicate();beam.attack_ticket=attack_ticket
	beam.balance.beam_length=game.tuning.beam_length
	beam.balance.beam_radius=game.tuning.beam_width*.5*hero.pickup_multiplier("range")*hero.growth_multiplier()
	beam.sustained=true;beam_held=true
	change(State.BEAM);hero.attack_left=1;hero.attack_duration=1
	game.add_child(beam);game.camera_rig.kick(hero.facing,.08);game.sound("edo_beam_start",.6)
	if hero.attack_chain.unleashed():beam.damage_tick();beam.tick_left=balance.beam_tick
	beam_guard=true
	if shield_left<=0:shield_tick_left=0
	ensure_shield_visual()
func stop_hold_beam():
	if not beam_held and state!=State.BEAM:return
	if beam_action=="light_attack":primary_held=false
	cancel_beam();hero.attack_left=0;change(State.IDLE)
func release_primary():primary_held=false;stop_hold_beam()

func activate_shield():
	shield_ticket=hero.attack_chain.begin("shield")
	shield_left=balance.shield_duration;shield_cooldown=0 if hero.attack_chain.unleashed() else balance.shield_cooldown;shield_tick_left=0
	ensure_shield_visual();heavy_queued=false
	if state not in [State.BEAM,State.METEOR_CAST]:hero.attack_left=0;change(State.FIRE_SHIELD)
	game.burst(hero.global_position+Vector3.UP,Color("45adff"),30);game.sound("edo_shield",.8)
	game.toast("BLUE SURGE · Hold LMB: Piercing beam · Blue orbs extend its reach")
func ensure_shield_visual():
	if is_instance_valid(shield):return
	shield=load("res://assets/vfx/fire_shield/fire_shield.tscn").instantiate();hero.add_child(shield)
func shield_damage():
	BreakableBuilding.hit_area(game,hero.global_position+Vector3.UP*hero.growth_multiplier(),balance.shield_radius*hero.growth_multiplier(),balance.shield_damage*hero.damage_multiplier(),shield_ticket)
	for e in game.enemies:
		if not is_instance_valid(e) or e.dead:continue
		var dif=e.global_position-hero.global_position
		if dif.length()>balance.shield_radius*hero.growth_multiplier()+e.body_radius:continue
		if not hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP,e.global_position+Vector3.UP,1)).is_empty():continue
		e.take_hit(balance.shield_damage*hero.damage_multiplier(),dif.normalized(),false,shield_ticket)
		game.burst(e.global_position+Vector3.UP,Color("5ecbff"),5,.5)
func end_shield():
	shield_left=0
	if beam_guard:return
	if is_instance_valid(shield):shield.dissipate()
	shield=null
func cancel(preserve_power: bool=false):
	primary_held=false;heavy_queued=false;meteor_pending=0
	if teleport!=null:teleport.cancel()
	cancel_beam();clear_charge()
	if not preserve_power:end_shield()
	hero.attack_left=0;change(State.IDLE)
	for ball in get_tree().get_nodes_in_group("musashi_projectiles"):ball.queue_free()
	if not preserve_power:
		for rain in get_tree().get_nodes_in_group("edo_meteor_rains"):rain.queue_free()
func hit():
	if protects_player():return
	primary_held=false;heavy_queued=false;meteor_pending=0
	cancel_beam();clear_charge();hero.attack_left=0;change(State.HIT_REACTION)
func protects_player()->bool:return shield_left>0 or beam_guard or blocks_movement()
func interrupt_for_dodge():
	primary_held=false;heavy_queued=false;meteor_pending=0
	cancel_beam();clear_charge();hero.attack_left=0;change(State.IDLE)
func select_weapon(_ranged: bool):ranged_mode=true
func end_beam_guard():
	beam_guard=false
	if shield_left<=0:end_shield()
func cancel_beam():
	beam_held=false
	if is_instance_valid(beam):beam.stop()
	beam=null;end_beam_guard()
func finish_beam(effect: Node):
	if beam!=effect:return
	beam=null;beam_held=false;hero.attack_left=0;end_beam_guard()
	if state==State.BEAM:change(State.IDLE)
