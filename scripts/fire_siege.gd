class_name FireSiege
extends TowerDefense

const State=preload("res://scripts/fire_siege_state.gd")
const ARROW_COST=5
const MINE_COST=10
const BUILD_RANGE=3.5
var runtime=State.new()
var redesign_mode=true
var mine_states: Array=[]
var gate_state: Dictionary={}
var gate_hp: float=0.0
var gate_max_hp: float=5000.0
var gate_position: Vector3=Vector3(0,0,180)
# The first mine remains available to existing tour and diagnostic scripts.
var mine_built: bool:
	get:return not mine_states.is_empty() and mine_states[0].level>0
var mine_progress: float:
	get:return mine_states[0].progress if not mine_states.is_empty() else 0.0
var mine_visual: Node3D:
	get:return mine_states[0].cannon if not mine_states.is_empty() else null
var build_site=-1
var build_progress=0.0
var building=false
var powered=true
var original_spawn=Vector3.ZERO
var _last_hero_id=-1
var exploration=preload("res://scripts/fire_siege_exploration.gd").new()
var shrine=preload("res://scripts/fire_siege_shrine.gd").new()
var gate=preload("res://scripts/fire_siege_gate.gd").new()
var shrine_warning_left=0.0

var generation: int:
	get:return runtime.generation
var start_progress: float:
	get:return runtime.start_progress
var revive_left: float:
	get:return runtime.revive_left
var hero_dead: bool:
	get:return runtime.hero_dead
var wave_elapsed: float:
	get:return runtime.wave_elapsed

func reset():
	retire_wave_effects()
	for site in site_states:
		if is_instance_valid(site.get("cannon")):site.cannon.queue_free()
	for mine in mine_states:
		if is_instance_valid(mine.get("cannon")):mine.cannon.queue_free()
	if not gate_state.is_empty() and is_instance_valid(gate_state.get("cannon")):gate_state.cannon.queue_free()
	gate_state.clear();gate_hp=0
	runtime.reset();active=false;enabled=true;elapsed=0;wave=0;pending=0;alive_count=0
	total_spawned=0;total_scheduled=0;total_skipped=0;money=10.0
	base_max_hp=50 if hard_mode else 100;base_hp=base_max_hp
	phase="setup";prep_left=0;wave_kills=0;wave_breaches=0;run_kills=0;run_breaches=0
	last_spawn_count=0;peak_spawn_count=0;last_spawn_usec=0
	slots.clear();wave_actors.clear();resolved.clear();respawn_count=0
	upgrades.clear();card_offer.clear();card_history.clear();card_choice_wave=0;chosen_wave=0
	cannon_path="";fire_path="";tactics_enabled=false
	cannons.clear();site_states.clear();mine_states.clear()
	build_site=-1;build_progress=0;building=false;powered=true;_last_hero_id=-1

func _create_sites():
	for site in game.world.cannon_sites:
		var structure=_new_structure("arrow",site.position)
		site_states.append({"level":0,"cannon":structure,"kind":"arrow","progress":0.0})
	for site in game.world.mine_sites:
		mine_states.append({"level":0,"cannon":_new_structure("mine",site.position),"kind":"mine","progress":0.0})
	if game.world.get("custom_map")!=true and game.world.get("expanded_mode")==true and game.world.layout_anchors.has("gate"):
		gate_position=game.world.layout_anchors.gate
		var structure=preload("res://scripts/fire_siege_gate_structure.gd").new()
		structure.game=game;structure.director=self;structure.position=gate_position;add_child(structure)
		gate_state={"level":0,"cannon":structure,"kind":"gate","progress":0.0}

func gate_alive()->bool:
	return not gate_state.is_empty() and gate_state.level>0 and gate_hp>0 and gate_state.cannon.completed
func _build_states()->Array:
	return site_states+mine_states+([] if gate_state.is_empty() else [gate_state])
func _build_sites()->Array:
	return game.world.cannon_sites+game.world.mine_sites+([] if gate_state.is_empty() else [{"position":gate_position,"footprint":Vector2(6,.6)}])

func mine_count()->int:
	var count=0
	for mine in mine_states:
		if mine.level>0:count+=1
	return count

func _new_structure(kind: String,point: Vector3)->Node3D:
	var structure=load("res://scripts/fire_siege_structure.gd").new()
	structure.game=game;structure.director=self;structure.kind=kind;structure.position=point
	add_child(structure)
	return structure

