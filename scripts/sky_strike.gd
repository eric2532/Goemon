class_name SkyStrike
extends RefCounted
# Each tap adds a complete leap / impact / return, with no cooldown between casts.
const OUT_TIME=.24
const BACK_TIME=.19
const BLAST_RADIUS=5.0
var attack_ticket: Dictionary={}
var hero: Hero
var active=false
var elapsed=0.0
var pending=0
var origin=Vector3.ZERO
var landing=Vector3.ZERO
var target: Ninja
var previous_target=0
var landed=false
var trail_left=0.0
var arc_height=6.0
func _init(player):hero=player
func request():
	if active:
		pending=mini(pending+1,8)
		return
	begin()
func choose_target()->Ninja:
	var nearest: Ninja
	var closest=INF
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		if hero.game.has_method("forest_enemy_visible") and not hero.game.forest_enemy_visible(enemy):continue
		if hero.game.descent_mode and enemy.island_index>=0 and enemy.island_index!=hero.game.encounters.current_island:continue
		var distance=hero.global_position.distance_squared_to(enemy.global_position)
		if distance<closest:nearest=enemy;closest=distance
	return nearest
func begin()->bool:
	target=choose_target()
	if target==null:
		pending=0;hero.game.toast("T · No enemies remaining in this area")
		return false
	var saved_pending=pending;var last_target=previous_target;var selected=target
	hero.cancel_charge(false,hero.game.rogue_battle_mode);pending=saved_pending;previous_target=last_target;target=selected
	hero.attack_left=0;hero.heavy_buffer=0;hero.queued=false
	hero.reset_wall_jump()
	hero.jump_buffer=0;hero.jump_windup=0;hero.dodge_time=0;hero.air_turn=0
	origin=hero.global_position
	var direction=target.global_position-origin;direction.y=0;direction=direction.normalized()
	landing=target.global_position-direction*(target.body_radius+.65)
	landing.y=hero.game.world.surface_height_at(landing)+.1
	# Validate the capsule along the complete arc before committing to the movement.
	arc_height=6.0
	var clear=path_clear(arc_height)
	if not clear:
		arc_height=2.8;clear=path_clear(arc_height)
	if not clear:
		# Preserve the original close-range arcs; lift only when a longer route needs clearance.
		for height in [12.0,24.0,48.0,96.0,192.0,384.0,768.0]:
			arc_height=height
			if path_clear(arc_height):clear=true;break
	if not clear:
		pending=0;hero.game.toast("T · Leap path is blocked");return false
	attack_ticket=hero.attack_chain.begin("sky_strike")
	active=true;elapsed=0;landed=false;trail_left=0
	hero.facing=direction;hero.velocity=Vector3.ZERO;hero.impact_pause=0
	hero.game.burst(origin+Vector3.UP*.2,Color("78dfff"),20)
	SkySmoke.emit(hero.game,origin,false)
	hero.game.sound("sky_leap",.85)
	if hero.attack_chain.unleashed():
		impact();active=false;hero.attack_left=0
	return true
func arc(t: float)->Vector3:
	return origin.lerp(landing,t)+Vector3.UP*sin(t*PI)*arc_height
func path_clear(height: float)->bool:
	var shape=CapsuleShape3D.new();shape.radius=.38*hero.growth_multiplier();shape.height=1.85*hero.growth_multiplier()
	var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	var last=origin
	for i in range(1,25):
		var t=float(i)/24
		var next=origin.lerp(landing,t)+Vector3.UP*sin(t*PI)*height
		query.transform=Transform3D(Basis.IDENTITY,last+Vector3.UP*.95*hero.growth_multiplier());query.motion=next-last
		var sweep=hero.get_world_3d().direct_space_state.cast_motion(query)
		if sweep[0]<.99:return false
		last=next
	return true
func tick(delta: float):
	delta*=hero.attack_speed_multiplier()
	elapsed+=delta
	if not landed and elapsed>=OUT_TIME:
		landed=true;hero.global_position=landing;impact()
	var t=clampf(elapsed/OUT_TIME,0,1) if not landed else 1-clampf((elapsed-OUT_TIME)/BACK_TIME,0,1)
	hero.global_position=arc(t)
	hero.model.visible=true
	hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	hero.model.charge_requested=false;hero.model.charge_release=-1;hero.model.pipe_combo_active=false
	hero.model.locomotion.free_feet=true
	hero.model.locomotion_velocity=Vector3.ZERO
	var strike_pose=.15+smoothstep(.68,.96,t)*.7 if not landed else .9
	hero.model.animate(delta,0,false,-18 if t>.6 else 18,1.0-strike_pose,true,3,false)
	hero.model.body.rotation.x=lerpf(-.25,.6,t)
	trail_left-=delta
	if trail_left<=0:
		trail_left=.035;hero.game.wind(hero.global_position+Vector3.UP,-hero.facing)
		var echo=Geo.sphere(hero.game,hero.global_position+Vector3.UP,Vector3(.3,.65,.3),Geo.mat("7ee3ff",0,1))
		var tween=echo.create_tween();tween.tween_property(echo,"scale",Vector3.ONE*.01,.18);tween.tween_callback(echo.queue_free)
	if elapsed>=OUT_TIME+BACK_TIME:
		hero.global_position=origin;hero.velocity=Vector3.ZERO;active=false
		hero.model.locomotion.free_feet=false;hero.model.body.rotation=Vector3.ZERO
		hero.game.burst(origin+Vector3.UP*.2,Color("b6f4ff"),8,.5)
		if pending>0:
			pending-=1;begin()
func impact():
	SkySmoke.emit(hero.game,landing,true)
	hero.game.sound("sky_stomp",1.0)
	hero.game.burst(landing+Vector3.UP*.4,Color("ffdf86"),30,1.4)
	hero.game.camera_rig.kick(Vector3.DOWN,.13)
	var radius=BLAST_RADIUS*hero.pickup_multiplier("range")*hero.growth_multiplier()
	BreakableBuilding.hit_area(hero.game,landing+Vector3.UP,radius,160*hero.damage_multiplier(),attack_ticket)
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		if hero.game.has_method("forest_enemy_visible") and not hero.game.forest_enemy_visible(enemy):continue
		var offset=enemy.global_position-landing
		if Vector2(offset.x,offset.z).length()>radius+enemy.body_radius or absf(offset.y)>3.5:continue
		var ray=PhysicsRayQueryParameters3D.create(landing+Vector3.UP,enemy.global_position+Vector3.UP,1)
		if not hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		var direction=offset.normalized() if offset.length()>.01 else hero.facing
		enemy.take_hit(160*hero.damage_multiplier(),direction,true,attack_ticket)
		hero.game.impact_effect(enemy.global_position+Vector3.UP,direction,2)
		hero.game.chain+=1;hero.game.chain_timer=3

func cancel():
	if active:hero.global_position=origin;hero.velocity=Vector3.ZERO
	active=false;pending=0;previous_target=0;target=null
	if is_instance_valid(hero.model):hero.model.locomotion.free_feet=false;hero.model.body.rotation=Vector3.ZERO
