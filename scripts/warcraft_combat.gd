extends "res://scripts/character_combat.gd"
## One player kit, native local contacts, and the existing projectile lease owner.
const Kit=preload("res://scripts/warcraft_kit.gd")
const Effects=preload("res://scripts/warcraft_effects.gd")
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/warcraft_projectile.gd")
var wind_left=0.0
var wind_cooldown=0.0
var mirror_cooldown=0.0
var immolating=false
var burn_clock=0.0
var burn_ticket={}
var effects:Node3D
var mirrors:RefCounted
var wind_geometry:Array=[]
var mode=""
var clip=""
var elapsed=0.0
var duration=0.0
var contact=0.0
var next_pulse=0.0
var next_sound=0.0
var combo=-1
var combo_timer=0.0
var cooldown=0.0
var demon=false
var released=false
var queued=false
var ticket={}
var primary_held=false

func prepare_projectiles():
	if effects==null:
		effects=Effects.new();effects.character=source_id();hero.model.add_child(effects)
		wind_geometry=hero.model.find_children("*","GeometryInstance3D",true,false)
	if mirrors==null and source_id()==31 and not hero.mirror_copy and (spell_owner==null or spell_owner.spec.method=="start_mirrors"):mirrors=Mirrors.new(hero)
	# Four-second flight plus impact playback at the default maximum chain rate.
	if source_id()==32:Pool.service(game).warm(hero,Shot,"demon",{},24)

func input(event:InputEvent):
	release_input(event)
	if not active or event.is_echo() or hero.dodge_time>0:return
	if event.is_action_pressed("light_attack"):
		if hero.is_meta_shooter():primary_held=true
		if mode=="attack":queued=true
		elif not is_attacking():start_attack()
	elif event.is_action_pressed("heavy_attack"):
		if source_id()==31:start_attack(true)
		else:start_morph()
	elif event.is_action_pressed("surge"):
		if source_id()==31:start_wind()
		else:toggle_immolation()
	elif event.is_action_pressed("sky_strike") and source_id()==31:start_mirrors()
	elif event.is_action_pressed("equip"):
		if source_id()==31:start_spin()
		else:start_morph()

func release_input(event:InputEvent):
	if event.is_action_released("light_attack"):primary_held=false

func begin(action:String,name_:String):
	mode=action;clip=name_;elapsed=0;released=false;queued=false
	duration=cast_model().animation_player.get_animation(clip).length
	hero.facing=Vector3.FORWARD.rotated(Vector3.UP,game.camera_rig.yaw) if hero.is_meta_shooter() else hero.combat_attack_direction()
	cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	ticket=hero.attack_chain.begin("warcraft_"+action,"primary_%d"%(combo+1) if action=="attack" else action)
	hero.attack_ticket=ticket;hero.attack_duration=duration;hero.attack_left=duration

func start_attack(heavy:bool=false):
	if is_attacking() or hero.hp<=0:return
	combo=2 if heavy else 0 if combo_timer<=0 else (combo+1)%(3 if source_id()==31 else 2)
	begin("attack",("Attack Alternate" if demon else ["Attack","Attack 2","Attack Slam"][combo]))
	hero.combo=combo+1;contact=.733 if combo==2 else .26 if source_id()==32 else .33
	if not demon and combo!=2:sound("wc_attack_%d"%(combo+1))

func start_spin():
	if is_attacking() or cooldown>0 or hero.hp<=0:return
	begin("spin","Attack Walk Stand Spin");duration=Kit.SPIN_TIME;next_pulse=Kit.SPIN_INTERVAL;next_sound=.846;cooldown=8;sound("wc_spin");effects.emitters.spin.scale=Vector3.ONE*skill_factor("size",ticket);effects.spin(true)

func other_kits()->Array:
	var kits=[hero.active_ability]
	for key in hero.spell_loadout.instances:
		if key.begins_with("%d:"%hero.character_id):kits.append(hero.spell_loadout.instances[key].controller)
	return kits.filter(func(c):return is_instance_valid(c) and c!=self and c.has_method("consume_wind"))

func start_wind():
	if is_attacking() or wind_cooldown>0 or hero.hp<=0:return
	if other_kits().any(func(c):return c.wind_left>0):return
	wind_left=Kit.WIND_TIME;wind_cooldown=Kit.WIND_COOLDOWN;sound("wc_wind")
	set_wind_visual(true)
func consume_wind(action:String)->bool:
	if wind_left<=0 or action in ["warcraft_wind","warcraft_mirrors","warcraft_immolation"]:return false
	wind_left=0;set_wind_visual(false);return true
