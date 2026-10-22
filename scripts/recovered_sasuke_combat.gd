extends Node
## Recovered Sasuke action clocks and source visual sweeps. Controls, enemy
## damage/freeze amounts and collision response adapt the native kit to this game.
const Profile=preload("res://scripts/recovered_sasuke_combat_profile.gd")
const Projectile=preload("res://scripts/recovered_sasuke_projectile.gd")
const ChargeFX=preload("res://scripts/recovered_goemon_charge_vfx.gd")
var hero: Hero
var game: Node
var active=false:
	set(value):
		active=value
		if not value:cancel()
var primary_held=false
var ice_held=false
var queued_primary=false
var queued_bomb=false
var elapsed=0.0
var action_id=0
var mode=""
var combo=0
var combo_timer=0.0
var contact_done=false
var cue_done=false
var charge_cue_done=false
var charge_fx: Node3D
var jetpack_voice: AudioStreamPlayer
var jetpack_voice_order=-1
var next_charge_sound=1.5
var charge_sustain_count=0
var generation=0
var launch_clock=0.0
var launch_velocity=0.0
var launch_started=false
var pending_from=-1.0
var pending_until=-1.0
var previous_root=Transform3D.IDENTITY
var have_previous_root=false
var cached_reach_scale=-1.0
var cached_melee_reach=3.3

