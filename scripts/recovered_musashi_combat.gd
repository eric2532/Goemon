extends Node
## Retail sword windows, frontal guard and Lumina Rotation. Additional recovered
## states are retained in the asset manifest; full original gameplay is ongoing.
const Profile=preload("res://scripts/recovered_musashi_action_profile.gd")
var hero: Hero
var game: Node
var active=false
var primary_held=false
var elapsed=0.0
var clip=""
var contact_done=false
var combo_timer=0.0
var combo=0
var queued_heavy=false
var contact_time=0.0
var swing_done=false
var mode=""
var action_key=""
var guard_held=false
var special_held=false
var guard_elapsed=0.0
var charge=0
var charge_clock=0.0
var queued_primary=false
var contact_end=0.0
var finisher_phase=""
var finisher_ticks=0
var finisher_vertical=0 # Original downward-positive units per source tick.
const FINISHER_PHASES={"windup":"fusion_4","rise":"fusion_4_rise","hover":"fusion_4_apex","drop":"fusion_4_drop","land":"fusion_4_land"}
var rotation_clock=0.0
var rotation_ticks=0
var rotation_angle=0
var rotation_previous_angle=0
var rotation_speed=256
var rotation_phase=""
var locomotion
func _ready():locomotion=preload("res://scripts/recovered_musashi_locomotion.gd").new(hero)

