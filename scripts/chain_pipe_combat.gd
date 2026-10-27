class_name ChainPipeCombat
extends "res://scripts/character_combat.gd"
const Original=preload("res://scripts/recovered_goemon_combat_profile.gd")
const EXTENDED_TIME=1.0
const TURN_SPEED=TAU
var attack_ticket:Dictionary={}
var mode="throw"
var elapsed=0.0
var duration=0.0
var damage=0.0
var reach=0.0
var origin=Vector3.ZERO
var direction=Vector3.FORWARD
var end=Vector3.ZERO
var struck={}
var phase=""
var phase_age=0.0
var airborne_start=false
var hold_action=0x71
var flight_age=0.0
var flight_reach=0.0
var last_point=Vector3.ZERO
var origin_offset=Vector3.ZERO

func _init(player:Hero):
	hero=player;game=player.game

func start(_kind:String="throw",_sweep_reach:float=6.5):
	if active or hero.attack_left>0 or hero.dodge_time>0:return
	attack_ticket=hero.attack_chain.begin("chain_throw")
	active=true;mode="throw";elapsed=0;phase="windup";phase_age=0;flight_age=0;struck.clear()
	airborne_start=not hero.is_on_floor()
	duration=Original.chain_release_time(airborne_start)+Original.CHAIN_FLIGHT_TICKS/Original.LOGIC_HZ+EXTENDED_TIME+Original.action_duration(0x72)
	damage=(90 if hero.surge_left>0 else 60)*hero.damage_multiplier()
	reach=18.0*hero.range_multiplier()*hero.melee_reach_setting();flight_reach=reach
	direction=hero.combat_attack_direction();hero.facing=Vector3(direction.x,0,direction.z).normalized()
	origin_offset=Vector3.UP*1.2*hero.growth_multiplier()+direction*.5
	origin=hero.global_position+origin_offset;end=origin+direction*reach;last_point=origin
	hero.attack_duration=duration;hero.attack_left=duration;hero.attack_heavy=false;hero.attack_charged=false
	hero.model.equipped=true;hero.model.chain_pipe.powered=false

func pose()->Dictionary:
	if phase=="windup":return {"action":0x75 if airborne_start else 0x70,"time_seconds":phase_age}
	if phase=="catch":return {"action":0x72,"time_seconds":phase_age}
	return {"action":hold_action,"time_seconds":0.0}

func tick(delta:float):
	if not active:return
	var advance=maxf(0,delta)*hero.attack_speed_multiplier()
	elapsed+=advance;phase_age+=advance
	hero.attack_left=maxf(.001,duration-elapsed)
	var visual=hero.model.chain_pipe
	visual.powered=false
	if phase=="windup":
		var release=Original.chain_release_time(airborne_start)
		if phase_age<release:return
		phase_age-=release;advance=phase_age;phase="flight"
		hold_action=0x76 if airborne_start and not hero.is_on_floor() else 0x71
		hero.play_sound("chain_throw",.8,attack_ticket)
		hero.emit_robe_coins()
		visual.endpoint_override=true
	if phase=="flight":
		var remaining=advance
		var aim=hero.combat_attack_direction()
		var peak_time=Original.CHAIN_FLIGHT_TICKS/Original.LOGIC_HZ*.5
		var flight_duration=peak_time*2+EXTENDED_TIME
		while remaining>.000001 and phase=="flight":
			var next_tick=(floorf(flight_age*Original.LOGIC_HZ+.000001)+1)/Original.LOGIC_HZ
			var step=minf(remaining,minf(next_tick,flight_duration)-flight_age)
			flight_age+=step;remaining-=step
			# Bound each turn so the swept tip follows the arc instead of teleporting across it.
			direction=direction.rotated(Vector3.UP,clampf(direction.signed_angle_to(aim,Vector3.UP),-TURN_SPEED*step,TURN_SPEED*step))
			hero.facing=Vector3(direction.x,0,direction.z).normalized()
			origin_offset=Vector3.UP*1.2*hero.growth_multiplier()+direction*.5
			origin=hero.global_position+origin_offset
			var source_time=flight_age-clampf(flight_age-peak_time,0,EXTENDED_TIME)
			var extension=Original.chain_extension(source_time)
			var point=origin+direction*flight_reach*extension
			var wall=AttackChain.world_ray(hero,last_point,point,1,[hero.get_rid()]) if not point.is_equal_approx(last_point) else {}
			if not wall.is_empty():
				point=wall.position-last_point.direction_to(point)*.02
				flight_reach=maxf(0,(point-origin).dot(direction))/maxf(.0001,extension)
				if source_time<peak_time+.000001:flight_age=flight_duration-source_time
			hit_path(last_point,point)
			last_point=point;visual.endpoint=point
			if flight_age>=flight_duration-.000001:
				if hold_action==0x76 and not hero.is_on_floor():cancel();return
				phase="catch";phase_age=remaining
				duration=elapsed-remaining+Original.action_duration(0x72);hero.attack_duration=duration
	if phase=="catch":
		visual.endpoint=hero.model.chain_pipe.global_position
		if phase_age>=Original.action_duration(0x72):cancel()

func hit_path(a:Vector3,b:Vector3):
	BreakableBuilding.hit_segment(hero.game,a,b,damage,attack_ticket,struck)
	var radius=.7*hero.pickup_multiplier("range")*hero.growth_multiplier()
	for enemy in AttackChain.segment_enemy_candidates(hero.game,a,b,radius):
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		var contact=AttackChain.segment_contact(enemy,a,b,radius)
		if contact.is_empty():continue
		var point=AttackChain.contact_point(enemy,contact.point,enemy.global_position+Vector3.UP)
		if not AttackChain.clear_line(hero,contact.point,point,[hero.get_rid()]):continue
		struck[enemy.get_instance_id()]=true
		enemy.take_hit(damage,direction,true,attack_ticket)
		if hero.ai_controlled:hero.game.confirm_ally_impact(enemy,point,direction,2,true,1)
		else:
			if hero.ai_controlled:hero.game.confirm_ally_impact(enemy,point,direction,2,true,1)
			else:hero.game.confirm_impact(enemy,point,direction,2,true,1)
			hero.game.chain+=1;hero.game.chain_timer=3

func cancel(_preserve_power:bool=false):
	active=false;phase="";phase_age=0;flight_age=0;struck.clear();attack_ticket={};hero.attack_left=0
	if is_instance_valid(hero.character_models.get(1)):
		var model=hero.character_models[1];model.chain_pose={}
		if is_instance_valid(model.chain_pipe):model.chain_pipe.endpoint_override=false;model.chain_pipe.powered=false
