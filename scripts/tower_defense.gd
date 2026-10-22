class_name TowerDefense
extends EndlessEncounters

# A wave owns a finite roster. New waves only begin after every raider has
# either been defeated or reached the shrine, so demand never accumulates.
const START_MONEY=250
const BUILD_COST=100
const UPGRADE_COSTS=[100,150,225]
const PURCHASE_RADIUS=9.0
const PREPARATION_TIME=18.0
const REST_TIME=20.0
const SPAWN_BUDGET=4
const KILL_REWARD=12
const BETA_ENEMIES=600
const MAX_WAVES=10
const BETA_REST_TIME=12.0
const BETA_LIVE_LIMIT=180
const BETA_MONEY=12000
const BETA_PREPARATION=4.0
const BETA_SPAWN_BUDGET=8
const SPAWN_TIME_USEC=2000
const Cannon=preload("res://scripts/defense_cannon.gd")
var beta_mode=false
var tactics_enabled=true
var hard_mode=false
var upgrades: Dictionary={}
var cannon_path=""
var fire_path=""
var card_offer: Array[String]=[]
var card_history: Array=[]
var card_choice_wave=0
var chosen_wave=0
var active=false
var elapsed=0.0
var wave=0
var pending=0
var alive_count=0
var total_spawned=0
var total_scheduled=0
var total_skipped=0
var money: float=START_MONEY
var base_max_hp=20
var base_hp=20
var phase="preparing"
var prep_left=PREPARATION_TIME
var wave_kills=0
var wave_breaches=0
var run_kills=0
var run_breaches=0
var site_states: Array=[]
var cannons: Array=[]
var wave_actors: Dictionary={}
var resolved: Dictionary={}
var last_spawn_count=0
var peak_spawn_count=0
var last_spawn_usec=0

func reset():
	active=false;elapsed=0;wave=0;pending=0;alive_count=0;total_spawned=0
	total_scheduled=0;total_skipped=0;money=BETA_MONEY if beta_mode else START_MONEY
	base_max_hp=100 if beta_mode else 20;base_hp=base_max_hp
	if beta_mode and tactics_enabled and hard_mode:money=650;base_max_hp=50;base_hp=50
	upgrades.clear();cannon_path="";fire_path="";card_offer.clear();card_history.clear();card_choice_wave=0;chosen_wave=0
	phase="preparing";prep_left=BETA_PREPARATION if beta_mode else PREPARATION_TIME;wave_kills=0;wave_breaches=0
	run_kills=0;run_breaches=0
	last_spawn_count=0;peak_spawn_count=0;last_spawn_usec=0
	slots.clear();wave_actors.clear();resolved.clear();respawn_count=0
	for cannon in cannons:
		if is_instance_valid(cannon):cannon.queue_free()
	cannons.clear();site_states.clear()
	if is_instance_valid(game) and is_instance_valid(game.world) and game.world.get("cannon_sites")!=null:
		for index in range(game.world.cannon_sites.size()):
			site_states.append({"level":0,"cannon":null,"kind":"fire" if beta_mode and index%4 in [1,2] else "cannon"})

func begin():
	reset();enabled=true;active=true
	if beta_mode:
		game.active_enemy_limit=mini(game.active_enemy_limit,BETA_LIVE_LIMIT)
		for index in range(4 if tactics_enabled and hard_mode else site_states.size()):install_cannon(index)
	game.checkpoint=game.world.spawn_point
	game.player.position=game.checkpoint;game.player.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=.5;game.camera_rig.reset_follow()
	game.hud.banner="FIRE SIEGE · 2 walls · 4 fire towers + 4 cannons" if beta_mode else "THREE GATES · Build cannons at the gold pads [F]"
	game.hud.banner_time=6
	if beta_mode and tactics_enabled:request_card_choice()

func upgrade_level(id: String)->int:
	return int(upgrades.get(id,0)) if beta_mode and tactics_enabled else 0

