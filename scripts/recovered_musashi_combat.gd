extends "res://scripts/character_combat.gd"
## Retail sword windows, frontal guard, Lumina specials and five enemy abilities.
const SKILL_SCALE=preload("res://scripts/weapon_proportions.gd").RECOVERED_SKILL_SCALE
const Profile=preload("res://scripts/recovered_musashi_action_profile.gd")
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
var assimilation:Node3D
var technique_ticks=0
var technique_vertical=0
var crosswise_impact_done=false
var combo_skill=""
var contact_segments:Array[PackedVector3Array]=[]
var contact_until=-1.0
const INPUT_BUFFER_SECONDS=0.4
var buffered_action=""
var buffered_args:Array=[]
var buffer_left=0.0

func responsive_controls()->bool:
	return spell_owner==null and hero.character_id==13 and not hero.ai_controlled

func buffer_action(method:String,args:Array=[])->bool:
	if not responsive_controls() or not is_attacking():return false
	if not active or not game.playing or game.paused or game.transitioning or hero.hp<=0 or hero.dodge_time>0:return false
	buffered_action=method;buffered_args=args;buffer_left=INPUT_BUFFER_SECONDS
	_recovery_exit()
	return true

func recovery_open()->bool:
	if not hero.is_on_floor():return false
	if not is_attacking():return true
	if mode=="finisher":return finisher_phase=="land" and finisher_ticks>=1
	if mode=="rotation":return rotation_ticks>=19
	if mode=="desperado_end":return elapsed>=1.0/Profile.HZ
	if mode not in ["fusion","lumina","counter","crosswise","desperado","tenderize_end"]:return false
	return elapsed+0.000001>=contact_end

func _recovery_exit()->bool:
	if not responsive_controls() or not recovery_open():return false
	var moving=hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back")
	if buffered_action.is_empty() and (not is_attacking() or moving.length_squared()<=.01):return false
	var method=buffered_action;var args=buffered_args
	var previous_mode=mode;var previous_combo=combo;var timer=combo_timer
	var connected=not hero.struck_targets.is_empty()
	# End only after the last contact sample; cancellation clears all pending cuts.
	cancel()
	if method=="attack":
		var heavy:bool=args[0]
		if heavy and previous_mode=="fusion" and previous_combo==0 and connected:start_technique("crosswise")
		elif heavy and previous_mode=="fusion" and previous_combo==1:start_technique("tenderize")
		elif not heavy and previous_mode=="crosswise":start_technique("desperado")
		elif heavy and previous_mode=="desperado":start_technique("desperado_dual")
		else:
			combo=previous_combo;combo_timer=timer;start_attack(heavy)
	elif method=="cast":hero.spell_loadout._cast.callv(args)
	elif not method.is_empty():callv(method,args)
	return true

func _ready():
	locomotion=preload("res://scripts/recovered_musashi_locomotion.gd").new(hero)
	assimilation=preload("res://scripts/recovered_musashi_assimilation.gd").new()
	assimilation.combat=self;assimilation.hero=hero;assimilation.game=game;add_child(assimilation)