func begin():
	reset();_create_sites();active=true
	exploration.configure(self)
	shrine.configure(self);gate.configure(self);shrine_warning_left=0
	game.active_enemy_limit=300
	original_spawn=game.world.spawn_point;game.checkpoint=original_spawn
	game.player.position=original_spawn;game.player.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=ActionCamera.CROSSHAIR_DEFAULT_PITCH if game.crosshair_aim_enabled() else .5;game.camera_rig.reset_follow()
	_banner("FIRE SIEGE · Stand beside a structure to build · Hold Y for 3s to start",6)

func _running()->bool:
	return enabled and active and not runtime.terminal and is_instance_valid(game) and game.playing and not game.paused and not game.transitioning

func _living_hero()->bool:
	return is_instance_valid(game.player) and game.player.hp>0 and not hero_dead

func tick(delta: float):
	if not _running():return
	if base_hp<=0:_terminate(false);return
	var dt=maxf(0,delta)
	exploration.tick(dt)
	shrine_warning_left=maxf(0,shrine_warning_left-dt)
	elapsed+=dt
	if game.player.hp<=0 and not hero_dead:hero_died()
	if runtime.advance_revive(dt):_restore_hero()
	if _last_hero_id>=0 and game.player.character_id!=_last_hero_id:interrupt_inputs()
	_last_hero_id=game.player.character_id
	for i in range(game.enemies.size()-1,-1,-1):
		if not is_instance_valid(game.enemies[i]):game.enemies.remove_at(i)
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and owns(enemy):recover_escaped_actor(enemy)
	gate.tick(dt);shrine.tick(dt)
	if not _running():return
	var combat=phase in ["spawning","clearance"]
	var income_seconds=0.0
	var due=0
	if phase=="spawning":
		var schedule=runtime.advance_wave(dt)
		income_seconds=schedule.spawning_seconds;due=schedule.due
	var powered_delta=0.0
	if combat:
		var ledger=runtime.economy(money,dt,income_seconds,cannons.size(),mine_count())
		money=ledger.money;powered_delta=ledger.powered_delta
		powered=cannons.is_empty() or powered_delta>=dt-0.000000001
	else:powered=true
	_spawn_due(due)
	if phase=="spawning" and runtime.scheduled>=300:phase="clearance"
	for site in site_states:
		if is_instance_valid(site.cannon):site.cannon.tick(dt,powered_delta if site.level>0 else 0.0)
	for mine in mine_states:
		if is_instance_valid(mine.cannon):mine.cannon.tick(dt,0)
	if not gate_state.is_empty():gate_state.cannon.tick(dt)
	update_build_input(dt)
	update_start_input(dt,Input.is_action_pressed("siege_start"))
	_settle_wave()

func update_start_input(delta: float,held: bool):
	if not _running():return
	if phase!="setup":
		# Only a release in the new setup can rearm the next confirmation.
		runtime.interrupt_inputs();return
	if runtime.update_start(delta,held,_living_hero() and base_hp>0):queue_wave()

func queue_wave():
	if not _running() or not runtime.start_permit or phase!="setup" or wave>=10 or pending>0 or alive_count>0 or not _living_hero() or base_hp<=0:return
	retire_wave_effects();runtime.start_wave()
	wave+=1;phase="spawning";pending=300;total_scheduled+=300
	shrine.configure(self);gate.configure(self)
	wave_kills=0;wave_breaches=0;resolved.clear();wave_actors.clear();prep_left=0
	_banner("WAVE %02d / 10 · 300 RAIDERS · HOLD THE SHRINE" % wave,4)

func spawn_pending(_delta: float=0.0):
	# The clock in tick is the sole source of spawn demand. Legacy calls do
	# not bypass the 0.2-second cadence or accelerate the spawning window.
	pass