func card_eligible(id: String)->bool:
	var data=DefenseCards.get_card(id)
	if data.is_empty():return false
	if int(data.max_stacks)>0 and upgrade_level(id)>=int(data.max_stacks):return false
	if data.has("requires") and upgrade_level(data.requires)==0:return false
	if data.get("path","")=="cannon" and not cannon_path.is_empty():return false
	if data.get("path","")=="fire" and not fire_path.is_empty():return false
	if id=="shrine_repair" and base_hp>=base_max_hp and game.player.hp>=game.player.max_hp:return false
	return true

func eligible_cards()->Array[String]:
	var result: Array[String]=[]
	for card in DefenseCards.definitions():
		if card_eligible(card.id):result.append(card.id)
	return result

func card_summary()->String:
	var names: Array[String]=[]
	for entry in card_history.slice(maxi(0,card_history.size()-3)):
		names.append(DefenseCards.get_card(entry.id).title)
	return " · ".join(names)+( "  (+%d earlier)" % (card_history.size()-3) if card_history.size()>3 else "")

func request_card_choice():
	if not beta_mode or not tactics_enabled or not active or wave>=MAX_WAVES or pending>0 or alive_count>0:return
	if phase=="draft" or chosen_wave>=wave+1:return
	retire_wave_effects();card_choice_wave=wave+1;card_offer.clear()
	if wave==0:
		card_offer.assign(["ice_shells","hot_flames","supply_cache"])
	else:
		var available=eligible_cards();var rng=RandomNumberGenerator.new()
		rng.seed=game.run_seed+card_choice_wave*7919
		for i in range(3):
			var index=rng.randi_range(0,available.size()-1)
			card_offer.append(available[index]);available.remove_at(index)
	phase="draft";prep_left=0
	game.show_defense_cards()

func choose_card(id: String)->bool:
	if not active or not beta_mode or not tactics_enabled or not game.playing or game.won:return false
	if phase!="draft" or card_choice_wave!=wave+1 or chosen_wave>=card_choice_wave or wave>=MAX_WAVES:return false
	if game.player.hp<=0 or base_hp<=0 or not card_offer.has(id) or not card_eligible(id):return false
	var data=DefenseCards.get_card(id)
	upgrades[id]=upgrade_level(id)+1
	if data.get("path","")=="cannon":cannon_path=data.value
	if data.get("path","")=="fire":fire_path=data.value
	match id:
		"supply_cache":money+=1000
		"shrine_repair":
			base_hp=mini(base_max_hp,base_hp+30)
			game.player.hp=minf(game.player.max_hp,game.player.hp+40)
		"fortified_shrine":base_max_hp+=25;base_hp+=25
	card_history.append({"wave":card_choice_wave,"id":id});chosen_wave=card_choice_wave;card_offer.clear()
	phase="preparing" if wave==0 else "rest";prep_left=BETA_PREPARATION if wave==0 else BETA_REST_TIME
	for tower in cannons:
		if is_instance_valid(tower) and tower.has_method("refresh_upgrades"):tower.refresh_upgrades()
	game.resume()
	game.hud.banner="%s · WAVE %02d IN %ds" % [String(data.title).to_upper(),chosen_wave,int(prep_left)]
	game.hud.banner_time=4
	return true

func clock_text(seconds: float)->String:
	var rounded=ceili(maxf(0,seconds))
	return "%02d:%02d" % [rounded/60,rounded%60]

func remaining()->float:return 0.0
func next_wave_in()->float:return maxf(0,prep_left) if phase!="wave" else 0.0
func wave_size(number: int)->int:return BETA_ENEMIES if beta_mode else mini(144,36+maxi(0,number-1)*12)
func cannon_count()->int:return cannons.size()
func tower_count(kind: String="")->int:
	var count=0
	for site in site_states:
		if site.level>0 and (kind.is_empty() or site.kind==kind):count+=1
	return count

func wave_profile(number: int)->Dictionary:
	var growth=float(clampi(number,1,MAX_WAVES)-1)
	return {"size":1.0+.10*growth,"health":1.0+.22*growth,"damage":1.0+.12*growth,"speed":1.0+.015*growth}

