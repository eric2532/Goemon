extends RefCounted
## Each recovering occupant owns its native casts, damage and projectiles.
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const FACE=9.25 # Beyond the 8.6 m masonry half-width and projectile radius.
var reference:WeakRef
var shot_left=0.0
var damage_serial=0
var counter_pending=false
var resting=false
var leap_stage=""
var leap_age=0.0
var launch_point=Vector3.ZERO
var leap_aim=Vector3.ZERO
var unit:
	get:return reference.get_ref()
func reset():
	shot_left=0;damage_serial=0;counter_pending=false;resting=false;leap_stage="";leap_age=0
func enter(b:Dictionary):
	var u=unit
	damage_serial=int(b.get("damage_serial",0));counter_pending=false;resting=false;leap_stage=""
	u.active_ability.player.hp=u.hp
	if u.kit_id==8:
		var occupied=0
		for ally in u.director.active_units():
			if ally!=u and ally.kit_id==8 and ally.state=="sheltered" and ally.shelter.building_id==b.id:occupied+=1
		u.global_position=u.game.model.center(b)+Vector3((occupied%3-1)*4,Profile.BARRACKS_DECK_HEIGHT+.12,(occupied/3%3-1)*4)
		u.active_ability.player.pos=u.global_position;u.show()
func rest():
	if resting:return
	unit.active_ability.cancel();unit.active_ability.active=true
	counter_pending=false;resting=true
func face_point(b:Dictionary,target:Vector3)->Vector3:
	var m=unit.game.model;var center:Vector3=m.center(b)
	var offset=target-center;offset.y=0
	var point=center+offset/maxf(.01,maxf(absf(offset.x),absf(offset.z)))*FACE
	point.y=m.surface_height(point.x,point.z)
	return point
func target_for(b:Dictionary,reach:float):
	var u=unit;var c=u.active_ability;var center:Vector3=u.game.model.center(b)
	var best=null;var distance=INF
	for row in u.director.melee_candidates(center,reach+14):
		var enemy=row.enemy
		if not u.director.valid_target(enemy):continue
		var origin=face_point(b,enemy.global_position)+Vector3.UP*1.2
		var aim=AttackChain.aim_point(enemy,origin)
		var gap=origin.distance_to(aim)
		if gap>reach or gap>=distance or not c.clear_line(origin,aim):continue
		distance=gap;best=enemy
	return best
func aim_at(b:Dictionary,enemy):
	var u=unit;var c=u.active_ability
	u.ai_target=enemy;u.global_position=face_point(b,enemy.global_position);c.player.pos=u.global_position
	u.ai_aim=AttackChain.aim_point(enemy,u.global_position+Vector3.UP*1.2)
	c.aim=u.ai_aim;c.player.angle=atan2(u.ai_aim.x-u.global_position.x,u.ai_aim.z-u.global_position.z)
func tick(b:Dictionary,delta:float):
	var u=unit;var c=u.active_ability;var p=c.player
	resting=false;shot_left=maxf(0,shot_left-delta)
	var serial=int(b.get("damage_serial",0))
	if serial!=damage_serial:
		counter_pending=true;damage_serial=serial
	if u.kit_id==8:
		if shot_left<=0 and p.cooldowns.flintlock<=0:
			var enemy=target_for(b,22)
			if enemy!=null:begin_leap(b,enemy)
	elif u.kit_id in [10,5] and shot_left<=0:
		var enemy=target_for(b,20 if u.kit_id==10 else 28)
		if enemy!=null:
			aim_at(b,enemy)
			var origin=u.global_position+Vector3.UP*1.2
			var direction=(u.ai_aim-origin).normalized()
			if u.kit_id==10:
				c.begin_cast("primary")
				var power=int(p.rangerShots)%3==2 or p.buffTime>0
				Actions.fire_projectile(c,{"origin":origin,"direction":direction,"handPoseSampled":true,"angle":p.angle,"damage":roundi(Actions.PRIMARY.ranger.damage*1.5) if power else Actions.PRIMARY.ranger.damage,"speed":36,"kind":"arrow","weapon":"cutlass","heavy":true,"width":.25,"primary":true,"power":power})
				p.rangerShots+=1;shot_left=Actions.PRIMARY.ranger.duration/maxf(.01,u.attack_speed_multiplier())
			else:
				c.begin_cast("utility")
				for i in range(-2,3):
					Actions.fire_projectile(c,{"origin":origin,"direction":direction.rotated(Vector3.UP,i*.19),"angle":p.angle+i*.19,"damage":25,"speed":25,"kind":"star","width":.5,"visualScale":1.8,"range":28})
				p.cooldowns.roll=c.class_data().cooldowns.roll;shot_left=p.cooldowns.roll
	elif u.kit_id==11 and counter_pending and p.attack==null and p.cooldowns.cutlass<=0:
		counter_pending=false
		var enemy=target_for(b,Actions.PRIMARY.explorer.reach+1)
		if enemy!=null:aim_at(b,enemy);c.action("cutlass")
	if u.state=="sheltered":
		# Hidden occupants skip body physics, but still obey native combo expiry.
		u.attack_chain.tick(delta,u.attack_left>0 or c.blocks_movement())
		c.player.pos=u.global_position;c.tick(delta);c._animate(delta,0)