func set_wind_visual(enabled:bool):
	for mesh in wind_geometry:
		if is_instance_valid(mesh):mesh.transparency=.72 if enabled else 0.0
	if is_instance_valid(effects):effects.wind(enabled)
func start_mirrors():
	if hero.mirror_copy:return
	if is_attacking() or mirror_cooldown>0 or hero.hp<=0:return
	if other_kits().any(func(c):return c.mirrors!=null and c.mirrors.left>0):return
	if not mirrors.cast():game.toast("Mirror Image needs clear ground for five allies");return
	begin("mirrors","Stand Ready");duration=.5;mirror_cooldown=Kit.MIRROR_COOLDOWN;sound("wc_mirror")
	effects.mirror()
func toggle_immolation():
	if hero.hp<=0:return
	for c in other_kits():
		if c.immolating:c.toggle_immolation();return
	immolating=not immolating;burn_clock=0
	if immolating:burn_ticket=hero.attack_chain.begin("warcraft_immolation","immolation")
	else:burn_ticket={}
	if immolating:effects.emitters.immolation.scale=Vector3.ONE*skill_factor("size",burn_ticket)
	effects.immolation(immolating);sound("wc_immolation" if immolating else "wc_immolation_end")
func burn():
	var origin=hero.global_position+Vector3.UP*1.2
	var reach=skill_factor("hit_area",burn_ticket)*Kit.IMMOLATION_RADIUS*hero.contact_size_multiplier()*hero.pickup_multiplier("range")
	for enemy in AttackChain.enemy_candidates(game,origin,reach+2):
		if not is_instance_valid(enemy) or enemy.dead:continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		var target=AttackChain.aim_point(enemy,origin)
		var hit=AttackChain.segment_contact(enemy,origin,origin,reach)
		if hit.is_empty() or not AttackChain.clear_line(hero,origin,target):continue
		enemy.take_hit(Kit.IMMOLATION_DAMAGE*hero.damage_multiplier(),(target-origin).normalized(),false,burn_ticket)
		if is_instance_valid(game.get("crowd")) and is_instance_valid(game.crowd.army):game.crowd.army.presentation.add_effect("spark",hit.point,.35,.5)

func start_morph():
	# Native AI may choose either toggle again; keep Meta and spend the action firing.
	if hero.ai_controlled and demon:
		start_attack();return
	if is_attacking() or cooldown>0 or hero.hp<=0:return
	primary_held=false
	begin("morph","Morph Alternate" if demon else "Morph");cooldown=2;sound("wc_morph")

func tick_timers(delta:float):
	combo_timer=maxf(0,combo_timer-delta);cooldown=maxf(0,cooldown-delta)
	wind_cooldown=maxf(0,wind_cooldown-delta);mirror_cooldown=maxf(0,mirror_cooldown-delta)
	if wind_left>0:
		wind_left=maxf(0,wind_left-delta)
		if wind_left<=0:set_wind_visual(false)
func clear_cooldowns():cooldown=0;wind_cooldown=0;mirror_cooldown=0
func tick(delta:float,after_pose:bool=false):
	if after_pose or not active or game.paused or game.transitioning or not game.playing:return
	if mode=="dead":elapsed+=delta;return
	if immolating:
		burn_clock+=delta
		while burn_clock>=1.0:burn_clock-=1.0;burn()
	if not is_attacking():
		if spell_owner==null and (hero.auto_attack_running() or primary_held):start_attack()
		return
	elapsed+=delta*(hero.attack_speed_multiplier() if mode=="attack" else 1.0)
	hero.attack_left=maxf(0,duration-elapsed)
	if mode=="attack" and not released and elapsed>=contact:
		released=true
		if demon:launch()
		else:
			if combo==2:sound("wc_slam");effects.slam()
			strike(false)
	elif mode=="spin":
		while next_pulse<=minf(elapsed,duration)+.00001:strike(true);next_pulse+=Kit.SPIN_INTERVAL
		if elapsed>=next_sound and elapsed<duration:sound("wc_spin");next_sound+=.846
	if elapsed>=duration:
		if mode=="morph":demon=not demon;primary_held=false
		var again=queued;finish();combo_timer=.85
		if again:start_attack()