func retire_wave_effects():
	# A completed wave may leave a shell in flight. Reuse its pooled visual,
	# but never let damage from an old roster spill into the next one.
	for tower in cannons:
		if not is_instance_valid(tower):continue
		if tower.has_method("retire_wave_effects"):tower.retire_wave_effects()
		for effects in [tower.shells,tower.blasts]:
			for effect in effects:
				if is_instance_valid(effect.get("node")):effect.node.hide()
			effects.clear()
		tower.target=null

func queue_wave():
	if not active or pending>0 or alive_count>0 or (beta_mode and wave>=MAX_WAVES):return
	if beta_mode and tactics_enabled and chosen_wave!=wave+1:
		request_card_choice();return
	retire_wave_effects()
	wave+=1;phase="wave";prep_left=0;wave_kills=0;wave_breaches=0
	resolved.clear();wave_actors.clear()
	# The complete wave is bounded, even when the player's population cap is
	# smaller. Creation is budgeted across frames as existing raiders die.
	pending=wave_size(wave);total_scheduled+=pending
	game.hud.banner="WAVE %02d / %02d · %d RAIDERS · SIZE %.1f×" % [wave,MAX_WAVES,pending,wave_profile(wave)["size"]] if beta_mode else "WAVE %02d · %d RAIDERS · ALL THREE GATES" % [wave,pending]
	game.hud.banner_time=4

func tick(delta: float):
	if not enabled or not active or not game.playing or game.paused or game.transitioning or game.player.hp<=0:return
	if phase=="draft":return
	elapsed+=maxf(0,delta)
	for i in range(game.enemies.size()-1,-1,-1):
		if not is_instance_valid(game.enemies[i]):game.enemies.remove_at(i)
	alive_count=0
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.defense_lane>=0:
			alive_count+=1
			recover_escaped_actor(enemy)
	for cannon in cannons:
		if is_instance_valid(cannon):cannon.tick(delta)
	if phase!="wave":
		prep_left=maxf(0,prep_left-delta)
		if prep_left<=0:queue_wave()
	if phase=="wave":
		spawn_pending()
		if pending==0 and alive_count==0:
			if beta_mode and wave>=MAX_WAVES:
				retire_wave_effects()
				phase="complete";active=false;prep_left=0
				game.defense_victory()
				return
			var bonus=75+wave*10;money+=bonus;phase="rest";prep_left=BETA_REST_TIME if beta_mode else REST_TIME
			retire_wave_effects()
			game.hud.banner="WAVE %02d CLEARED · +%d GOLD · %ds TO REBUILD" % [wave,bonus,int(prep_left)]
			game.hud.banner_time=5
			if beta_mode and tactics_enabled:request_card_choice()