func _spawn_due(count: int):
	last_spawn_count=0
	if count<=0 or not _running() or phase!="spawning":return
	var started=Time.get_ticks_usec()
	for _i in range(count):
		var serial=300-pending
		var point: Vector3=game.world.lanes[1][0]
		var sideways=(float(serial%5)-2.0)*1.6
		point+=Vector3(sideways,.15,-float((serial/5)%4)*1.4)
		var enemy=Ninja.new();enemy.game=game;enemy.swarm=true
		enemy.defense_lane=1;enemy.defense_waypoint=1;enemy.defense_offset=Vector3(sideways,0,0)
		enemy.encounter_id="siege_%d_%d_%d" % [generation,wave,serial]
		enemy.formation_index=total_spawned;enemy.variant=(serial+wave)%3
		# Two additional melee roles use the existing combat timings and crowd path.
		var health=100.0
		if serial%10==4:
			enemy.variant=1;health=80.0;enemy.defense_speed_multiplier=1.15;enemy.defense_damage_multiplier=.8
			enemy.set_meta("siege_archetype","cyber_ronin");enemy.set_meta("siege_species",4)
		elif serial%10==9:
			enemy.variant=2;health=180.0;enemy.defense_speed_multiplier=.82;enemy.defense_damage_multiplier=1.4
			enemy.defense_scale=1.12
			enemy.set_meta("siege_archetype","armored_oni");enemy.set_meta("siege_species",5)
		enemy.position=point;enemy.state="march";enemy.alerted=true
		enemy.set_meta("siege_generation",generation)
		enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		game.add_child(enemy);game.enemies.append(enemy)
		enemy.max_hp=health;enemy.hp=health
		wave_actors[enemy.encounter_id]=weakref(enemy)
		_admit_gate_actor(enemy)
		pending-=1;total_spawned+=1;alive_count+=1;last_spawn_count+=1
	last_spawn_usec=Time.get_ticks_usec()-started;peak_spawn_count=maxi(peak_spawn_count,last_spawn_count)

func owns(enemy: Ninja)->bool:
	if not active or runtime.terminal or not is_instance_valid(enemy) or enemy.defense_lane<0:return false
	if enemy.get_meta("siege_generation",-1)!=generation or not wave_actors.has(enemy.encounter_id):return false
	return wave_actors[enemy.encounter_id].get_ref()==enemy

func record_defeat(enemy: Ninja):
	if not owns(enemy) or not enemy.dead or enemy.defense_escaped or resolved.has(enemy.encounter_id):return
	shrine.release(enemy);gate.release(enemy);_restore_gate_mask(enemy)
	resolved[enemy.encounter_id]="killed";wave_kills+=1;run_kills+=1;alive_count=maxi(0,alive_count-1)

func breach(enemy: Ninja):
	if not owns(enemy) or enemy.dead or resolved.has(enemy.encounter_id):return
	if shrine.handles(enemy) or gate_blocking(enemy):return
	if shrine.admit(enemy):
		wave_breaches+=1;run_breaches+=1
		enemy.state="march";enemy.timer=0;enemy.attack_hit=true;enemy.walk_clock=0;enemy.walk_phase_pending=true

func can_breach(enemy: Ninja)->bool:
	return owns(enemy) and not gate_blocking(enemy) and not shrine.handles(enemy) and enemy.defense_waypoint>=game.world.lanes[enemy.defense_lane].size()-1 and super.can_breach(enemy)

func lane_direction(enemy: Ninja)->Vector3:
	if gate_blocking(enemy):
		_admit_gate_actor(enemy)
		var target=gate.assignment(enemy)
		if target.is_empty():return Vector3.ZERO
		var offset: Vector3=target.position-enemy.position;offset.y=0;return offset.normalized()
	if shrine.handles(enemy):
		var offset: Vector3=shrine.assignment(enemy).position-enemy.position;offset.y=0;return offset.normalized()
	return super.lane_direction(enemy)

func apply_shrine_contact(enemy: Ninja)->bool:
	if not _running() or phase not in ["spawning","clearance"] or not shrine.handles(enemy):return false
	var target: Dictionary=shrine.assignment(enemy)
	if not target.attacking or enemy.position.distance_squared_to(target.position)>=1.25*1.25 or enemy.stun>0 or enemy.frozen_left>0 or enemy.impact_pause>0:return false
	var ray=PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP,game.world.base_position+Vector3.UP,1)
	if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
	base_hp=maxi(0,base_hp-1)
	game.burst(game.world.base_position+Vector3.UP*2,Color("ff725a"),4,.65)
	if shrine_warning_left<=0:
		shrine_warning_left=3;_banner("SHRINE UNDER ATTACK · %d / %d HEALTH" % [base_hp,base_max_hp],2.5)
	if base_hp<=0:_terminate(false)
	return true

func shrine_attacker_count()->int:return shrine.attackers()