func begin_leap(b:Dictionary,enemy):
	var u=unit;var center:Vector3=u.game.model.center(b)
	leap_aim=AttackChain.aim_point(enemy,center+Vector3.UP)
	var offset=leap_aim-center;offset.y=0
	launch_point=center+offset/maxf(.01,maxf(absf(offset.x),absf(offset.z)))*6.0
	launch_point.y=center.y+Profile.BARRACKS_DECK_HEIGHT+.12
	u.ai_target=enemy;u.ai_aim=leap_aim;u.state="bunker_leaping";u.collision_layer=2
	leap_stage="approach";leap_age=0;u.director.sync_targets()
func tick_leap(delta:float):
	var u=unit;var c=u.active_ability;var p=c.player;var m=u.game.model
	leap_age+=delta;u.ai_aim=leap_aim
	var b:Dictionary=m.buildings.get(u.shelter.building_id,{})
	# A destroyed bunker must never leave a launch aimed at a vanished deck.
	if b.is_empty() and leap_stage in ["approach","takeoff"]:
		finish_leap();return
	if leap_stage=="approach":
		var offset=launch_point-u.global_position;offset.y=0
		u.ai_move=offset.normalized() if offset.length()>.5 else Vector3.ZERO
		if offset.length()<=.5 and u.is_on_floor():
			u.jump_buffer=.15;leap_stage="takeoff"
	elif leap_stage=="takeoff":
		var offset=leap_aim-u.global_position;offset.y=0;u.ai_move=offset.normalized()
		var local=u.global_position-m.center(b)
		if maxf(absf(local.x),absf(local.z))>FACE+.5 and not u.is_on_floor():
			u.ai_move=Vector3.ZERO;c.action("flintlock")
			if p.travel!=null:leap_stage="dive"
	elif leap_stage=="dive":
		u.ai_move=Vector3.ZERO
		if p.travel==null and p.pulses.is_empty() and u.is_on_floor():finish_leap();return
	if leap_age>5 and leap_stage!="dive":
		# A blocked launch returns through the ordinary entrance path.
		finish_leap()
func finish_leap():
	var u=unit;var m=u.game.model
	u.active_ability.interrupt_attack_for_movement();u.ai_move=Vector3.ZERO
	shot_left=3;leap_stage="";u.route.clear();u.route_goal=Vector2i(-999,-999)
	var b:Dictionary=m.buildings.get(u.shelter.building_id,{})
	if not b.is_empty():
		var local=u.global_position-m.center(b)
		if maxf(absf(local.x),absf(local.z))<FACE and local.y>Profile.BARRACKS_BODY_HEIGHT:
			# A ceiling or parapet can stop takeoff. Resume recovery on this
			# deck instead of asking ground navigation to cross its stone rim.
			u.state="sheltered";u.collision_layer=0;u.velocity=Vector3.ZERO;enter(b)
		else:u.state="retreating"
	else:u.state="returning"
	u.director.sync_targets()
