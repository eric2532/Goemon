class_name EdoMeteorRain
extends Node3D
# One cast owns the falling fireballs. Damage happens once per impact.
var game: Node
var hero: Hero
var targets: Array[Vector3]=[]
var damage=240.0
var radius=5.5
var elapsed=0.0
var impacts=0
var strikes: Array[Dictionary]=[]

static func ground_point(player: Hero,point: Vector3)->Variant:
	var bounds=player.game.world.playable_bounds.grow(-2)
	point.x=clampf(point.x,bounds.position.x,bounds.end.x)
	point.z=clampf(point.z,bounds.position.y,bounds.end.y)
	point.y=player.game.world.height_at(point.x,point.z)
	if point.y<0:return null
	var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*80,point-Vector3.UP*3,1)
	var hit=player.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.5:return null
	return hit.position+Vector3.UP*.08

static func choose_targets(player: Hero,count: int,reach: float)->Array[Vector3]:
	var result: Array[Vector3]=[]
	var candidates: Array[Vector3]=[]
	for enemy in player.game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position)<=reach:
			candidates.append(enemy.global_position)
	candidates.sort_custom(func(a,b):return a.distance_squared_to(player.global_position)<b.distance_squared_to(player.global_position))
	# Select separated enemy groups first, rather than spending every meteor on one mob.
	for candidate in candidates:
		var spaced=true
		for chosen in result:
			if Vector2(candidate.x-chosen.x,candidate.z-chosen.z).length()<7:spaced=false;break
		if not spaced:continue
		var point=ground_point(player,candidate)
		if point==null:continue
		result.append(point)
		if result.size()==count:return result
	var center=player.global_position+player.facing*16
	if not result.is_empty():center=result[0]
	# Empty areas and dense packs still receive a broad, full-sized rainfall.
	for attempt in range(160):
		var angle=attempt*2.399963
		var distance=8.0+float(attempt%7)*3.5
		var point=ground_point(player,center+Vector3(cos(angle),0,sin(angle))*distance)
		if point==null:continue
		var spaced=true
		for chosen in result:
			if chosen.distance_to(point)<6:spaced=false;break
		if not spaced:continue
		result.append(point)
		if result.size()==count:return result
	# Use verified ground as a last resort on very small platforms.
	if result.is_empty():
		var floor_point=ground_point(player,player.global_position)
		result.append(floor_point if floor_point!=null else player.global_position)
	while result.size()<count:result.append(result[0])
	return result

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	add_to_group("projectiles");add_to_group("edo_meteor_rains")
	for i in range(targets.size()):
		var point=targets[i]
		var ball=Node3D.new();add_child(ball);ball.hide()
		var core=FireEnergy.new();core.charged=true;ball.add_child(core);core.scale=Vector3.ONE*3.5
		# A tapered tail points back up the falling path.
		Geo.spike(ball,Vector3.UP*.2,Vector3.UP*5,.7,Geo.mat("ff6b18",0,1.7))
		Geo.spike(ball,Vector3.UP*.2,Vector3.UP*3,.36,Geo.mat("ffe595",0,2))
		strikes.append({"point":point,"start":point+Vector3.UP*(28+i%4*3),"delay":.12+i*.065,"flight":.72+float(i%3)*.06,"done":false,"ball":ball})
	for mesh in find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _physics_process(delta):
	if not is_instance_valid(hero) or hero.hp<=0 or hero.character_id!=2:queue_free();return
	if not game.playing or game.paused or game.transitioning:return
	elapsed+=delta*hero.attack_speed_multiplier()
	for strike in strikes:
		if strike.done:continue
		var age=elapsed-strike.delay
		if age<0:continue
		if age>=strike.flight:
			strike.done=true;strike.ball.hide();impact(strike.point);continue
		strike.ball.show()
		var t=clampf(age/strike.flight,0,1)
		strike.ball.global_position=strike.start.lerp(strike.point,t*t)
	if impacts==strikes.size():queue_free()

func impact(point: Vector3):
	impacts+=1
	# The exact same Blender-authored flame/smoke burst as Edo's fire dodge.
	EdoFireExplosion.emit(game,point,true,"edo_meteor_impact")
	game.burst(point+Vector3.UP*.4,Color("ffb352"),22,1.4)
	if hero.global_position.distance_to(point)<45:game.camera_rig.kick(Vector3.DOWN,.045)
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var offset=enemy.global_position-point
		if Vector2(offset.x,offset.z).length()>radius+enemy.body_radius or absf(offset.y)>4:continue
		var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,enemy.global_position+Vector3.UP,1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		var direction=offset.normalized() if offset.length()>.01 else hero.facing
		enemy.take_hit(damage,direction,true)
		game.impact_effect(enemy.global_position+Vector3.UP,direction,2)
		game.chain+=1;game.chain_timer=3