func gate_blocking(enemy: Ninja)->bool:return gate.intercepts(enemy)
func _admit_gate_actor(enemy: Ninja)->void:
	if not gate_blocking(enemy):return
	if not enemy.has_meta("gate_prior_mask"):enemy.set_meta("gate_prior_mask",enemy.collision_mask)
	enemy.collision_mask|=16
	gate.admit(enemy)
func _restore_gate_mask(enemy: Ninja)->void:
	if not is_instance_valid(enemy):return
	if enemy.has_meta("gate_prior_mask"):
		enemy.collision_mask=int(enemy.get_meta("gate_prior_mask"));enemy.remove_meta("gate_prior_mask")
	if enemy.has_meta("gate_motion_target"):enemy.remove_meta("gate_motion_target")
	enemy.walk_clock=0;enemy.walk_phase_pending=true
func _clear_gate_combat()->void:
	gate.clear()
	if not is_instance_valid(game):return
	for enemy in game.enemies:
		if is_instance_valid(enemy):_restore_gate_mask(enemy)
func apply_gate_contact(enemy: Ninja)->bool:
	if not _running() or phase not in ["spawning","clearance"] or not gate.handles(enemy):return false
	var target: Dictionary=gate.assignment(enemy)
	if not target.attacking or enemy.position.distance_squared_to(target.position)>=1.25*1.25 or enemy.stun>0 or enemy.frozen_left>0 or enemy.impact_pause>0:return false
	var ray=PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP,gate_position+Vector3.UP,1)
	if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
	gate_hp=maxf(0,gate_hp-20.0*enemy.defense_damage_multiplier*game.tuning.enemy_damage)
	game._native_feedback().impact(gate_position+Vector3(enemy.position.x-gate_position.x,1.8,-.2),Vector3.BACK,1,Color("ff725a"))
	if gate_hp<=0:
		gate_state.cannon.break_gate();gate_state.level=0;gate_state.progress=0
		_clear_gate_combat();_banner("GATE BROKEN · Protect the shrine · Rebuild for 10 gold",4)
	return true

func retire_wave_effects():
	super.retire_wave_effects();shrine.clear();_clear_gate_combat()

func recover_escaped_actor(enemy: Ninja)->bool:
	if enemy.position.y< -5 or not game.world.playable_bounds.has_point(Vector2(enemy.position.x,enemy.position.z)):
		shrine.release(enemy);gate.release(enemy);_restore_gate_mask(enemy)
	return super.recover_escaped_actor(enemy)

func _settle_wave():
	if not active:return
	if base_hp<=0:_terminate(false);return
	var reward=runtime.settle(wave,base_hp,alive_count,pending,phase=="clearance")
	if reward<=0:return
	money+=reward
	retire_wave_effects();interrupt_inputs()
	if wave>=10:_terminate(true);return
	phase="setup";powered=true
	_banner("WAVE %02d CLEARED · +%d GOLD · Hold Y for the next wave" % [wave,reward],5)

func _terminate(victory: bool):
	if runtime.terminal:return
	active=false;pending=0;phase="complete" if victory else "defeat"
	interrupt_inputs();runtime.terminate();retire_wave_effects()
	if game.has_method("clear_siege_projectiles"):game.clear_siege_projectiles()
	if victory:game.defense_victory()
	else:game.defeat()

func defense_speed(enemy: Ninja)->float:
	return [8.5,11.5,7.0][enemy.variant]*enemy.defense_speed_multiplier*(1.35 if hero_dead else 1.0)

func hero_died():
	if not active or base_hp<=0 or not runtime.hero_died():return
	interrupt_inputs();game.player.hp=0;game.player.velocity=Vector3.ZERO
	game.player.cancel_charge();game.player.attack_left=0;game.player.queued=false
	game.player.end_surge()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if game.has_method("clear_siege_projectiles"):game.clear_siege_projectiles()
	_banner("HERO DOWN · Enemies move faster · Reviving in 5 seconds",5)

func revive_now()->bool:
	if not _running() or hard_mode or base_hp<=0 or not runtime.revive_now():return false
	_restore_hero();return true

func _restore_hero():
	if not active or base_hp<=0 or runtime.terminal:return
	game.reset_player_at(original_spawn);game.player.hp=game.player.max_hp;game.player.invuln=2.0
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	_banner("HERO REVIVED · 2 seconds of protection",2)