func input(event: InputEvent):
	release_input(event)
	if not active or event.is_echo() or hero.dodge_time>0:return
	if responsive_controls() and (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack")):
		if buffer_action("attack",[event.is_action_pressed("heavy_attack")]):return
	if not combo_skill.is_empty() and (event.is_action("light_attack") or event.is_action("heavy_attack")):return
	if event is InputEventKey and event.pressed and not (event.ctrl_pressed or event.shift_pressed or event.alt_pressed or event.meta_pressed):
		var number=(event.physical_keycode if event.physical_keycode!=0 else event.keycode)-KEY_1+1
		if number in [3,4,5,6,7]:select_number(number);return
	if event is InputEventKey and (event.ctrl_pressed or event.shift_pressed or event.alt_pressed or event.meta_pressed) and (event.is_action("weapon_pipe") or event.is_action("weapon_coin")):return
	if event.is_action_pressed("weapon_pipe"):
		select_number(1)
	elif event.is_action_pressed("weapon_coin"):
		select_number(2)
	elif event.is_action_pressed("light_attack"):
		primary_held=true
		if mode=="crosswise" and hero.is_on_floor():start_technique("desperado")
		elif is_attacking():queued_primary=true
		else:primary_attack()
	elif event.is_action_pressed("heavy_attack"):
		if mode=="desperado":start_technique("desperado_dual")
		elif mode=="fusion" and combo==1 and hero.is_on_floor():start_technique("tenderize")
		elif is_attacking():
			queued_heavy=true
			_try_crosswise()
		elif charge>=Profile.CHARGE_LIMIT:start_rotation()
		else:start_attack(true)
	elif event.is_action_pressed("surge"):
		if not is_attacking():guard_held=true;guard_elapsed=0.0
	elif event.is_action_pressed("equip"):
		if not is_attacking():special_held=true;guard_elapsed=0.0

func select_number(number:int):
	if number!=7 and buffer_action("select_number",[number]):return
	if not active or not game.playing or game.paused or game.transitioning or hero.hp<=0 or hero.dodge_time>0 or is_attacking():return
	if number==1:start_rotation()
	elif number==2:start_counter()
	elif number in [3,4,5,6,7]:assimilation.start(number)

func release_input(event: InputEvent):
	if event is InputEventKey and (event.physical_keycode==KEY_7 or event.keycode==KEY_7) and not event.pressed and assimilation!=null:assimilation.held=false
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
	var model=cast_model()
	var airborne=not hero.is_on_floor()
	action_key=("air_lumina" if airborne else "lumina") if heavy else (("moving_air_fusion" if Vector2(hero.velocity.x,hero.velocity.z).length()>.25 else "air_fusion") if airborne else "fusion_%d"%(combo+1))
	cast_model().sword_trail.begin_action(action_key)
	if not heavy and not airborne and combo==3:
		mode="finisher";finisher_vertical=0;_finisher_phase("windup")
		guard_held=false;special_held=false;charge=0;charge_clock=0
		hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
		hero.attack_ticket=hero.attack_chain.begin("sword_4","primary_4")
		# Retail case4 calls 0x5F6 at initialization; 0x447 waits for apex.
		game.move_audio.release(game,hero.attack_ticket)
		cast_model().animate(0,0,true,0,1,false,4,false)
		return
	mode="lumina" if heavy else "fusion"
	clip=Profile.action(action_key).clip
	hero.attack_duration=Profile.duration(action_key)
	var window=Profile.window(action_key);contact_time=window[0];contact_end=window[1]
	hero.attack_left=hero.attack_duration
	guard_held=false;special_held=false;charge=0;charge_clock=0
	hero.facing=hero.combat_attack_direction()
	cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	hero.attack_ticket=hero.attack_chain.begin("heavy" if heavy else "sword_%d"%(combo+1),"heavy" if heavy else "primary_%d"%(combo+1))
	play_swing()
	cast_model().animate(0,0,hero.is_on_floor(),hero.velocity.y,1,heavy,combo+1,false)

func _try_crosswise()->bool:
	# Retail 55A44 requires a successful first Fusion contact. Buffer the host
	# mouse press through windup, but a miss remains an ordinary queued Lumina.
	if not queued_heavy or mode!="fusion" or combo!=0 or not hero.is_on_floor() or hero.struck_targets.is_empty():return false
	start_technique("crosswise")
	return true

func start_combo(key:String):
	if key in ["crosswise","tenderize","desperado"] and buffer_action("start_combo",[key]):return
	if key not in ["crosswise","tenderize","desperado"] or not active or not game.playing or game.paused or game.transitioning or hero.hp<=0 or hero.dodge_time>0 or not hero.is_on_floor() or is_attacking():return
	if spell_owner==null:hero.spell_loadout.interrupt()
	combo_skill=key;combo_timer=0;queued_primary=false;queued_heavy=false
	start_attack(false)

func start_leaping_strike():
	if not active or not game.playing or game.paused or game.transitioning or hero.hp<=0 or hero.dodge_time>0 or hero.is_on_floor() or is_attacking():return
	if spell_owner==null:hero.spell_loadout.interrupt()
	combo_skill="leaping-strike";mode="finisher";combo=3;combo_timer=0
	queued_primary=false;queued_heavy=false;primary_held=false
	guard_held=false;special_held=false;charge=0;charge_clock=0
	finisher_vertical=0;contact_done=false;swing_done=true
	hero.weapon_slot=1;hero.attack_heavy=false;hero.attack_charged=false;hero.combo=4
	hero.hit_done=false;hero.struck_targets.clear()
	hero.facing=hero.combat_attack_direction()
	locomotion.jumps_used=hero.jumps_used;locomotion.discard_jump_input()
	# Enter the recovered apex/downstroke; jumping remains the wearer's choice.
	_finisher_phase("hover")
	hero.attack_ticket=hero.attack_chain.begin("sword_4","primary_4")
	cast_model().sword_trail.begin_action("fusion_4_drop")
	cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	cast_model().animate(0,0,false,hero.velocity.y,1,false,4,false)
	game.sound("fusion_air_swing",.7,false,hero.attack_ticket,13)

func _advance_combo()->bool:
	if combo_skill.is_empty():return false
	if mode=="fusion" and combo==0 and combo_skill=="tenderize":
		if elapsed<hero.attack_duration:return false
		start_attack(false);return true
	if elapsed<contact_end:return false
	if mode=="fusion":start_technique("tenderize" if combo_skill=="tenderize" else "crosswise");return true
	if combo_skill=="desperado":
		if mode=="crosswise":start_technique("desperado");return true
		if mode=="desperado":start_technique("desperado_dual");return true
	return false

func start_technique(key:String):
	var continuing=key in ["tenderize_end","desperado_end"]
	if not continuing:technique_vertical=0
	mode=key;action_key=key;clip=Profile.action(key).clip
	elapsed=0;technique_ticks=0;contact_done=false;crosswise_impact_done=false
	if not continuing:queued_primary=false;queued_heavy=false
	combo_timer=0
	guard_held=false;special_held=false;charge=0;charge_clock=0
	hero.weapon_slot=1;hero.attack_heavy=key!="desperado";hero.attack_charged=false
	hero.hit_done=false;hero.struck_targets.clear()
	hero.attack_duration=Profile.duration(key);hero.attack_left=hero.attack_duration
	var window=Profile.window(key);contact_time=window[0];contact_end=window[1]
	if key=="desperado_dual":contact_end=INF
	hero.attack_ticket=hero.attack_chain.begin("musashi_"+key,key)
	if not continuing:
		cast_model().sword_trail.begin_action(key)
		if key=="desperado_dual":cast_model().dual_sword_trail.begin_action("desperado_fusion")
		game.sound("move_primary_2_weapon" if key=="desperado" else "heavy_swing",.7,false,hero.attack_ticket,13)
	elif key=="tenderize_end":game.sound("heavy_swing",.7,false,hero.attack_ticket,13)
	cast_model().animate(0,0,hero.is_on_floor(),hero.velocity.y,1,hero.attack_heavy,hero.combo,false)

func _technique_tick()->Vector3:
	technique_ticks+=1;elapsed=technique_ticks/Profile.HZ
	hero.attack_left=maxf(.000001,hero.attack_duration-elapsed)
	if mode in ["tenderize","desperado_dual"] and technique_ticks==8:
		technique_vertical=-12 if mode=="tenderize" else -6
	var moving=mode=="tenderize_end" or (mode in ["tenderize","desperado_dual"] and technique_ticks>=8)
	var travel=Vector3.ZERO
	if moving:
		technique_vertical+=1
		travel=Vector3.UP*(-technique_vertical*locomotion.source_world_scale()*Profile.HZ)
		if mode=="desperado_dual":travel+=hero.facing*12*locomotion.source_world_scale()*Profile.HZ
	if elapsed>=contact_time and elapsed<contact_end:
		contact_done=true;strike()
	if _recovery_exit():return Vector3.ZERO
	if mode=="tenderize" and technique_ticks>=18:start_technique("tenderize_end")
	elif mode=="tenderize_end" and technique_ticks>=17:
		clip="";mode="";combo_skill="";hero.attack_left=0
		if queued_heavy:queued_heavy=false;start_attack(true)
		elif queued_primary or (spell_owner==null and hero.auto_attack_running()):queued_primary=false;primary_attack()
	return travel

func start_rotation():
	_start_lumina_special("rotation")
func start_counter():
	_start_lumina_special("counter")
func _start_lumina_special(key:String):
	if buffer_action("start_rotation" if key=="rotation" else "start_counter"):return
	var charged_cast=charge>=Profile.CHARGE_LIMIT
	if not active or is_attacking() or not hero.is_on_floor():
		charge=0;charge_clock=0
		return
	if spell_owner==null:hero.spell_loadout.interrupt()
	guard_held=false;special_held=false;charge=0;charge_clock=0
	hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	mode=key;action_key=key;clip=Profile.action(action_key).clip
	elapsed=0;contact_done=false;swing_done=false;queued_primary=false;queued_heavy=false
	hero.weapon_slot=1;hero.attack_heavy=true;hero.attack_charged=false
	hero.hit_done=false;hero.struck_targets.clear()
	hero.attack_duration=23.0/30.0 if key=="rotation" else Profile.duration(action_key);hero.attack_left=hero.attack_duration
	var window=Profile.window(action_key);contact_time=8.0/30.0 if key=="rotation" else window[0];contact_end=19.0/30.0 if key=="rotation" else window[1]
	hero.attack_ticket=hero.attack_chain.begin("musashi_"+key,key)
	if key=="rotation" and charged_cast:preload("res://scripts/spells/skill_balance.gd").decorate(hero,hero.attack_ticket,"musashi_charge")
	rotation_clock=0;rotation_ticks=0;rotation_angle=0;rotation_previous_angle=0;rotation_speed=256;rotation_phase="windup" if key=="rotation" else ""
	cast_model().sword_trail.begin_action(key);cast_model().animate(0,0,true,0,1,true,1,false)
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
			contact_done=true;strike()
		elif rotation_ticks==19:
			rotation_phase="recovery";rotation_angle=0;action_key="rotation_end";clip=Profile.action(action_key).clip;elapsed=0
		else:
			elapsed=(rotation_ticks-19)/30.0
			if rotation_ticks>=23:
				clip="";mode="";rotation_phase="";hero.attack_left=0
				if queued_heavy:queued_heavy=false;start_attack(true)
				elif queued_primary or (spell_owner==null and hero.auto_attack_running()):queued_primary=false;primary_attack()
		if _recovery_exit():return

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
	buffer_left=maxf(0,buffer_left-delta)
	if buffer_left<=0 and not buffered_action.is_empty():buffered_action="";buffered_args=[]
	if not is_attacking() and _recovery_exit():return
	if controls_motion():return # The locomotion source clock advances these states.
	if mode=="assimilation":
		assimilation.tick(delta);_recovery_exit();return
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
			cast_model().rotation_effect.spawn(cast_model().rig_visual.global_transform,SKILL_SCALE*skill_factor("size"))
		if elapsed>=contact_time and before<contact_end:
			contact_done=true
			var after=elapsed
			elapsed=clampf(maxf(before,contact_time),contact_time,contact_end-.00001)
			contact_until=minf(after,contact_end-.00001)
			strike()
			contact_until=-1.0
			elapsed=after
			if _try_crosswise():return
		if _recovery_exit():return
		if _advance_combo():return
		if hero.attack_left<=0:
			clip="";mode="";combo_skill=""
			if queued_heavy:
				queued_heavy=false;start_attack(true)
			elif queued_primary or (spell_owner==null and hero.auto_attack_running()):queued_primary=false;primary_attack()
	elif (spell_owner==null and hero.auto_attack_running()):primary_attack()

func is_attacking()->bool:return not clip.is_empty()
func controls_motion()->bool:return (mode=="finisher" and not finisher_phase.is_empty()) or (mode=="assimilation" and action_key=="dkick") or mode in ["tenderize","tenderize_end","desperado_dual"]
func _finisher_phase(phase:String):
	finisher_phase=phase;finisher_ticks=0;elapsed=0
	action_key=FINISHER_PHASES[phase];clip=Profile.action(action_key).clip
	hero.attack_duration=Profile.duration(action_key);hero.attack_left=hero.attack_duration
	contact_time=0;contact_end=INF if phase=="drop" else 0
func source_motion_tick()->Vector3:
	if not controls_motion():return Vector3.ZERO
	if mode=="assimilation":return assimilation.motion_tick()
	if mode in ["tenderize","tenderize_end","desperado_dual"]:return _technique_tick()
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
			contact_done=true;strike()
			return Vector3.UP*(-finisher_vertical*locomotion.source_world_scale()*Profile.HZ)
		"land":
			if _recovery_exit():return Vector3.ZERO
			if finisher_ticks>=5:
				clip="";mode="";finisher_phase="";combo_skill="";hero.attack_left=0;combo_timer=0
				if queued_heavy:queued_heavy=false;start_attack(true)
				elif queued_primary or (spell_owner==null and hero.auto_attack_running()):queued_primary=false;primary_attack()
	return Vector3.ZERO
func after_source_motion(grounded:bool,ceiling:bool):
	if not controls_motion():return
	if mode in ["tenderize","tenderize_end","desperado_dual"]:
		if ceiling:technique_vertical=maxi(0,technique_vertical)
		if grounded and technique_vertical>=0:
			technique_vertical=0
			if mode=="desperado_dual" and technique_ticks>=8:start_technique("desperado_end")
		return
	if mode=="assimilation":
		if grounded and assimilation.kick_vertical>=0:assimilation.finish()
		elif ceiling:assimilation.kick_vertical=maxi(0,assimilation.kick_vertical)
		return
	if grounded and finisher_phase=="drop":_finisher_phase("land")
	elif ceiling and finisher_phase=="rise":
		finisher_vertical=0;_finisher_phase("hover")
func play_swing():
	swing_done=true
	game.sound("heavy_swing" if hero.attack_heavy else "swing",.7,false,hero.attack_ticket,hero.character_id)
func trail_active()->bool:
	if mode in ["tenderize","tenderize_end","desperado_dual"]:return elapsed>=contact_time and elapsed<contact_end
	if controls_motion():return finisher_phase=="drop"
	return is_attacking() and ((mode=="rotation" and rotation_phase=="spin") or (elapsed>=contact_time and elapsed<contact_end))
func lumina_scale_factor()->float:
	if mode=="counter":return 0x19EB/4096.0*SKILL_SCALE*skill_factor("size")
	if mode=="rotation":return (4096+int(mini(rotation_ticks,7)*1024.0/7.0))/4096.0*SKILL_SCALE*skill_factor("size")
	return 1.0
func can_hit_target(enemy: Ninja)->bool:
	if mode=="counter":return true
	if mode=="rotation":
		if rotation_phase!="spin":return false
		var unit=cast_model().rig_visual.global_basis.get_scale().x*.01
		var center=hero.global_position+Vector3.UP*30*unit
		var reach=82*unit*SKILL_SCALE*skill_factor("hit_area")
		var radius=.25*unit/locomotion.WORLD_SCALE*SKILL_SCALE*skill_factor("hit_area")
		if center.distance_to(AttackChain.aim_point(enemy,center))>reach+radius:return false
		# Sweep the whole enlarged blade so close targets do not fall inside a hollow tip arc.
		var steps=maxi(1,ceili((rotation_angle-rotation_previous_angle)*TAU/4096.0*reach/radius))
		for step in steps+1:
			var angle=lerpf(rotation_previous_angle,rotation_angle,float(step)/steps)
			var tip=center+hero.facing.rotated(Vector3.UP,-angle*TAU/4096.0)*reach
			if not AttackChain.segment_contact(enemy,center,tip,radius).is_empty():return true
		return false
	for segment in contact_segments:
		if not AttackChain.segment_contact(enemy,segment[0],segment[1],.25*hero.contact_size_multiplier()*skill_factor("hit_area")).is_empty():return true
	return false

func blade_reach(heavy:bool)->float:
	return (2.1 if heavy else 1.8)*hero.contact_size_multiplier()*hero.pickup_multiplier("range")*hero.melee_reach_setting()

func blade_segment(key:String,at:float)->PackedVector3Array:
	var pair=cast_model().sword_trail.pose_segment(key,at,cast_model().rig_visual.global_transform)
	return cast_model().sword_trail.wave_segment(pair,hero.global_position,blade_reach(hero.attack_heavy)*skill_factor("hit_area"))

func trace_blade(key:String,from:float,until:float):
	var previous=blade_segment(key,from)
	if previous.size()!=2:return
	contact_segments.append(previous)
	for tick in range(floori(from*Profile.HZ)+1,ceili(until*Profile.HZ)+1):
		var current=blade_segment(key,minf(float(tick)/Profile.HZ,until))
		var travel=maxf(previous[0].distance_to(current[0]),previous[1].distance_to(current[1]))
		var count=maxi(1,ceili(travel/(.25*hero.contact_size_multiplier())))
		for step in range(1,count+1):
			contact_segments.append(PackedVector3Array([previous[0].lerp(current[0],float(step)/count),previous[1].lerp(current[1],float(step)/count)]))
		previous=current
func blocks_movement()->bool:return false
func protects_player()->bool:return false
func cancel(_preserve_power: bool=false):
	buffered_action="";buffered_args=[];buffer_left=0
	if assimilation!=null:assimilation.cancel()
	primary_held=false;queued_heavy=false;queued_primary=false;clip="";mode="";elapsed=0;combo_timer=0
	guard_held=false;special_held=false;charge=0;charge_clock=0;guard_elapsed=0
	finisher_phase="";finisher_ticks=0;finisher_vertical=0
	technique_ticks=0;technique_vertical=0;crosswise_impact_done=false
	combo_skill=""
	rotation_clock=0;rotation_ticks=0;rotation_angle=0;rotation_previous_angle=0;rotation_speed=256;rotation_phase=""
	if locomotion!=null:locomotion.discard_jump_input()
	contact_segments.clear();contact_until=-1.0
	if is_instance_valid(hero):hero.attack_left=0
	if is_instance_valid(hero):
		var model=spell_owner.source_model if spell_owner!=null else hero.character_models.get(13)
		if is_instance_valid(model):
			if is_instance_valid(model.sword_trail):model.sword_trail.clear()
			if is_instance_valid(model.rotation_effect):model.rotation_effect.clear()
			model.dual_sword_trail.clear();model.crosswise_effect.clear()
func hit():cancel()
func interrupt_for_dodge():cancel()

func strike():
	contact_segments.clear()
	if mode not in ["rotation","counter"]:
		for key in ([action_key,"desperado_fusion"] if mode=="desperado_dual" else [action_key]):
			trace_blade(key,maxf(contact_time,elapsed-1.0/Profile.HZ) if contact_until<0 else elapsed,maxf(elapsed,contact_until))
	var impact_targets=AttackChain.enemy_candidates(game,hero.global_position,hero.melee_strike_reach()+3.5*hero.contact_size_multiplier()) if mode=="crosswise" and not crosswise_impact_done else []
	if spell_owner!=null:spell_owner.strike(self)
	else:hero.strike()
	if mode=="crosswise" and not crosswise_impact_done and not hero.struck_targets.is_empty():
		crosswise_impact_done=true
		# Use the existing local query; never traverse the whole army for an effect.
		for enemy in impact_targets:
			if is_instance_valid(enemy) and hero.struck_targets.has(enemy.get_instance_id()):
				var model=cast_model()
				model.crosswise_effect.spawn(AttackChain.aim_point(enemy,hero.global_position+Vector3.UP*hero.contact_size_multiplier()),model.rig_visual.global_basis.get_scale().x*skill_factor("size"))
				break
