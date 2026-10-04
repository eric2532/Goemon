class_name DefenseDog
extends CharacterBody3D

# Animation is advanced with the combat clock. The authored attack's contact
# pose and its one real hit therefore pause, restart and cancel together.
static var ring_mesh: TorusMesh
static var bar_mesh: BoxMesh
var game: Node
var kennel: Node
var profile: Dictionary={}
var profile_id=""
var generation=0
var formation_index=0
var hp=1.0
var max_hp=1.0
var dead=false
var state="idle"
var target: Ninja
var attack_target: Ninja
var model: Node3D
var animator: AnimationPlayer
var animation_name=""
var marker: MeshInstance3D
var health_bar: MeshInstance3D
var name_label: Label3D
var body_radius=.5
var attack_age=0.0
var hit_done=false
var attacks_started=0
var hits_landed=0
var hits_received=0
var damage_received=0.0
var damage_dealt=0.0
var healing_done=0.0
var heal_left=3.0
var cooldown_left=0.0
var target_clock=0.0
var hurt_left=0.0
var death_left=0.0
var feedback_left=0.0
var animation_clips: Dictionary={}
var stalled_left=0.0
var spacing_blocked=false

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	collision_layer=8;collision_mask=1;floor_snap_length=.6
	max_hp=float(profile.get("hp",300));hp=max_hp
	heal_left=float(profile.get("heal_interval",3))
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new()
	capsule.radius=body_radius;capsule.height=collision_height()
	collision.shape=capsule;collision.position.y=collision_height()*.5;add_child(collision)
	model=create_model();add_child(model)
	model.name="CompanionModel"
	for child in model.find_children("*","AnimationPlayer",true,false):animator=child;break
	if animator!=null:
		animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in animator.get_animation_list():
			for action in ["idle","run","attack","hurt","death"]:
				if clip==action or String(clip).ends_with("/"+action) or String(clip).ends_with("|"+action) or clip==action+"_loop":animation_clips[action]=clip
		for action in ["idle","run"]:
			if animation_clips.has(action):animator.get_animation(animation_clips[action]).loop_mode=Animation.LOOP_LINEAR
	if ring_mesh==null:
		ring_mesh=TorusMesh.new();ring_mesh.inner_radius=.73;ring_mesh.outer_radius=.82;ring_mesh.rings=20;ring_mesh.ring_segments=4
		bar_mesh=BoxMesh.new();bar_mesh.size=Vector3(1.5,.095,.05)
	marker=Geo.mesh(self,ring_mesh,Vector3(0,.065,0),Geo.mat("81e8e1",.15,.55))
	marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;marker.visibility_range_end=110
	health_bar=Geo.mesh(self,bar_mesh,Vector3(0,health_bar_height(),0),Geo.mat("86ead4",0,.35))
	health_bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;health_bar.visibility_range_end=65
	name_label=Label3D.new();add_child(name_label);name_label.text=String(profile.get("name",profile_id))
	name_label.position.y=health_bar_height()+.27;name_label.font_size=26;name_label.pixel_size=.018
	name_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;name_label.modulate=Color("b0f3ee");name_label.visibility_range_end=48
	target_clock=float(formation_index)*.035
	play_animation("idle")

func create_model()->Node3D:return load(String(profile.asset)).instantiate()
func collision_height()->float:return 1.25
func health_bar_height()->float:return 1.95
func advance_animation(delta: float):
	if animator!=null:animator.advance(delta)

func active_run()->bool:return kennel.owns(self) and kennel.running()
func attack_duration()->float:return maxf(.3,float(profile.get("attack_duration",1.0)))
func contact_time()->float:return clampf(float(profile.get("hit_time",.38)),.05,attack_duration()-.05)
func attack_reach()->float:return float(profile.get("reach",profile.get("attack_range",1.65)))
func attack_interval()->float:return maxf(attack_duration(),float(profile.get("attack_interval",1.25)))

func play_animation(action: String,restart: bool=false):
	if animator==null or not animation_clips.has(action):return
	var clip: String=animation_clips[action]
	var speed=1.0
	if action=="attack":speed=animator.get_animation(clip).length/attack_duration()
	elif action=="run":speed=clampf(Vector2(velocity.x,velocity.z).length()/2.4,.6,4.0)
	animator.speed_scale=speed
	if animation_name==action and not restart:return
	animation_name=action
	animator.play(clip,.10 if action in ["idle","run"] else .055,1.0)
	animator.advance(0)

func valid_target(enemy)->bool:return kennel.valid_enemy(enemy)

func acquire_target():
	var best=INF;var chosen: Ninja=null
	for enemy in game.enemies:
		if not valid_target(enemy):continue
		var distance=position.distance_squared_to(enemy.position)
		if enemy==target:distance*=.82
		if String(profile.get("preferred_role",""))==enemy.defense_role:distance*=.7
		if distance<best:best=distance;chosen=enemy
	target=chosen

