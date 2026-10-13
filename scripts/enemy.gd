class_name Ninja
extends CharacterBody3D

var game: Node
var model: HeroModel
var alerted=false
var training_dummy=false
var practice=false
var swarm=false
var island_index=-1
var ground_giant=false
var island_elite=false
var elite_attacks
const ELITE_SIZE=1.6
const GIANT_SIZE=5.0
const GIANT_HEALTH=8.0
const GIANT_DAMAGE=3.0
const COMBO_TEST_HEALTH=5.0
static var swarm_bar_mesh: BoxMesh
var encounter_id=""
var variant=0
const VARIANT_NAMES=["Masked soldier","Straw-hat bandit","Daruma bruiser","Lantern yokai"]
const HEALTH=[1.0,.8,1.8,1.0]
const SPEED=[4.0,6.4,2.9,3.6]
const COLORS=["e46d5a","50d9b0","e4ab55","b085f5"]
var boss_style=0
var attack_kind="dash"
var attack_count=0
var poise_hits=0
var boss=false
var body_radius=0.45
var hp=66.0
var max_hp=66.0
var dead=false
var home=Vector3.ZERO
var state="idle"
var timer=0.0
var cooldown=1.0
var stun=0.0
var frozen_left=0.0
var frozen_visual: Node3D
var formation_index=-1
var attack_dir=Vector3.FORWARD
var bar: MeshInstance3D
var pulse=0.0
var death_timer=0.8
var attack_hit=false
var impact_pause=0.0
var recoil_age=1.0
var recoil_direction=Vector3.ZERO
var recoil_strength=0.0
var distance_asleep=false
var render_full=false
var name_tag: Label3D
var route_clock=0.0
var route_direction=Vector3.ZERO
var animation_elapsed=0.0
var grounded_cached=false
var walk_clock=0.0
var walk_span=.15
var walk_phase_pending=true
var walk_start=Vector3.ZERO
var walk_end=Vector3.ZERO
var walk_age=1.0
var defense_lane=-1
var defense_waypoint=1
var defense_offset=Vector3.ZERO
var defense_escaped=false
var defense_scale=1.0
var defense_health_multiplier=1.0
var defense_damage_multiplier=1.0
var defense_speed_multiplier=1.0
var defense_role=""
var defense_boss_tier=0
var defense_traits
var defense_dog_target: Node3D
var defense_dog_state=""
var defense_dog_timer=0.0
var defense_dog_clock=0.0
var defense_dog_contact_done=false
var defense_dog_hits=0
var defense_dog_attacks=0