func interrupt_inputs():
	runtime.interrupt_inputs();building=false;build_site=-1;build_progress=0
	for state in _build_states():
		if is_instance_valid(state.cannon):
			state.cannon.set_build_progress(state.progress,false)
			state.cannon.set_proximity(false,false)

func nearest_site()->int:
	if not is_instance_valid(game) or not _living_hero():return -1
	var closest=-1;var best=BUILD_RANGE*BUILD_RANGE
	var states=_build_states()
	var sites=_build_sites()
	for index in range(states.size()):
		if states[index].level>0:continue
		var center: Vector3=sites[index].position
		if absf(center.y-game.player.position.y)>3:continue
		var half: Vector2=sites[index].footprint
		# Distance and visibility target the nearest footprint edge, so every
		# reachable side works without tracing through a tower's own parapet.
		var edge=Vector3(clampf(game.player.position.x,center.x-half.x,center.x+half.x),game.player.position.y,clampf(game.player.position.z,center.z-half.y,center.z+half.y))
		var diff=edge-game.player.position
		var distance=Vector2(diff.x,diff.z).length_squared()
		if distance>best:continue
		if game.is_inside_tree() and diff.length_squared()>.01:
			var query=PhysicsRayQueryParameters3D.create(game.player.global_position+Vector3.UP,edge+Vector3.UP,1)
			query.exclude=[game.player.get_rid()]
			if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
		best=distance;closest=index
	return closest

func build_candidate()->int:
	if not _running() or not _living_hero() or base_hp<=0:return -1
	var p=game.player
	var movement=Input.get_vector("move_left","move_right","move_forward","move_back")
	if movement.length_squared()>.01 or Vector2(p.velocity.x,p.velocity.z).length_squared()>.04:return -1
	if not p.is_on_floor() or Input.is_action_pressed("jump") or Input.is_action_pressed("dodge"):return -1
	if p.dodge_time>0 or p.forward_dash.active or p.sky_strike.active:return -1
	if p.active_ability!=null and p.active_ability.blocks_movement():return -1
	var nearby=nearest_site()
	return nearby if nearby>=0 and money+0.000000001>=site_cost(nearby) else -1

func update_build_input(delta: float,_held: bool=false):
	if not _running() or base_hp<=0:return
	var nearby=nearest_site()
	var index=build_candidate()
	var upgrade=nearest_upgrade_site()
	building=index>=0 and money+0.000000001>=site_cost(index)
	build_site=index;build_progress=0
	var states=_build_states()
	for i in range(states.size()):
		var state: Dictionary=states[i]
		var mine=state.kind=="mine"
		var barrier=state.kind=="gate"
		var price=10 if barrier else (MINE_COST if mine else ARROW_COST)
		state.cannon.set_proximity(i==nearby,money+0.000000001>=price)
		if not mine and not barrier and state.level>0:state.cannon.set_upgrade_proximity(i==upgrade,money+0.000000001>=10)
		if state.level>0:continue
		var working=i==index and building
		var step: Dictionary
		if barrier and state.progress>=1:
			# A paid completion may be deferred by occupancy. Retry only while
			# eligible; leaving the site retains ordinary progress decay.
			step={"progress":1.0 if working else maxf(0,1.0-.25*maxf(0,delta)),"completed":working}
		else:step=runtime.build_step(state.progress,delta,working,money+0.000000001>=price,4.0 if mine else 3.0)
		state.progress=step.progress
		if step.completed and money+0.000000001>=price and (not barrier or state.cannon.can_complete_build()):
			money=maxf(0,money-price);state.level=1
			if not mine and not barrier:cannons.append(state.cannon)
			if barrier:gate_hp=gate_max_hp
			state.cannon.complete_build();building=false
			if barrier:
				gate.configure(self)
				for enemy in game.enemies:
					if is_instance_valid(enemy):_admit_gate_actor(enemy)
			_banner("GATE READY · 5000 HP · Shoot through the door" if barrier else "MINE READY · +2 gold/s while enemies are spawning" if mine else "ARROW TOWER READY · 50 damage · 0.10 gold/s upkeep",3)
		state.cannon.set_build_progress(state.progress,working and state.level==0)
		if i==index:build_progress=state.progress

