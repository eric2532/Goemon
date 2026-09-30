class_name Ninja
extends CharacterBody3D

var game: Node
var model: HeroModel
var alerted=false
var training_dummy=false
var practice=false
var swarm=false
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
var walk_start=Vector3.ZERO
var walk_end=Vector3.ZERO
var walk_age=1.0



func _ready():
	route_clock=float(get_instance_id()%11)/60.0
	collision_layer=4
	collision_mask=1
	floor_snap_length=0.6
	home=position
	if boss:
		max_hp=580+boss_style*70
		hp=max_hp
		body_radius=0.85
	max_hp=max_hp*game.tuning.boss_hp_mult if boss else game.tuning.enemy_hp*HEALTH[variant]
	hp=max_hp
	if not boss and variant==2:body_radius=.62
	var collision=CollisionShape3D.new()
	var shape=CapsuleShape3D.new()
	shape.radius=body_radius
	shape.height=3 if boss else 1.8
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
	bar.visible=false
	if not boss and variant!=0 and not swarm:
		var label=Label3D.new();name_tag=label;label.text=VARIANT_NAMES[variant];label.font_size=23;label.pixel_size=.008
		label.position.y=3.5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color(COLORS[variant]);add_child(label)

	# The crowd director reveals the appropriate representation on the first frame.
	# Avoid rendering every rig while the initial main menu is open.
	visible=false

func take_hit(damage: float, dir: Vector3, heavy: bool):
	if dead: return
	recoil_age=0
	recoil_direction=model.global_basis.inverse()*dir.normalized()
	recoil_strength=0.48 if heavy else 0.22
	alerted=true
	hp-=damage
	bar.visible=true
	bar.scale.x=maxf(0.01,hp/max_hp)
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
	if training_dummy: velocity=Vector3.ZERO
	if heavy and not training_dummy: velocity.y=5.5;grounded_cached=false
	if frozen_left>0:velocity=Vector3.ZERO
	walk_clock=0
	if not model.crowd_proxy:
		model.animate(0,0,is_on_floor(),velocity.y,0,false,0,false)
		apply_recoil()
	game.damage_number(global_position+Vector3.UP*2.6,int(damage),heavy)
	if hp<=0:
		dead=true
		frozen_left=0
		if is_instance_valid(frozen_visual):frozen_visual.hide()
		collision_layer=0
		game.kills+=1
		game.remember_defeat(self)
		if not training_dummy:game.drop_powerup(global_position)
		game.player.hp=minf(game.player.max_hp,game.player.hp+9)
		game.burst(global_position+Vector3.UP,Color("82e7e0"),18)
		if boss: game.victory()

func freeze_for(seconds: float):
	if dead:return
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
	if frozen_left>0 and not dead:
		frozen_left=maxf(0,frozen_left-delta);velocity=Vector3.ZERO
		if frozen_left<=0 and is_instance_valid(frozen_visual):frozen_visual.hide()
		return
	var focus=game.player
	var distance=global_position.distance_squared_to(focus.global_position)
	var far=not practice and not boss and distance>28*28
	if focus.sky_strike.active and focus.sky_strike.target==self:far=false
	route_clock-=delta;animation_elapsed+=delta
	if far and not dead and stun<=0 and not training_dummy:
		if game.tuning.freeze_ai:return
		state="chase";alerted=true
		var direction=pursuit_direction()
		velocity.x=direction.x*SPEED[variant];velocity.z=direction.z*SPEED[variant]
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
			else: game.slash(global_position+Vector3.UP,attack_dir,boss,1,Color("fb7561"))
	elif state=="strike":
		timer-=delta
		velocity.x=attack_dir.x*(12 if boss else (12 if variant==1 else (5 if variant==2 else 7))) if attack_kind=="dash" else 0
		velocity.z=attack_dir.z*(12 if boss else (12 if variant==1 else (5 if variant==2 else 7))) if attack_kind=="dash" else 0
		if attack_kind=="dash" and not attack_hit and dist<(4.8 if boss else (3.4 if variant==2 else 2.6)):
			game.player.take_hit(22 if boss else (20 if variant==2 else (8 if variant==1 else 11)),attack_dir)
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
		if game.player.hp>0:
			state="chase"
			if boss and dist<30 and not game.boss_active: game.boss_intro()
			model.rotation.y=lerp_angle(model.rotation.y,atan2(-dir.x,-dir.z),delta*9)
			var attack_range=4.1 if boss else ([2.6,3.0,3.3,16.0][variant])
			if boss and boss_style==1: attack_range=21
			if boss and boss_style==2: attack_range=12
			if boss and boss_style==3: attack_range=18
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
				dir=pursuit_direction()
				var next=global_position+dir*1.5
				if game.world.height_at(next.x,next.z)<-0.5: speed=0
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

func fire_fan():
	var from=position+Vector3.UP*1.7
	var aim=(game.player.position+Vector3.UP-from).normalized()
	var count=(5 if hp<max_hp*0.5 else 3) if boss else 2
	for i in range(count):
		var angle=(i-(count-1)*0.5)*0.22
		var projectile=GoldCoin.new()
		projectile.game=game
		projectile.hostile=true
		projectile.damage=16 if boss else 9
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
	if route_clock<=0 or route_direction==Vector3.ZERO:
		route_clock=.18;route_direction=game.pursuit.direction(global_position,formation_index if swarm else -1)
	return route_direction
func update_animation(idle: bool):
	if model.crowd_proxy or not render_full:return
	if animation_elapsed<1.0/30.0 and state not in ["windup","strike"]:return
	model.animate(animation_elapsed,0 if idle else Vector2(velocity.x,velocity.z).length(),grounded_cached or is_on_floor(),velocity.y,0.65 if state=="windup" else (timer/.3 if state=="strike" else 0.0),boss,1,false)
	apply_recoil();model.sync_skeleton();animation_elapsed=0

func walk_motion(delta: float):
	# Keep real collision bodies for combat; amortize static-ground sweeps across
	# frames and interpolate the validated short segment at the physics rate.
	if walk_clock>0 and global_position.distance_squared_to(walk_start.lerp(walk_end,minf(1,walk_age/.15)))>.25:walk_clock=0
	if boss or stun>0 or (not grounded_cached and not is_on_floor()):
		if not grounded_cached and velocity.y==0:velocity.y=-1
		move_and_slide();grounded_cached=is_on_floor();walk_clock=0
		return
	grounded_cached=true;velocity.y=0
	var horizontal=Vector3(velocity.x,0,velocity.z)
	if horizontal.length_squared()<.001:walk_clock=0;return
	walk_clock-=delta
	if walk_clock<=0:
		walk_clock=.15;walk_age=0;walk_start=global_position
		var motion=horizontal*.15
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
	walk_age+=delta;global_position=walk_start.lerp(walk_end,minf(1,walk_age/.15))