func _ready():
	if defense_lane>=0 and (not defense_role.is_empty() or defense_boss_tier>0):
		if defense_boss_tier>0:defense_role="boss"
		defense_traits=preload("res://scripts/defense_enemy_traits.gd").new(self)
		defense_traits.apply_stats()
	route_clock=float(get_instance_id()%11)/60.0
	defense_dog_clock=float(maxi(0,formation_index)%8)*.035
	collision_layer=4
	collision_mask=1
	floor_snap_length=0.6
	home=position
	if boss:
		max_hp=580+boss_style*70
		hp=max_hp
		body_radius=0.85
	max_hp=max_hp*game.tuning.boss_hp_mult if boss else game.tuning.enemy_hp*HEALTH[variant]
	if not boss:max_hp*=COMBO_TEST_HEALTH
	if ground_giant:max_hp*=GIANT_HEALTH
	if island_elite:max_hp*=2.0
	if defense_lane>=0:max_hp*=defense_health_multiplier
	hp=max_hp
	if not boss and variant==2:body_radius=.62
	if ground_giant:body_radius*=GIANT_SIZE
	elif island_elite:body_radius*=ELITE_SIZE
	if defense_lane>=0:body_radius*=defense_scale
	var collision=CollisionShape3D.new()
	var shape=CapsuleShape3D.new()
	shape.radius=body_radius
	shape.height=(3 if boss else 1.8)*(GIANT_SIZE if ground_giant else (ELITE_SIZE if island_elite else 1.0))*defense_scale
	collision.shape=shape
	collision.position.y=shape.height/2
	add_child(collision)
	model=HeroModel.new(true,boss,boss_style)
	model.crowd_proxy=not boss
	add_child(model)
	if boss: model.scale=Vector3.ONE*1.5
	elif variant!=0:
		model.scale=Vector3.ONE*([1.0,.88,1.22,1.0][variant])
	if swarm:
		model.scale=Vector3.ONE*([1.0,.88,1.22,1.0][variant])
		if swarm_bar_mesh==null:
			swarm_bar_mesh=BoxMesh.new();swarm_bar_mesh.size=Vector3(1.3,.09,.065)
		bar=Geo.mesh(self,swarm_bar_mesh,Vector3(0,3.25,0),Geo.mat("ff8068",0,.3))
	else:
		bar=Geo.box(self,Vector3(0,4.7 if boss else 3.25,0),Vector3(1.3,0.09,0.065),Geo.mat("ff8068",0,0.3))
	if ground_giant:
		model.scale*=GIANT_SIZE
		bar.position.y*=GIANT_SIZE
		bar.mesh=bar.mesh.duplicate();bar.mesh.size=Vector3(4.5,.32,.12)
	if island_elite:
		elite_attacks=preload("res://scripts/elite_attacks.gd").new(self)
		model.scale*=ELITE_SIZE;bar.position.y*=ELITE_SIZE
		var crest=Label3D.new();crest.text="ELITE GUARD";crest.position.y=4.8
		crest.font_size=28;crest.pixel_size=.012;crest.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		crest.modulate=Color("ffd778");add_child(crest)
	bar.visible=false
	if defense_lane>=0:
		model.scale*=defense_scale
		bar.position.y*=defense_scale;bar.scale=Vector3.ONE*defense_scale
		# The crowd remains visible down the approach; tiny distant health bars
		# need not add one draw and shadow caster per artillery victim.
		bar.visibility_range_end=70
		bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not boss and variant!=0 and not swarm:
		var label=Label3D.new();name_tag=label;label.text=VARIANT_NAMES[variant];label.font_size=23;label.pixel_size=.008
		label.position.y=3.5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color(COLORS[variant]);add_child(label)

	# The crowd director reveals the appropriate representation on the first frame.
	# Avoid rendering every rig while the initial main menu is open.
	if defense_traits!=null:defense_traits.setup_visuals()
	visible=false

func apply_defense_slow(factor: float,seconds: float):
	if dead or defense_lane<0:return
	if defense_traits==null:
		defense_traits=preload("res://scripts/defense_enemy_traits.gd").new(self)
	defense_traits.apply_slow(factor,seconds)

func defense_slow_multiplier()->float:
	return defense_traits.slow_factor if defense_traits!=null else 1.0

func growth_knockback()->float:
	var extra=game.player.growth_multiplier()-1.0
	return 1.0+extra*(.2 if ground_giant or boss else (.6 if island_elite else 1.5))