func _notification(what: int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:cancel()

func input(event: InputEvent):
	release_input(event)
	if not active or event.is_echo() or hero.dodge_time>0:return
	if event is InputEventKey and (event.ctrl_pressed or event.shift_pressed or event.alt_pressed or event.meta_pressed) and (event.is_action("weapon_pipe") or event.is_action("weapon_coin")):return
	if event.is_action_pressed("weapon_pipe"):
		select_number(1)
	elif event.is_action_pressed("weapon_coin"):
		select_number(2)
	elif event.is_action_pressed("light_attack"):
		primary_held=true
		if is_attacking():queued_primary=true
		else:primary_attack()
	elif event.is_action_pressed("heavy_attack"):
		if is_attacking():queued_heavy=true
		elif charge>=Profile.CHARGE_LIMIT:start_rotation()
		else:start_attack(true)
	elif event.is_action_pressed("surge"):
		if not is_attacking():guard_held=true;guard_elapsed=0.0
	elif event.is_action_pressed("equip"):
		if not is_attacking():special_held=true;guard_elapsed=0.0

func select_number(number:int):
	if not active or not game.playing or game.paused or game.transitioning or hero.hp<=0 or hero.dodge_time>0 or is_attacking():return
	if number==1:start_rotation()
	elif number==2:start_counter()

func release_input(event: InputEvent):
	if event.is_action_released("light_attack"):primary_held=false
	if event.is_action_released("surge"):
		guard_held=false
		if not special_held:charge=0;charge_clock=0
	if event.is_action_released("equip"):
		var release_special=special_held and charge>=Profile.CHARGE_LIMIT
		special_held=false
		if release_special and active and not game.paused and not game.transitioning:start_rotation()
		elif not guard_held:charge=0;charge_clock=0

func primary_attack():
	if active and not is_attacking() and hero.dodge_time<=0:start_attack(false)

func start_attack(heavy: bool):
	combo=0 if heavy or combo_timer<=0 else (combo+1)%4
	combo_timer=1.0;elapsed=0;contact_done=false
	swing_done=false
	hero.weapon_slot=1;hero.attack_heavy=heavy;hero.attack_charged=false
	hero.combo=combo+1;hero.hit_done=false;hero.struck_targets.clear()
	var model=hero.model
	var airborne=not hero.is_on_floor()
	action_key=("air_lumina" if airborne else "lumina") if heavy else (("moving_air_fusion" if Vector2(hero.velocity.x,hero.velocity.z).length()>.25 else "air_fusion") if airborne else "fusion_%d"%(combo+1))
	hero.model.sword_trail.begin_action(action_key)
	if not heavy and not airborne and combo==3:
		mode="finisher";finisher_vertical=0;_finisher_phase("windup")
		guard_held=false;special_held=false;charge=0;charge_clock=0
		hero.facing=hero.combat_attack_direction();hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
		hero.attack_ticket=hero.attack_chain.begin("sword_4","primary_4")
		# Retail case4 calls 0x5F6 at initialization; 0x447 waits for apex.
		game.move_audio.release(game,hero.attack_ticket)
		hero.model.animate(0,0,true,0,1,false,4,false)
		return
	mode="lumina" if heavy else "fusion"
	clip=Profile.action(action_key).clip
	hero.attack_duration=Profile.duration(action_key)
	var window=Profile.window(action_key);contact_time=window[0];contact_end=window[1]
	hero.attack_left=hero.attack_duration
	guard_held=false;special_held=false;charge=0;charge_clock=0
	hero.facing=hero.combat_attack_direction()
	hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	hero.attack_ticket=hero.attack_chain.begin("heavy" if heavy else "sword_%d"%(combo+1),"heavy" if heavy else "primary_%d"%(combo+1))
	play_swing()
	hero.model.animate(0,0,hero.is_on_floor(),hero.velocity.y,1,heavy,combo+1,false)

func start_rotation():
	_start_lumina_special("rotation")
func start_counter():
	_start_lumina_special("counter")
func _start_lumina_special(key:String):
	if not active or is_attacking() or not hero.is_on_floor():
		charge=0;charge_clock=0
		return
	guard_held=false;special_held=false;charge=0;charge_clock=0
	hero.facing=hero.combat_attack_direction();hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	mode=key;action_key=key;clip=Profile.action(action_key).clip
	elapsed=0;contact_done=false;swing_done=false;queued_primary=false;queued_heavy=false
	hero.weapon_slot=1;hero.attack_heavy=true;hero.attack_charged=false
	hero.hit_done=false;hero.struck_targets.clear()
	hero.attack_duration=23.0/30.0 if key=="rotation" else Profile.duration(action_key);hero.attack_left=hero.attack_duration
	var window=Profile.window(action_key);contact_time=8.0/30.0 if key=="rotation" else window[0];contact_end=19.0/30.0 if key=="rotation" else window[1]
	hero.attack_ticket=hero.attack_chain.begin("musashi_"+key,key)
	rotation_clock=0;rotation_ticks=0;rotation_angle=0;rotation_previous_angle=0;rotation_speed=256;rotation_phase="windup" if key=="rotation" else ""
	hero.model.sword_trail.begin_action(key);hero.model.animate(0,0,true,0,1,true,1,false)
	if key=="rotation":game.sound("musashi_spin",.7,false,hero.attack_ticket,13)

func _rotation_tick(delta:float):
	# MAIN/42 owns its own30Hz body/turn clock. Eight windup poses pause,
	# ten accelerating yaw updates pass4096, next update resets yaw, then tail.
	rotation_clock+=delta*30
	while rotation_clock+.000001>=1 and mode=="rotation":
		rotation_clock-=1;rotation_ticks+=1
		hero.attack_left=maxf(0,(23-rotation_ticks)/30.0)
		if rotation_ticks<=8:elapsed=rotation_ticks/30.0
		elif rotation_ticks<=18:
			rotation_phase="spin";elapsed=8.0/30.0
			rotation_previous_angle=rotation_angle;rotation_speed+=30;rotation_angle+=rotation_speed
			contact_done=true;hero.strike()
		elif rotation_ticks==19:
			rotation_phase="recovery";rotation_angle=0;action_key="rotation_end";clip=Profile.action(action_key).clip;elapsed=0
		else:
			elapsed=(rotation_ticks-19)/30.0
			if rotation_ticks>=23:
				clip="";mode="";rotation_phase="";hero.attack_left=0
				if queued_heavy:queued_heavy=false;start_attack(true)
				elif queued_primary or hero.auto_attack_running():queued_primary=false;primary_attack()

func guarding()->bool:return active and (guard_held or special_held) and not is_attacking() and hero.is_on_floor()
func charge_fraction()->float:return float(charge)/Profile.CHARGE_LIMIT
func filter_damage(amount:float,direction:Vector3,_projectile:bool=false)->float:
	if not guarding():return amount
	var travel=Vector3(direction.x,0,direction.z)
	return 0.0 if not travel.is_zero_approx() and hero.facing.dot(-travel.normalized())>=.5 else amount

func tick_timers(delta: float):
	combo_timer=maxf(0,combo_timer-delta)

func tick(delta: float,_after_pose: bool=false):
	if not active:return
	if game.paused or game.transitioning or not game.playing:
		cancel();return
	if controls_motion():return # The locomotion source clock advances these states.
	if mode=="rotation":_rotation_tick(delta);return
	if guarding():
		guard_elapsed+=delta;charge_clock+=delta*Profile.HZ
		while charge_clock+0.000001>=1:
			charge=mini(Profile.CHARGE_LIMIT,charge+Profile.CHARGE_PER_TICK);charge_clock-=1
	if is_attacking():
		var before=elapsed
		elapsed+=delta*hero.attack_speed_multiplier()
		hero.attack_left=maxf(0,hero.attack_duration-elapsed)
		if mode=="counter" and not swing_done and elapsed>=Profile.cue(action_key,"0x7"):
			swing_done=true;game.sound("musashi_rotation",.7,false,hero.attack_ticket,hero.character_id)
			hero.model.rotation_effect.spawn(hero.model.rig_visual.global_transform)
		if elapsed>=contact_time and before<contact_end:
			contact_done=true
			var after=elapsed
			elapsed=clampf(maxf(before,contact_time),contact_time,contact_end-.00001)
			hero.strike()
			elapsed=after
		if hero.attack_left<=0:
			clip="";mode=""
			if queued_heavy:
				queued_heavy=false;start_attack(true)
			elif queued_primary or hero.auto_attack_running():queued_primary=false;primary_attack()
	elif hero.auto_attack_running():primary_attack()

func is_attacking()->bool:return not clip.is_empty()
func controls_motion()->bool:return mode=="finisher" and not finisher_phase.is_empty()
func _finisher_phase(phase:String):
	finisher_phase=phase;finisher_ticks=0;elapsed=0
	action_key=FINISHER_PHASES[phase];clip=Profile.action(action_key).clip
	hero.attack_duration=Profile.duration(action_key);hero.attack_left=hero.attack_duration
	contact_time=0;contact_end=INF if phase=="drop" else 0
func source_motion_tick()->Vector3:
	if not controls_motion():return Vector3.ZERO
	finisher_ticks+=1;elapsed=finisher_ticks/Profile.HZ
	hero.attack_left=maxf(.000001,hero.attack_duration-elapsed)
	match finisher_phase:
		"windup":
			if finisher_ticks>=6:
				finisher_vertical=-16;_finisher_phase("rise")
		"rise":
			if finisher_vertical<31:finisher_vertical+=3
			var velocity_y=-finisher_vertical*locomotion.source_world_scale()*Profile.HZ
			if finisher_vertical>=0:
				_finisher_phase("hover");game.sound("fusion_air_swing",.7,false,hero.attack_ticket,hero.character_id)
			return Vector3.UP*velocity_y
		"hover":
			if finisher_ticks>=6:_finisher_phase("drop")
		"drop":
			if finisher_vertical<31:finisher_vertical+=3
			contact_done=true;hero.strike()
			return Vector3.UP*(-finisher_vertical*locomotion.source_world_scale()*Profile.HZ)
		"land":
			if finisher_ticks>=5:
				clip="";mode="";finisher_phase="";hero.attack_left=0;combo_timer=0
				if queued_heavy:queued_heavy=false;start_attack(true)
				elif queued_primary or hero.auto_attack_running():queued_primary=false;primary_attack()
	return Vector3.ZERO
func after_source_motion(grounded:bool,ceiling:bool):
	if not controls_motion():return
	if grounded and finisher_phase=="drop":_finisher_phase("land")
	elif ceiling and finisher_phase=="rise":
		finisher_vertical=0;_finisher_phase("hover")
func play_swing():
	swing_done=true
	game.sound("heavy_swing" if hero.attack_heavy else "swing",.7,false,hero.attack_ticket,hero.character_id)
func trail_active()->bool:
	if controls_motion():return finisher_phase=="drop"
	return is_attacking() and ((mode=="rotation" and rotation_phase=="spin") or (elapsed>=contact_time and elapsed<contact_end))
func lumina_scale_factor()->float:
	if mode=="counter":return 0x19EB/4096.0
	if mode=="rotation":return (4096+int(mini(rotation_ticks,7)*1024.0/7.0))/4096.0
	return 1.0
func can_hit_target(enemy: Ninja)->bool:
	if mode=="counter":return true
	if mode=="rotation":
		if rotation_phase!="spin":return false
		var unit=locomotion.source_world_scale()*hero.growth_multiplier()
		var center=hero.global_position+Vector3.UP*30*unit
		var before=center+hero.facing.rotated(Vector3.UP,-rotation_previous_angle*TAU/4096.0)*82*unit
		var after=center+hero.facing.rotated(Vector3.UP,-rotation_angle*TAU/4096.0)*82*unit
		return not AttackChain.segment_contact(enemy,before,after,.25*hero.contact_size_multiplier()).is_empty()
	if not hero.attack_heavy:return true
	# Fitted enemies can return the query point when it is already inside their
	# body. Test the actual hurt volume against the downstroke's narrow forward
	# corridor instead of treating that zero offset as a target behind Musashi.
	var origin=hero.global_position+Vector3.UP*1.1*hero.contact_size_multiplier()
	return not AttackChain.segment_contact(enemy,origin,origin+hero.facing*hero.melee_strike_reach(),.25*hero.contact_size_multiplier()).is_empty()
func blocks_movement()->bool:return false
func protects_player()->bool:return false
func cancel(_preserve_power: bool=false):
	primary_held=false;queued_heavy=false;queued_primary=false;clip="";mode="";elapsed=0;combo_timer=0
	guard_held=false;special_held=false;charge=0;charge_clock=0;guard_elapsed=0
	finisher_phase="";finisher_ticks=0;finisher_vertical=0
	rotation_clock=0;rotation_ticks=0;rotation_angle=0;rotation_previous_angle=0;rotation_speed=256;rotation_phase=""
	if locomotion!=null:locomotion.discard_jump_input()
	if is_instance_valid(hero):hero.attack_left=0
	if is_instance_valid(hero):
		var model=hero.character_models.get(13)
		if is_instance_valid(model):
			if is_instance_valid(model.sword_trail):model.sword_trail.clear()
			if is_instance_valid(model.rotation_effect):model.rotation_effect.clear()
func hit():cancel()
func interrupt_for_dodge():cancel()