func site_cost(index: int)->int:
	var states=_build_states()
	if index<0 or index>=states.size() or states[index].level>0:return 0
	return 10 if states[index].kind=="gate" else MINE_COST if states[index].kind=="mine" else ARROW_COST

func _upgrade_access(index: int,required_level: int=1)->float:
	if not _running() or not _living_hero() or base_hp<=0 or not game.player.is_on_floor():return INF
	if index<0 or index>=site_states.size():return INF
	var state: Dictionary=site_states[index]
	if state.level!=required_level or not is_instance_valid(state.cannon) or state.cannon._generation!=generation:return INF
	if game.player.dodge_time>0 or game.player.forward_dash.active or game.player.sky_strike.active:return INF
	var site: Dictionary=game.world.cannon_sites[index]
	var center: Vector3=site.position;var hero=game.player
	if absf(center.y-hero.position.y)>3:return INF
	var half: Vector2=site.footprint
	var edge=Vector3(clampf(hero.position.x,center.x-half.x,center.x+half.x),hero.position.y,clampf(hero.position.z,center.z-half.y,center.z+half.y))
	var distance=Vector2(edge.x-hero.position.x,edge.z-hero.position.z).length_squared()
	if distance>BUILD_RANGE*BUILD_RANGE:return INF
	var ray=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP,edge+Vector3.UP,1);ray.exclude=[hero.get_rid()]
	if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return INF
	return distance

func nearest_upgrade_site()->int:
	var nearest=-1;var distance=INF
	for i in range(site_states.size()):
		var candidate=_upgrade_access(i)
		if candidate<distance:distance=candidate;nearest=i
	return nearest

func upgrade_site(index: int)->bool:
	if is_inf(_upgrade_access(index)) or money+0.000000001<10:return false
	var state: Dictionary=site_states[index]
	if not state.cannon.upgrade_to_ice():return false
	money=maxf(0,money-10);state.level=2
	_banner("ICE TOWER READY · Slow only · Keep arrow towers for damage",3)
	return true

func tower_counts()->Dictionary:
	var counts={"arrow":0,"ice":0}
	for state in site_states:
		if state.level==1:counts.arrow+=1
		elif state.level==2:counts.ice+=1
	return counts

func interaction_prompt()->String:
	if hero_dead:return "Reviving in %.1fs · Enemies move 35%% faster" % revive_left
	var upgrade=nearest_upgrade_site()
	if upgrade>=0:return "F: ICE UPGRADE · 10 gold · Slow only"+(" · Need %.2f more" % (10-money) if money<10 else "")
	for i in range(site_states.size()):
		if not is_inf(_upgrade_access(i,2)):return "LEVEL 2 ICE · Slow only · Maximum level"
	var index=nearest_site()
	if index<0:return "Approach a structure to build · Arrow 5 gold · Mine 10 gold"
	var cost=site_cost(index)
	var label="GATE" if _build_states()[index].kind=="gate" else "MINE" if index>=site_states.size() else "ARROW TOWER"
	if label=="GATE" and gate_state.progress>=1 and not gate_state.cannon.can_complete_build():return "OPENING OCCUPIED · Clear enemies before construction completes"
	return "STAND NEARBY · %s · %d gold%s" % [label,cost," · Need %.2f more" % (cost-money) if money<cost else ""]

func shrine_guidance()->Dictionary:
	var diff=game.world.base_position-game.player.position
	var direction=Vector2(diff.x,diff.z).normalized()
	return {"distance":Vector2(diff.x,diff.z).length(),"direction":direction,"screen_direction":direction.rotated(game.camera_rig.yaw),"under_attack":shrine_attacker_count()>0}

# Compatibility methods keep legacy card systems retired.
func try_purchase()->bool:return upgrade_site(nearest_upgrade_site())
func install_cannon(_index: int):pass
func upgrade_level(_id: String)->int:return 0
func card_eligible(_id: String)->bool:return false
func eligible_cards()->Array[String]:return []
func request_card_choice():pass
func choose_card(_id: String)->bool:return false
func card_summary()->String:return ""
func wave_size(_number: int)->int:return 300
func wave_profile(_number: int)->Dictionary:return {"size":1.0,"health":1.0,"damage":1.0,"speed":1.0}
func next_wave_in()->float:return 0.0
func remaining()->float:return maxf(0,60-wave_elapsed) if phase=="spawning" else 0.0

func _banner(message: String,duration: float):
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.banner=message;game.hud.banner_time=duration
