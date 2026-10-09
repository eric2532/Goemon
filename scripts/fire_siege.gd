class_name FireSiege
extends TowerDefense

const State=preload("res://scripts/fire_siege_state.gd")
const ARROW_COST=5
const MINE_COST=10
const BUILD_RANGE=3.5
var runtime=State.new()
var redesign_mode=true
var mine_states: Array=[]
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
var _build_armed=true
var _last_hero_id=-1

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
	runtime.reset();active=false;enabled=true;elapsed=0;wave=0;pending=0;alive_count=0
	total_spawned=0;total_scheduled=0;total_skipped=0;money=10.0
	base_max_hp=50 if hard_mode else 100;base_hp=base_max_hp
	phase="setup";prep_left=0;wave_kills=0;wave_breaches=0;run_kills=0;run_breaches=0
	last_spawn_count=0;peak_spawn_count=0;last_spawn_usec=0
	slots.clear();wave_actors.clear();resolved.clear();respawn_count=0
	upgrades.clear();card_offer.clear();card_history.clear();card_choice_wave=0;chosen_wave=0
	cannon_path="";fire_path="";tactics_enabled=false
	cannons.clear();site_states.clear();mine_states.clear()
	build_site=-1;build_progress=0;building=false;powered=true;_build_armed=true;_last_hero_id=-1

func _create_sites():
	for site in game.world.cannon_sites:
		var structure=_new_structure("arrow",site.position)
		site_states.append({"level":0,"cannon":structure,"kind":"arrow","progress":0.0})
	for site in game.world.mine_sites:
		mine_states.append({"level":0,"cannon":_new_structure("mine",site.position),"kind":"mine","progress":0.0})

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
	game.active_enemy_limit=300
	original_spawn=game.world.spawn_point;game.checkpoint=original_spawn
	game.player.position=original_spawn;game.player.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=.5;game.camera_rig.reset_follow()
	_banner("FIRE SIEGE · Approach a structure and hold B · Hold Y for 3s to start",6)

func _running()->bool:
	return enabled and active and not runtime.terminal and is_instance_valid(game) and game.playing and not game.paused and not game.transitioning

func _living_hero()->bool:
	return is_instance_valid(game.player) and game.player.hp>0 and not hero_dead

func tick(delta: float):
	if not _running():return
	if base_hp<=0:_terminate(false);return
	var dt=maxf(0,delta)
	elapsed+=dt
	if game.player.hp<=0 and not hero_dead:hero_died()
	if runtime.advance_revive(dt):_restore_hero()
	if _last_hero_id>=0 and game.player.character_id!=_last_hero_id:interrupt_inputs()
	_last_hero_id=game.player.character_id
	for i in range(game.enemies.size()-1,-1,-1):
		if not is_instance_valid(game.enemies[i]):game.enemies.remove_at(i)
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and owns(enemy):recover_escaped_actor(enemy)
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
	update_build_input(dt,Input.is_action_pressed("siege_build"))
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
		enemy.position=point;enemy.state="march";enemy.alerted=true
		enemy.set_meta("siege_generation",generation)
		enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		game.add_child(enemy);game.enemies.append(enemy)
		enemy.max_hp=100.0;enemy.hp=100.0
		wave_actors[enemy.encounter_id]=weakref(enemy)
		pending-=1;total_spawned+=1;alive_count+=1;last_spawn_count+=1
	last_spawn_usec=Time.get_ticks_usec()-started;peak_spawn_count=maxi(peak_spawn_count,last_spawn_count)

func owns(enemy: Ninja)->bool:
	if not active or runtime.terminal or not is_instance_valid(enemy) or enemy.defense_lane<0:return false
	if enemy.get_meta("siege_generation",-1)!=generation or not wave_actors.has(enemy.encounter_id):return false
	return wave_actors[enemy.encounter_id].get_ref()==enemy

func record_defeat(enemy: Ninja):
	if not owns(enemy) or not enemy.dead or enemy.defense_escaped or resolved.has(enemy.encounter_id):return
	resolved[enemy.encounter_id]="killed";wave_kills+=1;run_kills+=1;alive_count=maxi(0,alive_count-1)