func begin_attack(enemy: Ninja)->bool:
	if not active_run() or dead or not valid_target(enemy) or state in ["attack","hurt"] or cooldown_left>0:return false
	var offset=enemy.position-position;offset.y=0
	if offset.length()>attack_reach()+enemy.body_radius:return false
	if not clear_contact(enemy):return false
	target=enemy;attack_target=enemy;state="attack";attack_age=0;hit_done=false
	cooldown_left=attack_interval();attacks_started+=1
	velocity.x=0;velocity.z=0
	if offset.length_squared()>.001:model.rotation.y=atan2(-offset.x,-offset.z)
	play_animation("attack",true)
	return true

func clear_contact(enemy)->bool:
	var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.75,enemy.global_position+Vector3.UP*.9,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func damage_target(enemy,amount: float):
	if not valid_target(enemy) or not clear_contact(enemy):return
	var direction=enemy.position-position;direction.y=0;direction=direction.normalized()
	var before=enemy.hp
	var ticket={"tower":true,"ally":true,"armor_piercing":bool(profile.get("piercing",false)),"tower_feedback":false}
	enemy.take_hit(amount,direction,bool(profile.get("heavy",false)),ticket)
	damage_dealt+=maxf(0,before-maxf(0,enemy.hp));hits_landed+=1
	if not enemy.dead and float(profile.get("slow_factor",1))<1:enemy.apply_defense_slow(float(profile.slow_factor),float(profile.get("slow_duration",1.2)))

func attack_contact():
	if not active_run() or dead or hit_done or state!="attack" or attack_age<contact_time():return
	hit_done=true
	if not valid_target(attack_target):return
	var offset=attack_target.position-position
	if Vector2(offset.x,offset.z).length()>attack_reach()+attack_target.body_radius+.6 or absf(offset.y)>3:return
	if not clear_contact(attack_target):return
	var point=attack_target.position+Vector3.UP*.85
	damage_target(attack_target,float(profile.get("damage",75)))
	var victims=int(profile.get("cleave",1))
	var radius=float(profile.get("cleave_radius",3))
	if victims>1:
		var secondary=0
		for enemy in game.enemies:
			if enemy==attack_target or not valid_target(enemy):continue
			if enemy.position.distance_squared_to(point)>radius*radius:continue
			damage_target(enemy,float(profile.get("damage",75))*.55);secondary+=1
			if secondary>=mini(3,victims-1):break
	if feedback_left<=0 and point.distance_squared_to(game.player.position)<65*65:
		feedback_left=.3;game.burst(point,Color("92efe4"),4,.55)

func take_hit(amount: float,direction: Vector3):
	if dead or not active_run() or amount<=0:return
	var damage=amount*(1.0-clampf(float(profile.get("armor",0)),0,.65))
	hp=maxf(0,hp-damage);hits_received+=1;damage_received+=damage
	health_bar.scale.x=maxf(.01,hp/max_hp)
	if hp<=0:
		dead=true;state="dead";target=null;attack_target=null;hit_done=true
		collision_layer=0;velocity=Vector3.ZERO;death_left=.95
		health_bar.hide();name_label.hide();marker.hide()
		play_animation("death",true);kennel.record_loss(self)
		return
	# Recoil interrupts the animation and its pending bite together. A brief
	# reaction lock prevents a whole crowd from restarting the same pose.
	if hurt_left<=0:
		state="hurt";hurt_left=.45;attack_target=null;hit_done=true
		velocity=Vector3(direction.x,0,direction.z).normalized()*3.5
		play_animation("hurt",true)

func retire():
	dead=true;state="retired";target=null;attack_target=null;collision_layer=0
	set_physics_process(false);hide();queue_free()

func tick_healing(delta: float):
	if not active_run() or dead or float(profile.get("heal_amount",0))<=0:return
	heal_left-=delta
	if heal_left>0:return
	heal_left=maxf(.5,float(profile.get("heal_interval",3)))
	var radius=float(profile.get("heal_radius",10))
	for dog in kennel.dogs:
		if not is_instance_valid(dog) or dog.dead or not kennel.owns(dog):continue
		if dog.position.distance_squared_to(position)>radius*radius:continue
		var before=dog.hp
		dog.hp=minf(dog.max_hp,dog.hp+float(profile.get("heal_amount",0)))
		dog.health_bar.scale.x=maxf(.01,dog.hp/dog.max_hp);healing_done+=dog.hp-before

func recover_to_road():
	var bounds: Rect2=game.world.playable_bounds
	if position.y>=-5 and bounds.has_point(Vector2(position.x,position.z)):return
	position=Vector3((float(formation_index%4)-1.5)*1.8,.15,clampf(position.z,bounds.position.y+8,290))
	velocity=Vector3.ZERO;state="idle";attack_target=null;hit_done=true;hurt_left=0
	play_animation("idle")