func _notification(what: int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:cancel()
func input(event: InputEvent):
	release_input(event)
	if not active or event.is_echo() or hero.dodge_time>0:return
	if event.is_action_pressed("light_attack"):
		primary_held=true;ice_held=false
		if mode=="ice_charge":finish_attack()
		if is_attacking():queued_primary=true
		else:primary_attack()
	elif event.is_action_pressed("heavy_attack"):
		primary_held=false;ice_held=false
		if mode=="ice_charge":finish_attack()
		if is_attacking():queued_bomb=true
		else:start_bomb()
	elif event.is_action_pressed("equip"):
		cancel();ice_held=true;_begin("ice_charge",0)
		_ensure_charge_effect()
	elif event.is_action_pressed("sky_strike"):
		var forward=(event is InputEventWithModifiers and event.shift_pressed) or Input.is_action_pressed("sprint")
		cancel();start_hair(forward)
	elif event.is_action_pressed("surge"):
		cancel();start_super_jump()
func release_input(event: InputEvent):
	if event.is_action_released("light_attack"):primary_held=false
	if event.is_action_released("equip"):
		ice_held=false
		if mode=="ice_charge":
			var charged=elapsed>=Profile.CHARGE_SECONDS
			finish_attack();start_ice(charged)
func primary_attack():
	if not active or is_attacking() or hero.dodge_time>0:return
	combo=0 if combo_timer<=0 else (combo+1)%3
	combo_timer=1.0
	_begin("primary",Profile.combo_actions()[combo] if hero.is_on_floor() else 0x6e)
	_release_voice("move_primary_%d_voice"%(combo+1))
func start_bomb():_begin("bomb",0x90 if hero.is_on_floor() else 0x91)
func start_ice(charged: bool=false):_begin("hail" if charged else "ice",(0x97 if charged else 0x93) if hero.is_on_floor() else (0x98 if charged else 0x95))
func start_hair(forward: bool=false):
	_begin("hair_forward" if forward else "hair_up",0x6f if forward else 0x9a)
	_sound("sasuke_hair_forward" if forward else "sasuke_hair_up")
func start_super_jump():
	_begin("super_jump",0x9b)
	launch_clock=0;launch_velocity=24.0;launch_started=false
	hero.jump_buffer=0;hero.jump_windup=0;hero.coyote=0;hero.jumps_used=1
	hero.velocity.y=launch_velocity
	_sound("sasuke_super_jump")
	jetpack_voice=game.get("last_sound_voice")
	if is_instance_valid(jetpack_voice):jetpack_voice_order=jetpack_voice.get_meta("order",-1)
func _begin(kind: String,action: int):
	mode=kind;action_id=action;elapsed=0;contact_done=false;cue_done=false
	charge_cue_done=false;next_charge_sound=1.5;charge_sustain_count=0;pending_from=-1;pending_until=-1;have_previous_root=false
	hero.weapon_slot=1;hero.attack_heavy=kind in ["bomb","hair_up","hair_forward"];hero.attack_charged=kind=="hail"
	hero.combo=combo+1;hero.hit_done=false;hero.struck_targets.clear()
	hero.attack_duration=Profile.duration(action_id)
	if kind in ["ice_charge","super_jump"]:hero.attack_duration=Profile.CHARGE_SECONDS
	hero.attack_left=maxf(.05,hero.attack_duration)
	hero.facing=hero.combat_attack_direction()
	if is_instance_valid(hero.model):hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	if hero.attack_chain!=null:hero.attack_ticket=hero.attack_chain.begin("sasuke_"+kind,_move_key(kind))
	else:hero.attack_ticket={"source_hero":weakref(hero),"action":"sasuke_"+kind,"allied":hero.ai_controlled,"chain_enabled":false}
func tick_timers(delta: float):combo_timer=maxf(0,combo_timer-delta)
func tick(delta: float,after_pose: bool=false):
	if not active:return
	if game.paused or game.transitioning or not game.playing:
		if is_attacking() or primary_held or ice_held:cancel()
		return
	if after_pose:
		if pending_from>=0 and mode in ["primary","hair_up","hair_forward"]:
			_sweep(pending_from,pending_until)
			pending_from=-1;pending_until=-1
		return
	if mode=="hurt":
		elapsed+=delta
		if elapsed>=Profile.duration(action_id):finish_attack()
		return
	if not is_attacking():
		if primary_held or hero.auto_attack_running():primary_attack()
		return
	var previous=elapsed
	elapsed+=delta*hero.attack_speed_multiplier()
	if mode=="ice_charge":
		hero.attack_left=.05
		if is_instance_valid(charge_fx):charge_fx.set_charge_time(elapsed)
		if not charge_cue_done and elapsed>=.5:
			charge_cue_done=true;_sound("sasuke_ice_charge")
		while elapsed>=next_charge_sound:
			_sound("sasuke_ice_charge_a" if charge_sustain_count%2==0 else "sasuke_ice_charge_b")
			charge_sustain_count+=1;next_charge_sound+=1.0
		return
	if mode=="super_jump":
		launch_clock+=delta
		hero.attack_left=.05
		if launch_clock>.08 and not hero.is_on_floor():launch_started=true
		if (launch_started and hero.is_on_floor() and launch_clock>.2) or launch_clock>3.5:
			finish_attack()
		return
	hero.attack_left=maxf(.05,Profile.duration(action_id)-elapsed)
	if mode=="primary" and not cue_done and elapsed>=Profile.cue_time(combo):
		cue_done=true;_sound("sasuke_kunai_%d"%(combo+1))
	if mode in ["bomb","ice","hail"] and not contact_done:
		var release_at=Profile.release_time(mode)
		if action_id==0x98:release_at=8.0/30.0
		if elapsed>=release_at:
			contact_done=true;_release_projectiles();_sound("sasuke_"+mode)
	if mode in ["primary","hair_up","hair_forward"]:
		# Supersample source poses at120Hz; a long game frame cannot skip the blade.
		pending_from=previous;pending_until=minf(elapsed,Profile.duration(action_id))
	if elapsed+0.000001>=Profile.duration(action_id):
		if pending_from>=0:_sweep(pending_from,pending_until);pending_from=-1;pending_until=-1
		if mode=="primary" and action_id in Profile.combo_actions():
			if (primary_held or queued_primary or hero.auto_attack_running()) and combo<2:
				queued_primary=false;finish_attack();primary_attack();return
			action_id=0x6b+combo;mode="recovery";elapsed=0;hero.attack_duration=Profile.duration(action_id);return
		if mode in ["ice","hail"] and action_id in [0x93,0x97]:
			action_id=0x94;mode="recovery";elapsed=0;hero.attack_duration=Profile.duration(action_id);return
		finish_attack()
		if queued_bomb:queued_bomb=false;start_bomb()
		elif queued_primary or primary_held or hero.auto_attack_running():queued_primary=false;primary_attack()
func _release_projectiles():
	var count=3 if mode=="hail" else 1
	var alive=0
	for shot in get_tree().get_nodes_in_group("sasuke_projectiles"):
		if shot.hero==hero and shot.kind==mode and not shot.resolved and not shot.is_queued_for_deletion():alive+=1
	if alive>=3:return
	count=mini(count,3-alive)
	for index in count:
		var p=Projectile.new();p.hero=hero;p.game=game;p.kind=mode;p.attack_ticket=hero.attack_ticket
		p.damage_scale=hero.damage_multiplier()
		var native_scale=.01515809
		if is_instance_valid(hero.model) and hero.model.get("source_scale")!=null:native_scale=hero.model.source_scale
		var direction=hero.facing
		if mode=="hail":direction=direction.rotated(Vector3.UP,float(index-1)*TAU*64.0/1024.0)
		p.position=hero.global_position+Vector3.UP*(80.0*native_scale)+hero.facing*(50.0*native_scale)
		p.velocity=direction*(8.0*30.0*native_scale)
		if mode=="bomb":
			p.position=hero.global_position+Vector3.UP*(75*native_scale)+hero.facing*.5
			p.velocity=hero.velocity+hero.facing*(3.0*30.0*native_scale)+Vector3.UP*(5.0*30.0*native_scale)
			p.bomb_gravity=(2.0/3.0)*30.0*30.0*native_scale
		game.add_child(p)
func _sweep(from: float,until: float):
	if not is_instance_valid(hero.model) or until<from:return
	var source: Dictionary=Profile.data().get("collision_spheres",{}).get(str(action_id),{})
	if source.is_empty():return
	var model=hero.model
	var root_now=model.global_transform
	if not have_previous_root:previous_root=root_now;have_previous_root=true
	var count=clampi(ceili((until-from)*120.0),1,128)
	var previous_spheres=_source_spheres(source,from,previous_root)
	var scored=false
	for step in range(count+1):
		var fraction=float(step)/count
		var at=lerpf(from,until,fraction)
		var root_at=previous_root.interpolate_with(root_now,fraction)
		var spheres=_source_spheres(source,at,root_at)
		for index in spheres.size():
			var old: Dictionary=previous_spheres[index]
			var sphere: Dictionary=spheres[index]
			var radius=maxf(float(old.radius),float(sphere.radius))
			if radius<=.00001:continue
			if _contact_segment(old.center,sphere.center,radius):scored=true
		previous_spheres=spheres
	previous_root=root_now
	if scored and not hero.ai_controlled:game.chain+=1;game.chain_timer=3.0
func _source_spheres(source: Dictionary,at: float,root_at: Transform3D)->Array:
	var frame=clampf(at*30.0*Profile.rate(action_id),0,float(source.frame_count)-1.0)
	var first=floori(frame);var second=mini(first+1,int(source.frame_count)-1);var weight=frame-first
	var result=[]
	var model=hero.model
	var reach=reach_scale()
	var pose: Dictionary=model.sampler.sample_source(action_id,at) if not is_equal_approx(reach,1.0) else {}
	for index in int(source.count):
		var a: Dictionary=source.frames[first][index];var b: Dictionary=source.frames[second][index]
		var center_a=Vector3(a.center[0],a.center[1],a.center[2])
		var center_b=Vector3(b.center[0],b.center[1],b.center[2])
		var center=center_a.lerp(center_b,weight)
		if not pose.is_empty():
			var pointer="0x90063d8" if mode in ["hair_up","hair_forward"] else ("0x9002aa8" if index<3 else "0x9002bc8")
			if pose.has(pointer):
				var anchor: Vector3=pose[pointer].origin
				center=anchor+(center-anchor)*reach
		center=center*model.source_scale+model.source_offset
		center=root_at*(model.rig_visual.transform*center)
		var radius=lerpf(float(a.radius),float(b.radius),weight)*model.source_scale*root_at.basis.get_scale().abs().length()/sqrt(3.0)*reach
		result.append({"center":center,"radius":maxf(0,radius)})
	return result
func _contact_segment(from: Vector3,to: Vector3,radius: float)->bool:
	var scored=false
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or hero.struck_targets.has(enemy.get_instance_id()):continue
		var contact=AttackChain.segment_contact(enemy,from,to,radius)
		if contact.is_empty():continue
		var point: Vector3=contact.point
		if not _clear_line(point):continue
		hero.struck_targets[enemy.get_instance_id()]=true;hero.hit_done=true
		var direction=(point-hero.global_position).normalized()
		var amount=34.0 if mode in ["hair_up","hair_forward"] else (30.0 if combo==2 else 22.0)
		enemy.take_hit(amount*hero.damage_multiplier(),direction,mode!="primary" or combo==2,hero.attack_ticket)
		if hero.ai_controlled:game.confirm_ally_impact(enemy,point,direction,2 if combo==2 or mode!="primary" else 0,false,16)
		else:game.confirm_impact(enemy,point,direction,2 if combo==2 or mode!="primary" else 0,false,16)
		_sound("sasuke_hair_impact" if mode in ["hair_up","hair_forward"] else "sasuke_kunai_impact");scored=true
	return scored
func _clear_line(point: Vector3)->bool:
	var ray=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*1.1*hero.growth_multiplier(),point,1)
	ray.exclude=[hero.get_rid()]
	return hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func _ensure_charge_effect():
	if is_instance_valid(hero.model) and hero.model.get("rig_visual")!=null:
		charge_fx=ChargeFX.create(hero.model.rig_visual,hero.model.source_scale,hero.model.source_offset)