func take_hit(damage: float, dir: Vector3, heavy: bool,attack_ticket: Dictionary={}):
	if dead or damage<=0:return
	# A stagger cancels the pending companion strike as well as its pose.
	if not defense_dog_state.is_empty():
		defense_dog_state="";defense_dog_timer=0;defense_dog_contact_done=true
	if heavy and elite_attacks!=null and elite_attacks.active:elite_attacks.cancel()
	var tower_hit=bool(attack_ticket.get("tower",false))
	if not tower_hit:
		damage*=game.player.attack_chain.damage_for(attack_ticket)
		game.player.attack_chain.confirm(attack_ticket)
	if defense_traits!=null:damage*=defense_traits.hit_multiplier(dir,attack_ticket,heavy)
	var preserve_impact=attack_ticket.get("bonus",false) and recoil_age<.08
	var prior_velocity=velocity;var prior_strength=recoil_strength;var prior_direction=recoil_direction;var prior_stun=stun
	recoil_age=0
	recoil_direction=model.global_basis.inverse()*dir.normalized()
	recoil_strength=0.48 if heavy else 0.22
	alerted=true
	hp-=damage
	bar.visible=true
	bar.scale.x=maxf(0.01,hp/max_hp)*defense_scale
	stun=0.46 if heavy else 0.20
	if boss:
		poise_hits+=1 if heavy else 0
		stun=0.0
		if heavy and poise_hits%3==0:
			stun=0.22
			state="recover"
			timer=0.45
	else:
		state="chase"
		timer=0
	velocity=dir*(15 if heavy else 2.5)/(1.7 if boss else 1.0)
	velocity*=1.0 if tower_hit else growth_knockback()
	if island_elite:velocity/=1.7;stun*=.7
	if training_dummy: velocity=Vector3.ZERO
	if heavy and not training_dummy: velocity.y=5.5*sqrt(growth_knockback());grounded_cached=false
	if ground_giant:
		velocity/=3.0;stun*=.4
	if preserve_impact and prior_strength>recoil_strength:
		velocity=prior_velocity;recoil_strength=prior_strength;recoil_direction=prior_direction;stun=maxf(stun,prior_stun)
	if defense_traits!=null:defense_traits.adjust_hit_response(heavy)
	if frozen_left>0:velocity=Vector3.ZERO
	walk_clock=0
	if not model.crowd_proxy:
		model.animate(0,0,is_on_floor(),velocity.y,0,false,0,false)
		apply_recoil()
	if not tower_hit or attack_ticket.get("tower_feedback",false):
		game.damage_number(global_position+Vector3.UP*2.6*defense_scale,int(damage),heavy)
	if hp<=0:
		if elite_attacks!=null:elite_attacks.cancel()
		if defense_traits!=null:defense_traits.cancel()
		dead=true
		frozen_left=0
		if is_instance_valid(frozen_visual):frozen_visual.hide()
		collision_layer=0
		game.kills+=1
		if game.descent_mode and island_index>=0 and not practice:game.encounters.record_defeat(self)
		if defense_lane>=0 and not practice:game.encounters.record_defeat(self)
		if not tower_hit and not training_dummy and not practice:game.player.award_kill()
		game.remember_defeat(self)
		if not tower_hit and not training_dummy and not game.descent_mode:game.drop_powerup(global_position)
		if not tower_hit and (game.player.hp>0 or not game.is_fire_siege()):game.player.hp=minf(game.player.max_hp,game.player.hp+9)
		# Artillery already supplies a shared, budgeted impact effect. Spawning
		# eighteen particles per splash victim would overwhelm a large battery.
		if not tower_hit:game.burst(global_position+Vector3.UP,Color("82e7e0"),18)
		if boss: game.victory()

