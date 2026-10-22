extends RefCounted
## SC01's normal digital-pad locomotion in original 16.16 units.
## Source values/entry tables: assets/characters/recovered_musashi/locomotion_sources.json.
## Godot collision geometry and camera-relative WASD are host adaptations.
const HZ=30.0
const TICK=1.0/HZ
const FIXED=65536.0
const WORLD_SCALE=0.018
const TO_VELOCITY=WORLD_SCALE*HZ/FIXED
var hero
var jumps_used=0
var facing=Vector3.FORWARD
var source_vertical=0
var source_speed=0
var state="idle"
var stop_ticks=0
var airborne=false
var _until_tick=0.0
var _held_velocity=Vector3.ZERO
var _jump_pending=false
var _combat_owned=false
var _travel_direction=Vector3.FORWARD

func _init(owner_=null):hero=owner_

func source_world_scale()->float:
	# Unowned recovery fixtures retain the original source-to-world conversion.
	return WORLD_SCALE*(hero.character_size_multiplier() if is_instance_valid(hero) and hero.has_method("character_size_multiplier") else 1.0)

func source_velocity_scale()->float:return source_world_scale()*HZ/FIXED

func reset():
	jumps_used=0;source_vertical=0;source_speed=0;state="idle";airborne=false
	_until_tick=0;_held_velocity=Vector3.ZERO;_jump_pending=false;_combat_owned=false
	stop_ticks=0
	_travel_direction=facing

func animation_state()->String:return state
func discard_jump_input():
	_jump_pending=false
	if is_instance_valid(hero):hero.jump_buffer=0

func source_tick(direction:Vector3,grounded:bool,jump_pressed:bool,jump_held:bool,cautious:bool,guarding:bool)->Vector3:
	var move=Vector3(direction.x,0,direction.z)
	if move.length_squared()>0.000001:move=move.normalized()
	else:move=Vector3.ZERO
	# 61488 -> 61774 maps source floor bit 0x2000 to landing result 4.
	if airborne and grounded and source_vertical>=0:
		airborne=false;jumps_used=0;source_vertical=0;source_speed=0;state="land"
		if not jump_pressed:return Vector3.ZERO
	if not airborne and jump_pressed:
		# 496D4 -> 5AD08 -> 5ADB0: entry initializes, does not integrate Y.
		airborne=true;jumps_used=1;source_vertical=-0x120000;state="jump"
		return Vector3.ZERO
	if not airborne and not grounded:
		airborne=true;source_vertical=0;state="fall"
	if airborne:
		# 5B858 occurs before all ordinary air integration in 5AE2C.
		# L-Belt is deliberately always available in this playable restoration.
		if jump_pressed and jumps_used<2:
			source_vertical=-0xE0000;jumps_used=2;state="double_jump"
		# 47814 writes VERTICAL 0x34: release adds gravity, not air drag.
		if source_vertical<0 and not jump_held:source_vertical=mini(source_vertical+0x10000,0x1F0000)
		if move!=Vector3.ZERO:
			facing=move;_travel_direction=move
			if source_speed>-0x80000:source_speed=-0x80000;source_speed=maxi(source_speed-0x10000,-0xBA000)
			else:source_speed=maxi(source_speed-0x1000,-0xBA000)
		# 48038 is a soft terminal guard: it tests the old value before adding.
		if source_vertical<0 or source_vertical<=0x1EFFFF:source_vertical+=0x1A000
		if state!="double_jump":state="jump" if source_vertical<0 else "fall"
		return _travel_direction*(-source_speed*source_velocity_scale())+Vector3.UP*(-source_vertical*source_velocity_scale())
	if state=="stop":
		if move!=Vector3.ZERO or guarding:state="idle";source_speed=0
		elif stop_ticks<11:
			stop_ticks+=1
			return _travel_direction*(4*source_world_scale()*HZ)
		else:state="idle";source_speed=0;return Vector3.ZERO
	if move==Vector3.ZERO:
		if source_speed<=-0xB0000 and not guarding:
			# 5AC48 initializes Table9 plus raw vector81238. Init consumes
			# pose0; common54418 then consumespose1. Eleven later callbacks
			# integrate4 units before the terminal flag clears the vector.
			state="stop";stop_ticks=0;source_speed=-0x40000
			return Vector3.ZERO
		source_speed=0
		if state!="land":state="idle"
		return Vector3.ZERO
	_travel_direction=move
	# Preserve the host game's mouse-facing guard while allowing WASD strafing.
	if not guarding:facing=move
	if source_speed==0:
		# Raw 80181218 normal-entry vector; 80181228 is guarding.
		source_speed=-0x40000 if guarding else -0x80000
		state="guard_walk" if guarding else ("walk" if cautious else "run")
		return Vector3.ZERO
	if guarding:source_speed=-0x40000
	else:
		source_speed=maxi(source_speed-0x1000,-0xB0000)
		if cautious:source_speed=maxi(source_speed,-0x40000)
	state="guard_walk" if guarding else ("sprint" if source_speed<-0x94000 else ("run" if source_speed<-0x70000 else "walk"))
	return _travel_direction*(-source_speed*source_velocity_scale())

func physics_step(delta:float,direction:Vector3,jump_pressed:bool,jump_held:bool,cautious:bool,guarding:bool):
	if hero==null or delta<=0:return
	_jump_pending=_jump_pending or jump_pressed
	var remaining=delta
	var displacement=Vector3.ZERO
	var combat=hero.active_ability
	if guarding:facing=hero.facing
	while remaining>0.00000001:
		if _until_tick<=0.00000001:
			var controls=combat!=null and combat.has_method("controls_motion") and combat.controls_motion()
			if controls:
				_jump_pending=false;_combat_owned=true
				_held_velocity=combat.source_motion_tick()
			else:
				if _combat_owned:
					_combat_owned=false;airborne=not hero.is_on_floor();jumps_used=2 if airborne else 0
					source_vertical=int(-hero.velocity.y/source_velocity_scale());source_speed=0
				_held_velocity=source_tick(direction,hero.is_on_floor(),_jump_pending,jump_held,cautious,guarding)
				_jump_pending=false
			_until_tick=TICK
		var part=minf(remaining,_until_tick)
		displacement+=_held_velocity*part
		remaining-=part;_until_tick-=part
	hero.velocity=displacement/delta
	hero.jumps_used=jumps_used
	hero.move_and_slide()
	if combat!=null and combat.has_method("after_source_motion") and _combat_owned:
		combat.after_source_motion(hero.is_on_floor(),hero.is_on_ceiling())
	if hero.is_on_ceiling() and source_vertical<0:
		source_vertical=0;_held_velocity.y=0