func recover_escaped_actor(enemy: Ninja)->bool:
	var bounds: Rect2=game.world.playable_bounds
	if enemy.position.y>=-5 and bounds.has_point(Vector2(enemy.position.x,enemy.position.z)):return false
	if not owns(enemy):return false
	# Knockback can carry a living raider over the low perimeter. Keep its
	# place in the roster, but return it to the route before it falls forever.
	var path: Array=game.world.lanes[enemy.defense_lane]
	if game.world.get("custom_map")==true:
		var waypoint=clampi(enemy.defense_waypoint,1,path.size()-1)
		var point=Geometry3D.get_closest_point_to_segment(enemy.position,path[waypoint-1],path[waypoint])
		point.y=game.world.height_at(point.x,point.z)+.15
		enemy.position=point;enemy.velocity=Vector3.ZERO;enemy.grounded_cached=false
		enemy.walk_clock=0;enemy.walk_age=0;enemy.walk_start=point;enemy.walk_end=point
		enemy.route_clock=0;enemy.route_direction=Vector3.ZERO;enemy.state="march";enemy.timer=0
		enemy.stun=0;enemy.impact_pause=0;enemy.attack_hit=false
		if enemy.defense_traits!=null:enemy.defense_traits.cancel_attack()
		return true
	var z=clampf(enemy.position.z,bounds.position.y+3,game.world.base_position.z-12)
	var waypoint=1
	while waypoint<path.size()-1 and z>=path[waypoint].z-2:waypoint+=1
	var upstream: Vector3=path[waypoint-1]+enemy.defense_offset
	var downstream: Vector3=path[waypoint]
	if waypoint<path.size()-1:downstream+=enemy.defense_offset
	var fraction=clampf((z-upstream.z)/(downstream.z-upstream.z),0,1)
	var point=upstream.lerp(downstream,fraction)
	point.z=z;point.y=game.world.height_at(point.x,z)+.15
	enemy.position=point;enemy.defense_waypoint=waypoint
	enemy.velocity=Vector3.ZERO;enemy.grounded_cached=false
	enemy.walk_clock=0;enemy.walk_age=0;enemy.walk_start=point;enemy.walk_end=point
	enemy.route_clock=0;enemy.route_direction=Vector3.ZERO
	enemy.state="march";enemy.timer=0;enemy.stun=0;enemy.impact_pause=0;enemy.attack_hit=false
	enemy.cooldown=maxf(enemy.cooldown,.6)
	if enemy.defense_traits!=null:enemy.defense_traits.cancel_attack()
	return true

func spawn_pending(_delta: float=0.0):
	if not active or phase!="wave" or game.paused or not game.playing or game.transitioning:return
	last_spawn_count=0
	var spawn_start=Time.get_ticks_usec()
	var profile=wave_profile(wave)
	var budget=mini(BETA_SPAWN_BUDGET if beta_mode else SPAWN_BUDGET,mini(pending,game.enemy_spawn_capacity()))
	for _i in range(budget):
		var lane=1 if beta_mode else total_spawned%3
		var serial=total_spawned if beta_mode else total_spawned/3
		var point: Vector3=game.world.lanes[lane][0]
		# Spread ranks across each broad lane, with the tail behind its gate.
		var sideways=(float(serial%5)-2)*2.2
		var rank=(serial/5)%(36 if beta_mode else 10)
		point+=Vector3(sideways,.15,-float(rank)*(1.35 if beta_mode else 2.8))
		if point.distance_squared_to(game.player.position)<16*16:
			point.z-=24
		var bounds: Rect2=game.world.playable_bounds.grow(-3)
		point.z=clampf(point.z,bounds.position.y,bounds.end.y)
		if point.distance_squared_to(game.player.position)<16*16:
			point.z=clampf(game.player.position.z+24,bounds.position.y,bounds.end.y)
		var enemy=Ninja.new();enemy.game=game;enemy.swarm=true
		enemy.defense_lane=lane;enemy.defense_waypoint=1;enemy.defense_offset=Vector3(sideways,0,0)
		if beta_mode:
			enemy.defense_scale=profile["size"];enemy.defense_health_multiplier=profile.health
			enemy.defense_damage_multiplier=profile.damage;enemy.defense_speed_multiplier=profile.speed
		enemy.encounter_id="defense_%d" % total_spawned;enemy.formation_index=total_spawned
		enemy.variant=(serial+lane+wave)%3;enemy.position=point;enemy.state="chase";enemy.alerted=true
		if beta_mode and tactics_enabled:
			var wave_serial=wave_size(wave)-pending
			enemy.defense_role=["shield","runner","brute"][(wave_serial+wave)%3]
			enemy.variant={"shield":0,"runner":1,"brute":2}[enemy.defense_role]
			if wave in [5,10] and wave_serial==40:
				enemy.defense_role="boss";enemy.defense_boss_tier=1 if wave==5 else 2
				enemy.defense_scale=3.2 if wave==5 else 4.0;enemy.variant=2
				enemy.position.x=0;enemy.defense_offset=Vector3.ZERO
		enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		game.add_child(enemy);game.enemies.append(enemy)
		# Defense raiders arrive in dense ranks; the player's full moveset and
		# damage remain unchanged while their durability grows by wave.
		enemy.max_hp*=.45*(1.0 if beta_mode else 1.0+minf(2.5,(wave-1)*.08));enemy.hp=enemy.max_hp
		wave_actors[enemy.encounter_id]=weakref(enemy)
		pending-=1;total_spawned+=1;alive_count+=1
		last_spawn_count+=1
		if Time.get_ticks_usec()-spawn_start>=SPAWN_TIME_USEC:break
	last_spawn_usec=Time.get_ticks_usec()-spawn_start
	peak_spawn_count=maxi(peak_spawn_count,last_spawn_count)