func freeze_for(seconds: float):
	if dead:return
	if elite_attacks!=null:elite_attacks.cancel()
	if defense_traits!=null and defense_traits.is_boss():
		defense_traits.cancel_attack();seconds*=.5
	frozen_left=maxf(frozen_left,seconds);velocity=Vector3.ZERO;walk_clock=0
	state="chase";timer=0;attack_hit=true;cooldown=maxf(cooldown,.3)
	if not is_instance_valid(frozen_visual):
		frozen_visual=Node3D.new();add_child(frozen_visual)
		var ice_material=Geo.mat("89deff",.25,.6)
		ice_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ice_material.albedo_color.a=.4
		for i in range(3):
			var angle=TAU*i/3.0
			var shard=Geo.spike(frozen_visual,Vector3(cos(angle)*.4,0,sin(angle)*.4),Vector3(cos(angle)*.55,1.25,sin(angle)*.55),.18,ice_material)
	frozen_visual.show()

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning: return
	var hero_targetable=not game.player.rogue_untargetable() and (game.player.hp>0 or not game.is_fire_siege())
	if defense_traits!=null and not dead:defense_traits.tick_status(delta)
	if island_index>=0 and not dead:
		var center=game.world.sky_islands.islands[island_index]
		if position.y<center.y-8:
			if hp<max_hp:take_hit(hp+1,Vector3.DOWN,true)
			else:position=home;velocity=Vector3.ZERO
			return
		# Acquire approaching/jumping players, instead of reverting to patrol
		# whenever they rise four metres above the island.
		var hero_offset=game.player.position-center
		var near_hero=hero_targetable and absf(hero_offset.y)<26 and Vector2(hero_offset.x,hero_offset.z).length_squared()<40*40
		if near_hero:alerted=true
		var committed=state in ["windup","strike","recover"] or (elite_attacks!=null and elite_attacks.active)
		if not near_hero and stun<=0 and frozen_left<=0 and (hero_targetable or not committed):
			if elite_attacks!=null and elite_attacks.active:elite_attacks.cancel()
			if game.tuning.freeze_ai:
				velocity=Vector3.ZERO
				if not is_on_floor():velocity.y=-1;move_and_slide()
				return
			pulse+=delta;animation_elapsed+=delta
			var angle=pulse*.3+formation_index*2.399963
			var target=game.world.sky_islands.interior_point(island_index,angle,.45)
			var direction=target-position;direction.y=0;direction=direction.normalized()
			velocity.x=direction.x*1.8;velocity.z=direction.z*1.8
			if not is_on_floor():velocity.y-=28*delta
			state="patrol";model.rotation.y=atan2(-direction.x,-direction.z)
			walk_motion(delta);update_animation(false);return
	if frozen_left>0 and not dead:
		frozen_left=maxf(0,frozen_left-delta);velocity=Vector3.ZERO
		if frozen_left<=0 and is_instance_valid(frozen_visual):frozen_visual.hide()
		return
	var focus=game.player
	var distance=global_position.distance_squared_to(focus.global_position)
	if defense_lane>=0 and not dead:
		if game.is_fire_siege() and preload("res://scripts/gate_enemy_motion.gd").tick(self,delta):return
		if game.encounters.can_breach(self):
			game.encounters.breach(self);return
		if game.is_fire_siege() and preload("res://scripts/shrine_enemy_motion.gd").tick(self,delta):return
		var kennel=refresh_defense_dog_target(delta)
		var prior_boss_phase=defense_traits.phase if defense_traits!=null else ""
		if defense_traits!=null and defense_traits.is_boss() and is_instance_valid(defense_dog_target) and defense_traits.phase=="march" and defense_traits.slam_cooldown<=0 and not game.tuning.freeze_ai:
			defense_traits.begin_slam()
		var boss_attacking=defense_traits!=null and defense_traits.tick_attack(delta)
		if kennel!=null and defense_traits!=null and prior_boss_phase in ["march","warning"] and defense_traits.phase=="impact":
			var slam_damage=(38 if defense_boss_tier>=2 else 28)*defense_damage_multiplier*game.tuning.enemy_damage
			for roster in [game.get("kennel"),game.get("barracks")]:
				if roster!=null:roster.boss_slam(self,defense_traits.slam_origin,defense_traits.radius,slam_damage)
		if boss_attacking:
			animation_elapsed+=delta;recoil_age+=delta
			if not grounded_cached and not is_on_floor():velocity.y-=28*delta
			walk_motion(delta);update_animation(false);return
		if tick_defense_dog(delta):return
		if (not hero_targetable or distance>15*15) and stun<=0 and state not in ["windup","strike"]:
			if game.tuning.freeze_ai:return
			pulse+=delta;animation_elapsed+=delta;recoil_age+=delta;cooldown-=delta
			state="march";alerted=true
			var direction=game.encounters.lane_direction(self)
			if dead:return
			var speed=game.encounters.defense_speed(self)*defense_slow_multiplier()
			velocity.x=direction.x*speed;velocity.z=direction.z*speed
			if not grounded_cached and not is_on_floor():velocity.y-=28*delta
			walk_motion(delta);model.rotation.y=atan2(-direction.x,-direction.z)
			update_animation(false);return
	var far=hero_targetable and not practice and not boss and distance>28*28 and not (elite_attacks!=null and elite_attacks.active)
	if focus.sky_strike.active and focus.sky_strike.target==self:far=false
	route_clock-=delta;animation_elapsed+=delta
	if far and not dead and stun<=0 and not training_dummy:
		if game.tuning.freeze_ai:return
		state="chase";alerted=true
		var direction=pursuit_direction()
		var speed=SPEED[variant]*defense_speed_multiplier*defense_slow_multiplier()
		velocity.x=direction.x*speed;velocity.z=direction.z*speed
		if not grounded_cached and not is_on_floor():velocity.y-=28*delta
		walk_motion(delta)
		model.rotation.y=atan2(-direction.x,-direction.z)
		update_animation(false);return
	if impact_pause>0:
		impact_pause=maxf(0,impact_pause-delta)
		return
	recoil_age+=delta
	pulse+=delta
	if dead:
		death_timer-=delta
		model.scale*=maxf(0.01,1-delta*3)
		model.rotation.y+=delta*9
		velocity.y-=25*delta
		move_and_slide()
		if death_timer<=0: queue_free()
		return
	if training_dummy or game.tuning.freeze_ai:
		if not is_on_floor():
			velocity=Vector3(0,velocity.y-28*delta,0);move_and_slide()
		else:velocity=Vector3.ZERO
		if render_full:update_animation(true)
		return
	if not is_instance_valid(game.player): return
	var diff=game.player.global_position-global_position
	var dist=diff.length()
	var dir=diff.normalized()
	dir.y=0
	cooldown-=delta
	stun-=delta
	if not grounded_cached and not is_on_floor(): velocity.y-=28*delta
	if stun>0:
		velocity.x=move_toward(velocity.x,0,delta*16)
		velocity.z=move_toward(velocity.z,0,delta*16)
	elif elite_attacks!=null and (hero_targetable or elite_attacks.active) and elite_attacks.tick(delta):
		walk_motion(delta);update_animation(false);return
	elif state=="windup":
		timer-=delta
		velocity.x=0
		velocity.z=0
		if timer<=0:
			state="strike"
			timer=0.30
			attack_hit=false
			if attack_kind=="fan":
				fire_fan()
			elif attack_kind=="wave" and boss:
				var wave=BossWave.new()
				wave.game=game
				wave.position=position
				game.add_child(wave)
			else: game.slash(global_position+Vector3.UP*defense_scale,attack_dir,boss,1,Color("fb7561"),(GIANT_SIZE if ground_giant else 1.0)*defense_scale)
	elif state=="strike":
		timer-=delta
		velocity.x=attack_dir.x*(12 if boss else (12 if variant==1 else (5 if variant==2 else 7)))*defense_speed_multiplier*defense_slow_multiplier() if attack_kind=="dash" else 0
		velocity.z=attack_dir.z*(12 if boss else (12 if variant==1 else (5 if variant==2 else 7)))*defense_speed_multiplier*defense_slow_multiplier() if attack_kind=="dash" else 0
		if attack_kind=="dash" and not attack_hit and dist<(4.8 if boss else (3.4 if variant==2 else 2.6))*(GIANT_SIZE if ground_giant else 1.0)*defense_scale:
			var cover_clear=defense_lane<0 or get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,game.player.global_position+Vector3.UP,1)).is_empty()
			if cover_clear:
				game.player.take_hit((22 if boss else (20 if variant==2 else (8 if variant==1 else 11)))*(GIANT_DAMAGE if ground_giant else 1.0)*defense_damage_multiplier,attack_dir)
				attack_hit=true
		if timer<=0:
			state="recover"
			timer=0.85 if boss else ([.65,.4,1.1,.9][variant])
	elif state=="recover":
		timer-=delta
		velocity.x=move_toward(velocity.x,0,delta*40)
		velocity.z=move_toward(velocity.z,0,delta*40)
		if timer<=0:
			state="chase"
			cooldown=0.3
	else:
		if game.player.hp>0 and hero_targetable:
			state="chase"
			if boss and dist<30 and not game.boss_active: game.boss_intro()
			model.rotation.y=lerp_angle(model.rotation.y,atan2(-dir.x,-dir.z),delta*9)
			var attack_range=4.1 if boss else ([2.6,3.0,3.3,16.0][variant])
			if ground_giant:attack_range*=GIANT_SIZE
			if boss and boss_style==1: attack_range=21
			if boss and boss_style==2: attack_range=12
			if boss and boss_style==3: attack_range=18
			attack_range*=defense_scale
			if dist<attack_range and cooldown<=0 and get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,game.player.global_position+Vector3.UP,1)).is_empty():
				state="windup"
				attack_count+=1
				attack_kind="fan" if not boss and variant==3 else "dash"
				if boss_style==1 and boss: attack_kind="fan"
				if boss_style==2 and boss: attack_kind="wave"
				if boss_style==3 and boss: attack_kind=["fan","wave","dash"][attack_count%3] if dist<5 else ["fan","wave"][attack_count%2]
				timer=(0.66 if hp<max_hp*0.5 else 0.9) if boss else ([.62,.38,.95,.8][variant])
				attack_dir=dir
			else:
				var speed=(5.2 if hp<max_hp*0.5 else 4.2) if boss else SPEED[variant]
				speed*=defense_speed_multiplier*defense_slow_multiplier()
				dir=pursuit_direction()
				if variant==3 and not boss and not ground_giant:
					# Small throwers keep space while their attack reloads.
					if dist<8:dir=-dir
					elif dist<13:dir=dir.cross(Vector3.UP)*(1 if formation_index%2==0 else -1);speed*=.65
				var next=global_position+dir*1.5
				if island_index<0 and game.world.height_at(next.x,next.z)<-0.5: speed=0
				velocity.x=dir.x*speed
				velocity.z=dir.z*speed
		else:
			state="idle"
			var to_home=home-global_position
			var wander=to_home.normalized() if to_home.length()>4 else Vector3(sin(pulse*0.4),0,cos(pulse*0.4))*0.35
			velocity.x=wander.x*1.3
			velocity.z=wander.z*1.3
	walk_motion(delta)
	update_animation(false)
	if bar.visible: bar.look_at(game.camera_rig.camera.global_position,Vector3.UP)