func breach(enemy: Ninja):
	if not owns(enemy) or enemy.dead or resolved.has(enemy.encounter_id):return
	resolved[enemy.encounter_id]="breached";enemy.defense_escaped=true;enemy.dead=true
	if enemy.defense_traits!=null:enemy.defense_traits.cancel()
	enemy.collision_layer=0;enemy.hide();enemy.queue_free()
	alive_count=maxi(0,alive_count-1);wave_breaches+=1;run_breaches+=1;base_hp=maxi(0,base_hp-1)
	game.burst(game.world.base_position+Vector3.UP*3,Color("ff725a"),16,1.4)
	_banner("SHRINE BREACHED · %d / %d INTEGRITY" % [base_hp,base_max_hp],2.5)
	if base_hp<=0:_terminate(false)

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
	return [8.5,11.5,7.0][enemy.variant]*(1.35 if hero_dead else 1.0)

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
	runtime.interrupt_inputs();_build_armed=false;building=false;build_site=-1;build_progress=0
	for state in site_states+mine_states:
		if is_instance_valid(state.cannon):
			state.cannon.set_build_progress(state.progress,false)
			state.cannon.set_proximity(false,false)

func nearest_site()->int:
	if not is_instance_valid(game) or not _living_hero():return -1
	var closest=-1;var best=BUILD_RANGE*BUILD_RANGE
	var states=site_states+mine_states
	var sites=game.world.cannon_sites+game.world.mine_sites
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

func update_build_input(delta: float,held: bool):
	if not _running() or base_hp<=0:return
	if not held:_build_armed=true
	# Walking, knockback or jumping interrupts work even inside build range.
	# Releasing B makes the next stationary hold an intentional new action.
	var movement=Input.get_vector("move_left","move_right","move_forward","move_back")
	if held and (movement.length_squared()>.01 or Vector2(game.player.velocity.x,game.player.velocity.z).length_squared()>.04 or Input.is_action_pressed("jump")):
		_build_armed=false
	var nearby=nearest_site()
	var index=nearby if held and _build_armed and _living_hero() else -1
	building=index>=0 and money+0.000000001>=site_cost(index)
	build_site=index;build_progress=0
	var states=site_states+mine_states
	for i in range(states.size()):
		var state: Dictionary=states[i]
		var mine=state.kind=="mine"
		var price=MINE_COST if mine else ARROW_COST
		state.cannon.set_proximity(i==nearby,money+0.000000001>=price)
		if state.level>0:continue
		var working=i==index and building
		var step=runtime.build_step(state.progress,delta,working,money+0.000000001>=price,4.0 if mine else 3.0)
		state.progress=step.progress
		if step.completed and money+0.000000001>=price:
			money=maxf(0,money-price);state.level=1
			if not mine:cannons.append(state.cannon)
			state.cannon.complete_build();building=false
			_banner("MINE READY · +2 gold/s while enemies are spawning" if mine else "ARROW TOWER READY · 50 damage · 0.10 gold/s upkeep",3)
		state.cannon.set_build_progress(state.progress,working and state.level==0)
		if i==index:build_progress=state.progress

func site_cost(index: int)->int:
	var states=site_states+mine_states
	if index<0 or index>=states.size() or states[index].level>0:return 0
	return MINE_COST if states[index].kind=="mine" else ARROW_COST

func interaction_prompt()->String:
	if hero_dead:return "Reviving in %.1fs · Enemies move 35%% faster" % revive_left
	var index=nearest_site()
	if index<0:return "Approach a structure to build · Arrow 5 gold · Mine 10 gold"
	var cost=site_cost(index)
	var label="MINE" if index>=site_states.size() else "ARROW TOWER"
	return "IN RANGE · Hold B · %s · %d gold%s" % [label,cost," · Need %.2f more" % (cost-money) if money<cost else ""]

# Compatibility methods deliberately expose no legacy cards/upgrades/F buys.
func try_purchase()->bool:return false
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