func defense_speed(enemy: Ninja)->float:
	return [8.5,11.5,7.0][enemy.variant]*(enemy.defense_speed_multiplier if beta_mode else 1.0+minf(.35,(wave-1)*.012))

func can_breach(enemy: Ninja)->bool:
	if game.world.get("custom_map")==true and enemy.defense_waypoint<game.world.lanes[enemy.defense_lane].size()-1:return false
	return enemy.position.distance_squared_to(game.world.base_position)<8*8

func lane_direction(enemy: Ninja)->Vector3:
	var path: Array=game.world.lanes[enemy.defense_lane]
	if can_breach(enemy):
		breach(enemy);return Vector3.ZERO
	if game.world.get("custom_map")==true:
		while enemy.defense_waypoint<path.size()-1:
			var next: Vector3=path[enemy.defense_waypoint]+enemy.defense_offset
			var previous: Vector3=path[enemy.defense_waypoint-1]+enemy.defense_offset
			var segment=next-previous;segment.y=0
			var remaining=enemy.position-next;remaining.y=0
			var passed=remaining.dot(segment)>=0 and remaining.length()<6
			if remaining.length()>2.5 and not passed:break
			enemy.defense_waypoint+=1
		var next: Vector3=path[enemy.defense_waypoint]
		if enemy.defense_waypoint<path.size()-1:next+=enemy.defense_offset
		var move=next-enemy.position;move.y=0;return move.normalized()
	# All routes advance north-to-south. After briefly fighting the hero,
	# resume the next downstream waypoint instead of walking back upstream.
	while enemy.defense_waypoint<path.size()-1 and enemy.position.z>=path[enemy.defense_waypoint].z-2:
		enemy.defense_waypoint+=1
	var target: Vector3=path[enemy.defense_waypoint]
	if enemy.defense_waypoint<path.size()-1:target+=enemy.defense_offset
	# A hero may lure a raider outside the corridor. Rejoin sideways before
	# advancing past a parapet, instead of pressing into its solid shoulder.
	var corridor_half_width=6.0-enemy.body_radius-.1
	var straight_approach=is_equal_approx(path[enemy.defense_waypoint].x,path[0].x)
	if straight_approach and enemy.position.z<205 and absf(path[0].x-enemy.position.x)>corridor_half_width:
		var rejoin=Vector3(signf(target.x-enemy.position.x),0,0)
		var probe=PhysicsRayQueryParameters3D.create(enemy.position+Vector3.UP,enemy.position+Vector3.UP+rejoin*2,1)
		if not game.get_world_3d().direct_space_state.intersect_ray(probe).is_empty():
			# The short side returns are open downstream. Walk around their
			# end before crossing back into the open approach.
			return Vector3.BACK
		return rejoin
	var direction=target-enemy.position;direction.y=0
	return direction.normalized()

func owns(enemy: Ninja)->bool:
	if enemy.defense_lane<0 or not wave_actors.has(enemy.encounter_id):return false
	return wave_actors[enemy.encounter_id].get_ref()==enemy

func record_defeat(enemy: Ninja):
	if not owns(enemy) or not enemy.dead or enemy.defense_escaped or resolved.has(enemy.encounter_id):return
	resolved[enemy.encounter_id]=true;money+=KILL_REWARD+upgrade_level("bounty_hunters")*4;wave_kills+=1;run_kills+=1
	alive_count=maxi(0,alive_count-1)