func clear_defense_dog():
	defense_dog_target=null
	if not defense_dog_state.is_empty():
		state="chase";timer=0;walk_clock=0;cooldown=maxf(cooldown,.3)
	defense_dog_state="";defense_dog_timer=0;defense_dog_contact_done=true

func refresh_defense_dog_target(delta: float):
	if game.is_fire_siege():clear_defense_dog();return null
	var kennel=game.get("kennel")
	var barracks=game.get("barracks")
	var running_roster=kennel if kennel!=null and kennel.running() else (barracks if barracks!=null and barracks.running() else null)
	if running_roster==null:
		clear_defense_dog();return null
	var current_valid=defense_ally_manager(defense_dog_target)!=null and position.distance_squared_to(defense_dog_target.position)<18*18
	if defense_dog_state in ["windup","strike","recover"] and current_valid:return running_roster
	if not current_valid:clear_defense_dog()
	if state in ["windup","strike"] and defense_dog_state.is_empty():return running_roster
	defense_dog_clock-=delta
	if defense_dog_clock<=0:
		defense_dog_clock=.28+float(formation_index%5)*.015
		var chosen=kennel.enemy_target(self) if kennel!=null else null
		var hero=barracks.enemy_target(self) if barracks!=null else null
		if hero!=null and (chosen==null or position.distance_squared_to(hero.position)<position.distance_squared_to(chosen.position)):chosen=hero
		if chosen==null:clear_defense_dog()
		else:defense_dog_target=chosen
	return running_roster