func strike(radial:bool):
	var origin=hero.global_position+Vector3.UP*1.25*hero.contact_size_multiplier()
	var reach=skill_factor("hit_area",ticket)*(Kit.SPIN_RADIUS if radial else Kit.MELEE_REACH)*hero.contact_size_multiplier()*hero.melee_reach_setting()*hero.pickup_multiplier("range")
	if source_id()==33:cast_model().pressure_trail.paint_arc(origin,origin+hero.facing*reach,Vector3.UP,.65)
	for enemy in AttackChain.enemy_candidates(game,origin,reach+2):
		if not is_instance_valid(enemy) or enemy.dead:continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		var target=AttackChain.aim_point(enemy,origin)
		var offset=target-origin;offset.y=0
		if not radial and offset.length_squared()>.01 and offset.normalized().dot(hero.facing)<.15:continue
		var hit=AttackChain.segment_contact(enemy,origin,origin,reach)
		if hit.is_empty() or not AttackChain.clear_line(hero,origin,target):continue
		enemy.take_hit(attack_damage(radial)*hero.damage_multiplier(),hero.facing,combo==2,ticket)
		after_strike(enemy,radial)
		if hero.ai_controlled:game.confirm_ally_impact(enemy,hit.point,hero.facing,1,false,source_id())
		else:game.confirm_impact(enemy,hit.point,hero.facing,1,false,source_id())

func attack_damage(radial:bool)->float:return Kit.SPIN_DAMAGE if radial else 90.0 if combo==2 else 48.0
func after_strike(_enemy:Node3D,_radial:bool):pass

func launch():
	var origin=hero.global_position+Vector3.UP*1.65*hero.contact_size_multiplier()
	var direction=Vector3.ZERO
	var obstruction={}
	if hero.is_meta_shooter():
		var rig=game.camera_rig;rig.update_camera(0)
		hero.facing=Vector3.FORWARD.rotated(Vector3.UP,rig.yaw)
		rig.meta_viewmodel.pose(clip,contact)
		origin=rig.meta_viewmodel.muzzle_position()
		var camera:Camera3D=rig.camera
		var sight=preload("res://scripts/master_chief_combat.gd").trace_shot(hero,camera.global_position,camera.global_position-camera.global_basis.z*120)
		direction=(sight.point-origin).normalized()
		# Reuse Chief's eye-to-muzzle clearance so the overlay cannot bypass cover.
		var clearance=preload("res://scripts/master_chief_combat.gd").trace_shot(hero,camera.global_position,origin)
		if clearance.impact:obstruction=clearance
	else:
		direction=(hero.ai_aim-origin).normalized() if hero.ai_controlled else game.projectile_direction(origin)
		origin+=direction*.8
	var shot=Pool.service(game).launch(hero,Shot,"demon",{"position":origin if obstruction.is_empty() else obstruction.position,"velocity":direction*28,"damage":64.0*hero.damage_multiplier(),"attack_ticket":ticket.duplicate(true)})
	if not obstruction.is_empty():shot.explode(obstruction.position+obstruction.normal*.025,obstruction.target)
	sound("wc_missile")

func sound(slot:String):
	var audio_ticket=ticket if not ticket.is_empty() else hero.attack_chain.make_ticket("warcraft_"+slot)
	game.sound(slot,.8,false,audio_ticket,source_id())
func blade_active()->bool:return mode=="attack" and not demon and elapsed>=contact-.12 and elapsed<=contact+.16
func is_attacking()->bool:return mode in ["attack","spin","morph","mirrors"]
func blocks_movement()->bool:return false
func ground_attack_velocity()->Vector3:return Vector3.ZERO if mode=="morph" and hero.is_on_floor() else Vector3.INF
func protects_player()->bool:return false
func interrupt_for_dodge():cancel(true)
func hit():cancel(true)
func die():
	cancel(true);stop_powers();mode="dead";clip="Death Alternate" if demon else "Death"
	cast_model().pose(clip,0)
func finish():
	if is_instance_valid(effects):effects.spin(false)
	mode="";clip="";elapsed=0;released=false;queued=false;ticket={};hero.attack_left=0
func cancel(preserve_power:bool=false):
	primary_held=false
	finish();combo=-1;combo_timer=0
	if is_instance_valid(cast_model()):
		for blade in cast_model().blade_trails:blade.trail.clear();blade.original.clear()
		if cast_model().pressure_trail!=null:cast_model().pressure_trail.clear()
	if not preserve_power:demon=false;stop_powers()
func stop_powers():
	if wind_left>0:wind_left=0;set_wind_visual(false)
	immolating=false;burn_clock=0;burn_ticket={}
	if mirrors!=null:mirrors.clear()
	if is_instance_valid(effects):effects.immolation(false)
func _exit_tree():
	if mirrors!=null:mirrors.dispose()
	stop_powers()
	if is_instance_valid(effects):effects.queue_free()
