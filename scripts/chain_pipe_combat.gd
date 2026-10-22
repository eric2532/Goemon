class_name ChainPipeCombat
extends RefCounted
var attack_ticket: Dictionary={}
var hero: Hero
var active=false
var mode="throw"
var elapsed=0.0
var duration=0.95
var powered=false
var damage=0.0
var reach=0.0
var origin=Vector3.ZERO
var direction=Vector3.FORWARD
var end=Vector3.ZERO
var struck={}
var exploded=false
var trail=0.0
var sweep_done=false
var release_sound_played=false
const Original=preload("res://scripts/recovered_goemon_combat_profile.gd")
func _init(player: Hero):hero=player
func start(kind: String,sweep_reach: float=6.5):
	if active or hero.attack_left>0 or hero.dodge_time>0:return
	attack_ticket=hero.attack_chain.begin("chain_"+kind)
	mode=kind;active=true;elapsed=0;release_sound_played=false;struck.clear();exploded=false;sweep_done=false;trail=0
	powered=hero.surge_left>0;duration=1.0 if mode=="throw" else .78
	damage=(90 if powered else 60) if mode=="throw" else (110 if powered else 70)
	damage*=hero.damage_multiplier()
	reach=(18.0 if mode=="throw" else sweep_reach)*hero.range_multiplier()*hero.melee_reach_setting()
	direction=hero.game.attack_direction();hero.facing=direction
	origin=hero.global_position+Vector3.UP*1.2*hero.growth_multiplier()+direction*.5
	end=origin+direction*reach
	if mode=="throw":
		var wall=hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1))
		if not wall.is_empty():end=wall.position-direction*.12
	hero.attack_duration=duration;hero.attack_left=duration;hero.attack_heavy=mode=="sweep";hero.attack_charged=false
	hero.model.equipped=true;hero.model.chain_pipe.powered=powered

	if hero.attack_chain.unleashed() and not hero.game.rogue_battle_mode:
		hero.emit_robe_coins()
		if mode=="throw":
			hit_path(origin,end)
			if powered:explode_tip()
		else:hit_fan()
		hero.game.combo_slash(origin,direction,2,reach/3.5)
		cancel()
func tick(delta: float):
	if not active:return
	var before=elapsed/duration;elapsed+=delta*hero.attack_speed_multiplier();var t=clampf(elapsed/duration,0,1)
	hero.attack_left=maxf(0,duration-elapsed)
	if not release_sound_played and elapsed>=Original.chain_release_time():
		release_sound_played=true
		hero.play_sound("chain_throw" if mode=="throw" else ("chain_fire_sweep" if powered else "chain_sweep"),.8,attack_ticket)
	var visual=hero.model.chain_pipe
	visual.endpoint_override=true;visual.powered=powered
	if mode=="throw":
		if before<.18 and t>=.18:hero.emit_robe_coins()
		var old_point=origin.lerp(end,smoothstep(.18,.55,before))
		var new_point=origin.lerp(end,smoothstep(.18,.55,t))
		if t>=.18 and before<.55:hit_path(old_point,new_point)
		visual.endpoint=new_point.lerp(hero.model.pipe.global_position,smoothstep(.65,1,t))
		if t>=.55 and not exploded:
			exploded=true
			if powered:explode_tip()
		var pose=PipeCombo.interpolate(PipeCombo.HIGH,PipeCombo.DIAGONAL_END,smoothstep(.1,.35,t))
		hero.model.chain_pose=PipeCombo.interpolate(pose,PipeCombo.IDLE,smoothstep(.7,1,t))
	else:
		var angle=lerpf(-deg_to_rad(70),deg_to_rad(70),smoothstep(.22,.68,t))
		var extension=lerpf(1.5,reach,smoothstep(.05,.24,t))*(1-smoothstep(.7,1,t))
		visual.endpoint=hero.global_position+Vector3.UP*1.2*hero.growth_multiplier()+direction.rotated(Vector3.UP,angle)*maxf(1.2,extension)
		if t>=.45 and not sweep_done:
			sweep_done=true;hero.emit_robe_coins();hit_fan()
		var pose=PipeCombo.interpolate(PipeCombo.LEFT_END,PipeCombo.RIGHT_END,smoothstep(.2,.7,t))
		hero.model.chain_pose=PipeCombo.interpolate(pose,PipeCombo.IDLE,smoothstep(.75,1,t))
	trail-=delta*hero.attack_speed_multiplier()
	if trail<=0 and t>.18 and t<.72:
		trail=.045
		if powered:hero.game.burst(visual.endpoint,Color("ff882b"),3,.5)
		else:hero.game.wind(visual.endpoint,-direction)
	if t>=1:cancel()