func defense_ally_manager(ally):
	if game.is_fire_siege():return null
	# Both bounded rosters use the same actor ownership and cancellation rules.
	# Keep the legacy retaliation field names for existing saves and diagnostics.
	if not is_instance_valid(ally) or ally.dead:return null
	var roster=ally.kennel
	if roster==null or not roster.running() or not roster.owns(ally):return null
	return roster

func dog_attack_reach()->float:return body_radius+1.9

func dog_attack_contact():
	if defense_dog_contact_done or defense_dog_state!="strike" or dead or not game.playing or game.paused or game.transitioning:return
	defense_dog_contact_done=true
	var dog=defense_dog_target
	if defense_ally_manager(dog)==null:return
	var offset=dog.position-position
	if Vector2(offset.x,offset.z).length()>dog_attack_reach()+.6 or absf(offset.y)>2.5:return
	var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP,dog.position+Vector3.UP*.7,1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return
	dog.take_hit((20 if variant==2 else (8 if variant==1 else 11))*defense_damage_multiplier*game.tuning.enemy_damage,attack_dir)
	defense_dog_hits+=1

func tick_defense_dog(delta: float)->bool:
	if not is_instance_valid(defense_dog_target) or defense_dog_target.dead:
		clear_defense_dog();return false
	if defense_ally_manager(defense_dog_target)==null:
		clear_defense_dog();return false
	if game.tuning.freeze_ai or training_dummy or stun>0 or impact_pause>0:return false
	var offset=defense_dog_target.position-position;offset.y=0
	var direction=offset.normalized()
	pulse+=delta;animation_elapsed+=delta;recoil_age+=delta;cooldown-=delta
	if not grounded_cached and not is_on_floor():velocity.y-=28*delta
	if defense_dog_state=="windup":
		defense_dog_timer-=delta;timer=defense_dog_timer
		velocity.x=0;velocity.z=0;state="windup"
		if defense_dog_timer<=0:
			defense_dog_state="strike";state="strike";defense_dog_timer=.24;timer=.24
			defense_dog_contact_done=false;dog_attack_contact()
	elif defense_dog_state=="strike":
		defense_dog_timer-=delta;timer=defense_dog_timer
		velocity.x=0;velocity.z=0;state="strike"
		if defense_dog_timer<=0:defense_dog_state="recover";state="recover";defense_dog_timer=.55
	elif defense_dog_state=="recover":
		defense_dog_timer-=delta;velocity.x=0;velocity.z=0;state="recover"
		if defense_dog_timer<=0:defense_dog_state="chase";state="chase";cooldown=.3
	else:
		state="chase";defense_dog_state="chase"
		model.rotation.y=lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*9))
		var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP,defense_dog_target.position+Vector3.UP*.7,1)
		if offset.length()<=dog_attack_reach() and cooldown<=0 and get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			defense_dog_state="windup";state="windup";attack_kind="dash";attack_dir=direction
			defense_dog_timer=[.62,.38,.95][mini(variant,2)];timer=defense_dog_timer
			defense_dog_attacks+=1;defense_dog_contact_done=false;velocity.x=0;velocity.z=0
		else:
			var speed=SPEED[variant]*defense_speed_multiplier*defense_slow_multiplier()
			velocity.x=direction.x*speed;velocity.z=direction.z*speed
	walk_motion(delta);update_animation(false)
	return true