func movement_direction(destination: Vector3)->Vector3:
	var next=destination
	var lane_x=(float(formation_index%4)-1.5)*1.8
	# Every defense line, including the castle gate, has the same open road.
	# Stay on that road until the opponent is close enough to approach safely.
	var direct=destination-position;direct.y=0
	if direct.length_squared()<10*10:
		var approach=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.6,destination+Vector3.UP*.6,1)
		if get_world_3d().direct_space_state.intersect_ray(approach).is_empty():return direct.normalized()
	if absf(position.x)>4.5:
		var across=Vector3(lane_x-position.x,0,0)
		var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.6,position+Vector3.UP*.6+across.normalized()*2,1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return Vector3.BACK
		return across.normalized()
	if absf(destination.x)>4.5:
		# Cross through the gateway before approaching a target behind cover.
		# If a side return still blocks the crossing, its south end is open.
		if absf(destination.z-position.z)<.8:return Vector3.BACK
		next.x=lane_x
	elif absf(destination.z-position.z)>7:next.x=lane_x
	var direction=next-position;direction.y=0
	return direction.normalized()

func companion_spacing(toward: Vector3)->Vector3:
	# Both rosters share the road. Tangential steering lets a new arrival go
	# around an ally that is already attacking, including a collinear approach.
	# This query is bounded by the two independent eight-companion caps.
	spacing_blocked=false
	var tangent=toward.cross(Vector3.UP).normalized()
	if tangent.length_squared()<.01:tangent=Vector3.RIGHT
	var steering=Vector3.ZERO;var closest=INF;var fallback=Vector3.ZERO
	for roster in [game.get("kennel"),game.get("barracks")]:
		if roster==null:continue
		for ally in roster.dogs:
			if ally==self or not roster.owns(ally) or ally.dead:continue
			var away=position-ally.position;away.y=0
			var distance=away.length()
			if distance>=1.5:continue
			if distance<1.2:spacing_blocked=true
			var side=away.dot(tangent)
			if absf(side)<.03:side=1 if get_instance_id()>ally.get_instance_id() else -1
			var avoid=tangent*signf(side)*clampf((1.5-distance)/.7,0,1.5)
			steering+=avoid
			if distance<closest:closest=distance;fallback=avoid
	if spacing_blocked and steering.length_squared()<.01:return fallback
	return steering

func tick(delta: float):
	if not active_run():return
	if dead:
		death_left-=delta
		advance_animation(delta)
		if death_left<=0:queue_free()
		return
	recover_to_road()
	tick_healing(delta)
	cooldown_left=maxf(0,cooldown_left-delta);feedback_left=maxf(0,feedback_left-delta)
	target_clock-=delta
	if target_clock<=0 and state not in ["attack","hurt"]:
		acquire_target();target_clock=.32+float(formation_index)*.007
	if not is_on_floor():velocity.y-=28*delta
	if state=="attack":
		attack_age+=delta
		if not hit_done and attack_age>=contact_time():attack_contact()
		velocity.x=0;velocity.z=0
		if attack_age>=attack_duration():state="idle";attack_target=null
	elif state=="hurt":
		hurt_left=maxf(0,hurt_left-delta)
		velocity.x=move_toward(velocity.x,0,delta*20);velocity.z=move_toward(velocity.z,0,delta*20)
		if hurt_left<=0:state="idle"
	else:
		var destination=target.position if valid_target(target) else kennel.spawn_position(formation_index)
		var delta_to=destination-position;delta_to.y=0
		var spacing=companion_spacing(delta_to.normalized())
		var in_reach=valid_target(target) and delta_to.length()<=attack_reach()+target.body_radius
		if in_reach and not spacing_blocked:
			velocity.x=0;velocity.z=0;state="idle"
			if not begin_attack(target):play_animation("idle")
		elif delta_to.length()>.7 or spacing_blocked:
			state="run"
			var direction=spacing.normalized() if in_reach and spacing_blocked else (movement_direction(destination)+spacing*1.8).normalized()
			var speed=float(profile.get("speed",14))
			if in_reach and spacing_blocked:speed=minf(speed,3.5)
			velocity.x=direction.x*speed;velocity.z=direction.z*speed
			model.rotation.y=lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*12))
			play_animation("run")
		else:
			state="idle";velocity.x=0;velocity.z=0;play_animation("idle")
	var before=position;move_and_slide()
	if state=="run" and position.distance_squared_to(before)<.0001:stalled_left+=delta
	else:stalled_left=0
	if stalled_left>1.0:target_clock=0;target=null;stalled_left=0
	advance_animation(delta)
	if health_bar.visible:health_bar.look_at(game.camera_rig.camera.global_position,Vector3.UP)
	marker.scale=Vector3.ONE*(1.0+.06*sin(attack_age*PI*4)) if state=="attack" else Vector3.ONE

func _physics_process(delta):tick(delta)