func _move_key(kind: String)->String:
	return {"primary":"primary_%d"%(combo+1),"bomb":"secondary","ice_charge":"utility","ice":"utility","hail":"ice_charged","hair_up":"hair_up","hair_forward":"hair_forward","super_jump":"skill"}.get(kind,kind)
func _release_voice(fallback: String):
	if game.get("move_audio")!=null:game.move_audio.release(game,hero.attack_ticket)
	else:_sound(fallback)
func _sound(slot: String):game.sound(slot,.7,false,hero.attack_ticket,16)
func is_attacking()->bool:return not mode.is_empty() and mode not in ["hurt","dead"]
func pose_active()->bool:return not mode.is_empty()
func blocks_movement()->bool:return false
func protects_player()->bool:return false
func can_hit_target(_enemy: Ninja)->bool:return false # Contact belongs to the native weapon sweep.
func ground_attack_velocity()->Vector3:
	return Vector3.ZERO if mode in ["primary","hair_up","hair_forward","ice_charge","ice","hail","bomb"] and hero.is_on_floor() else Vector3.INF
func reach_scale()->float:
	if not is_instance_valid(hero) or not is_instance_valid(game) or game.get("tuning")==null:return 1.0
	return hero.pickup_multiplier("range")*hero.melee_reach_setting()