func fire_fan():
	var from=position+Vector3.UP*1.7
	# A committed volley may finish, but it cannot retarget a vanished hero.
	var aim=attack_dir if game.player.rogue_untargetable() else (game.player.position+Vector3.UP-from).normalized()
	var count=(5 if hp<max_hp*0.5 else 3) if boss else 2
	for i in range(count):
		var angle=(i-(count-1)*0.5)*0.22
		var projectile=GoldCoin.new()
		projectile.game=game
		projectile.hostile=true
		projectile.damage=(16 if boss else 9)*(GIANT_DAMAGE if ground_giant else 1.0)*defense_damage_multiplier
		projectile.lifetime=2.4
		projectile.position=from+aim*0.7
		projectile.velocity=aim.rotated(Vector3.UP,angle)*19
		game.add_child(projectile)
	game.sound("heavy_swing",0.5,true)

func apply_recoil():
	if model.crowd_proxy:return # Crowd applies the same directional response to its instance.
	var response=exp(-recoil_age*10)*cos(recoil_age*15)*recoil_strength
	model.body.rotation.x+=recoil_direction.z*response
	model.body.rotation.z-=recoil_direction.x*response
	model.body.rotation.y+=recoil_direction.x*response*0.45
	model.head.rotation.x-=recoil_direction.z*response*0.65
	model.head.rotation.z+=recoil_direction.x*response*0.6
	for arm in model.arms:arm.rotation.x+=response*0.6