func hit_path(a: Vector3,b: Vector3):
	BreakableBuilding.hit_segment(hero.game,a,b+direction*.2,damage,attack_ticket,struck)
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		var legacy=enemy.global_position+Vector3.UP*(1.5 if enemy.boss else 1.1)
		var contact=AttackChain.segment_contact(enemy,a,b,.7*hero.pickup_multiplier("range")*hero.growth_multiplier(),legacy)
		if contact.is_empty():continue
		var point=AttackChain.contact_point(enemy,contact.point,legacy)
		var nearest=Geometry3D.get_closest_point_to_segment(point,a,b)
		if not clear_hit(nearest,point):continue
		hit(enemy,point,direction,damage)
func clear_hit(a: Vector3,b: Vector3)->bool:
	return hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()
func hit_fan():
	var bonus=hero.attack_chain.energized()
	BreakableBuilding.hit_area(hero.game,hero.global_position+Vector3.UP*hero.growth_multiplier(),reach,damage,attack_ticket,direction,cos(deg_to_rad(70)),struck)
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var hurt=AttackChain.contact_point(enemy,hero.global_position+Vector3.UP,enemy.global_position)
		var offset=hurt-hero.global_position
		var flat=Vector3(offset.x,0,offset.z)
		if flat.length()>reach+enemy.body_radius or absf(offset.y)>3.5*hero.growth_multiplier():continue
		if flat.length()>.1 and direction.dot(flat.normalized())<cos(deg_to_rad(70)):continue
		if not clear_hit(hero.global_position+Vector3.UP,AttackChain.contact_point(enemy,hero.global_position+Vector3.UP,enemy.global_position+Vector3.UP)):continue
		hit(enemy,AttackChain.contact_point(enemy,hero.global_position+Vector3.UP,enemy.global_position+Vector3.UP),flat.normalized(),damage)
	if bonus:ComboEnergy.melee_attack(hero,attack_ticket,reach,true)
func hit(enemy: Ninja,point: Vector3,dir: Vector3,amount: float):
	struck[enemy.get_instance_id()]=true;enemy.take_hit(amount,dir,true,attack_ticket)
	preload("res://scripts/recovered_goemon_vfx.gd").hit(hero.game,point,true);hero.play_sound("chain_hit",.55,attack_ticket)
	hero.game.chain+=1;hero.game.chain_timer=3
func explode_tip():
	EdoFireExplosion.emit(hero.game,end,true,"chain_explosion")
	var radius=5.5*hero.pickup_multiplier("range")*hero.growth_multiplier()
	BreakableBuilding.hit_area(hero.game,end,radius,120*hero.damage_multiplier(),attack_ticket)
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var point=AttackChain.contact_point(enemy,end,enemy.global_position+Vector3.UP)
		if point.distance_to(end)>radius+enemy.body_radius or not clear_hit(end,point):continue
		# Explosion damage is separate from the tip's one piercing hit.
		hit(enemy,point,(point-end).normalized(),120*hero.damage_multiplier())
func cancel():
	active=false;hero.attack_left=0
	if is_instance_valid(hero.character_models.get(1)):
		var model=hero.character_models[1];model.chain_pose={}
		if is_instance_valid(model.chain_pipe):model.chain_pipe.endpoint_override=false;model.chain_pipe.powered=hero.surge_left>0