func melee_reach()->float:
	var reach=reach_scale()
	if not is_equal_approx(reach,cached_reach_scale) and is_instance_valid(hero.model):
		var maximum=0.0
		for attack in Profile.combo_actions():
			var source: Dictionary=Profile.data().collision_spheres[str(attack)]
			for frame in int(source.frame_count):
				var pose: Dictionary=hero.model.sampler.sample_source(attack,float(frame)/(30.0*Profile.rate(attack)))
				for index in int(source.count):
					var sphere: Dictionary=source.frames[frame][index]
					var pointer="0x9002aa8" if index<3 else "0x9002bc8"
					var anchor: Vector3=pose[pointer].origin
					var center=Vector3(sphere.center[0],sphere.center[1],sphere.center[2])
					center=anchor+(center-anchor)*reach
					maximum=maxf(maximum,(center.z+float(sphere.radius)*reach)*hero.model.source_scale)
		cached_reach_scale=reach;cached_melee_reach=maximum*.9
	return cached_melee_reach*hero.growth_multiplier()
func controls_vertical_motion()->bool:return mode=="super_jump"
func vertical_velocity(delta: float)->float:
	# Integrate through CharacterBody3D.move_and_slide so ceilings and floors
	# constrain the native jetpack pose; never teleport through a ceiling.
	launch_velocity=maxf(-30,launch_velocity-30.0*delta)
	if hero.is_on_ceiling():launch_velocity=minf(0,launch_velocity)
	return launch_velocity
func finish_attack():
	if is_instance_valid(charge_fx):charge_fx.queue_free()
	charge_fx=null
	if is_instance_valid(jetpack_voice) and jetpack_voice.get_meta("order",-1)==jetpack_voice_order and jetpack_voice.get_meta("kind","")=="sasuke_super_jump":jetpack_voice.stop()
	jetpack_voice=null
	mode="";elapsed=0;action_id=0;pending_from=-1;pending_until=-1
	if is_instance_valid(hero):hero.attack_left=0
func cancel(_preserve_power: bool=false):
	generation+=1;primary_held=false;ice_held=false;queued_primary=false;queued_bomb=false
	combo_timer=0;combo=0;finish_attack()
func hit():
	cancel();mode="hurt";action_id=0x1d;elapsed=0
func die():
	cancel();mode="dead";action_id=0x2d;elapsed=Profile.duration(action_id)
	if is_instance_valid(hero.model):hero.model.apply_native_pose(action_id,elapsed)
func interrupt_for_dodge():cancel()