func pursuit_direction()->Vector3:
	if island_index>=0:
		var direction=game.player.position-position;direction.y=0
		return direction.normalized()
	if route_clock<=0 or route_direction==Vector3.ZERO:
		route_clock=.18;route_direction=game.pursuit.direction(global_position,formation_index if swarm else -1)
	return route_direction
func update_animation(idle: bool):
	if model.crowd_proxy or not render_full:return
	if animation_elapsed<1.0/30.0 and state not in ["windup","strike"]:return
	model.animate(animation_elapsed,0 if idle else Vector2(velocity.x,velocity.z).length(),grounded_cached or is_on_floor(),velocity.y,0.65 if state=="windup" else (timer/.3 if state=="strike" else 0.0),boss,1,false)
	apply_recoil();model.sync_skeleton();animation_elapsed=0

func walk_motion(delta: float):
	var island_patrol=false
	if island_index>=0:
		var center=game.world.sky_islands.islands[island_index]
		var next=position+velocity*delta
		if stun<=0 and not game.world.sky_islands.contains_point(island_index,next,body_radius+.8):
			# Polygon-aware ledge steering keeps casters and patrols on wedges,
			# ridges and notched islands; knockback can still throw them off.
			var inward=center-position;inward.y=0;inward=inward.normalized()
			var speed=minf(2.5,Vector2(velocity.x,velocity.z).length())
			velocity.x=inward.x*speed;velocity.z=inward.z*speed
		# Remote patrols follow short, collision-tested segments. Nearby combat,
		# airborne actors and knockback still use the full controller every tick.
		island_patrol=state=="patrol" and stun<=0 and (grounded_cached or is_on_floor()) and game.player.position.distance_squared_to(center)>32*32
		if not island_patrol:
			if is_on_floor() and velocity.y<=0:velocity.y=-.1
			move_and_slide();grounded_cached=is_on_floor();walk_clock=0;walk_phase_pending=true
			return
	# Keep real collision bodies for combat; amortize static-ground sweeps across
	# frames and interpolate the validated short segment at the physics rate.
	if walk_clock>0 and global_position.distance_squared_to(walk_start.lerp(walk_end,minf(1,walk_age/walk_span)))>.25:
		walk_clock=0;walk_phase_pending=true
	if boss or stun>0 or (not grounded_cached and not is_on_floor()):
		if not grounded_cached and velocity.y==0:velocity.y=-1
		move_and_slide();grounded_cached=is_on_floor();walk_clock=0;walk_phase_pending=true
		return
	grounded_cached=true;velocity.y=0
	var horizontal=Vector3(velocity.x,0,velocity.z)
	if horizontal.length_squared()<.001:walk_clock=0;walk_phase_pending=true;return
	walk_clock-=delta
	if walk_clock<=0:
		# A short first segment seeds a stable phase for each actor. Subsequent
		# sweeps retain the existing 0.15 s horizon instead of all 300 sharing
		# one tick. Real knockback/airborne collision above stays immediate.
		walk_span=.15
		if walk_phase_pending:
			var slot=formation_index if formation_index>=0 else int(get_instance_id())
			walk_span=.15*float(1+posmod(slot,9))/9.0
			walk_phase_pending=false
		walk_clock=walk_span;walk_age=0;walk_start=global_position
		var motion=horizontal*walk_span
		var hit=move_and_collide(motion,true)
		if hit:
			var slide=hit.get_remainder().slide(hit.get_normal())
			var from=global_transform;from.origin+=hit.get_travel()
			var second=KinematicCollision3D.new()
			if test_move(from,slide,second):slide=second.get_travel()
			motion=hit.get_travel()+slide
		var end=walk_start+motion
		var floor_hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(end+Vector3.UP*1.5,end-Vector3.UP*2,1))
		if floor_hit.is_empty() or floor_hit.normal.y<.6:walk_end=walk_start
		else:walk_end=Vector3(end.x,floor_hit.position.y+.06,end.z)
	walk_age+=delta;global_position=walk_start.lerp(walk_end,minf(1,walk_age/walk_span))