func breach(enemy: Ninja):
	if not active or not owns(enemy) or enemy.dead or resolved.has(enemy.encounter_id):return
	resolved[enemy.encounter_id]=true;enemy.defense_escaped=true;enemy.dead=true
	enemy.collision_layer=0;enemy.hide();enemy.queue_free()
	alive_count=maxi(0,alive_count-1);wave_breaches+=1;run_breaches+=1
	base_hp=maxi(0,base_hp-(15 if enemy.defense_boss_tier>0 else 1))
	game.burst(game.world.base_position+Vector3.UP*3,Color("ff725a"),16,1.4)
	game.hud.banner="SHRINE BREACHED · %d / %d INTEGRITY" % [base_hp,base_max_hp]
	game.hud.banner_time=2.5
	if base_hp<=0:active=false;pending=0;game.defeat()

func nearest_site()->int:
	if not is_instance_valid(game.player) or site_states.is_empty():return -1
	var closest=-1;var best=PURCHASE_RADIUS*PURCHASE_RADIUS
	for i in range(game.world.cannon_sites.size()):
		var point: Vector3=game.world.cannon_sites[i].position
		var diff=point-game.player.position
		if absf(diff.y)>10:continue
		var distance=Vector2(diff.x,diff.z).length_squared()
		if distance<=best:best=distance;closest=i
	return closest

func site_cost(index: int)->int:
	if index<0 or index>=site_states.size() or site_states[index].level>=3:return 0
	return UPGRADE_COSTS[site_states[index].level]

func interaction_prompt()->String:
	var index=nearest_site()
	if index<0:return "%d defenses · [F] at a gold pad to build or upgrade" % tower_count() if beta_mode else "Gold wall pads: [F] build a cannon · %d gold" % BUILD_COST
	var level=int(site_states[index].level);var label=String(game.world.cannon_sites[index].label)
	var tower_name="FIRE TOWER" if site_states[index].kind=="fire" else "CANNON"
	if level>=3:return "%s · %s III · MAXIMUM FIREPOWER" % [label,tower_name]
	var cost=site_cost(index)
	var action="BUILD %s" % tower_name if level==0 else "UPGRADE %s TO %s" % [tower_name,["I","II","III"][level]]
	return "[F] %s · %s · %d GOLD%s" % [label,action,cost," · Need %d more" % (cost-money) if money<cost else ""]

func try_purchase()->bool:
	if not active or not game.playing or game.paused or game.transitioning:return false
	var index=nearest_site()
	if index<0:return false
	var state: Dictionary=site_states[index];var site: Dictionary=game.world.cannon_sites[index]
	var tower_name="FIRE TOWER" if state.kind=="fire" else "CANNON"
	if state.level>=3:game.toast("This %s is already fully upgraded" % tower_name.to_lower());return false
	var cost=site_cost(index)
	if money<cost:game.toast("Need %d more gold for this %s" % [cost-money,tower_name.to_lower()]);return false
	money-=cost
	if state.level==0:install_cannon(index)
	else:state.level+=1;state.cannon.upgrade(state.level)
	game.burst(site.position+Vector3.UP,Color("ffce70"),18,1.2)
	game.toast("%s · %s %s READY" % [site.label,tower_name,["I","II","III"][state.level-1]])
	return true

func install_cannon(index: int):
	var state: Dictionary=site_states[index]
	if state.level>0:return
	var site: Dictionary=game.world.cannon_sites[index]
	var cannon=load("res://scripts/defense_flame_tower.gd").new() if state.kind=="fire" else Cannon.new()
	cannon.game=game;cannon.director=self;cannon.lane=site.lane
	add_child(cannon);cannon.position=site.position
	# Opening salvo and target scans are distributed across the battery.
	cannon.cooldown=.15+float(index%8)*.16
	cannon.target_clock=float(index%8)*.03
	state.level=1;state.cannon=cannon;cannons.append(cannon)
