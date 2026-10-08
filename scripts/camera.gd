class_name ActionCamera
extends Node3D

var player: Hero
var game: Node
var camera: Camera3D
var yaw=0.0
var pitch=0.36
var distance=14.0
var current_distance=14.0
var follow=Vector3.ZERO
var impulse=0.0
var sens=1.0
var kick_direction=Vector2.ZERO
var kick_strength=0.0
var kick_age=1.0

func kick(direction: Vector3, strength: float):
	if kick_age<0.06 and strength<kick_strength:return
	kick_direction=Vector2(direction.dot(camera.global_basis.x),direction.y*0.5+0.35).normalized()
	kick_strength=strength
	kick_age=0.0

func _ready():
	camera=Camera3D.new()
	camera.fov=63
	camera.near=0.12
	camera.far=3200 if game.descent_mode else 1400
	add_child(camera)
	camera.current=true

func reset_follow():
	if game.rogue_battle_mode and is_instance_valid(game.rogue_view) and game.rogue_view.enabled:
		game.rogue_view.reset();return
	follow=player.global_position+Vector3.UP*1.4*player.growth_multiplier()

func _unhandled_input(event):
	if game.rogue_battle_mode:return
	if not game.playing or game.paused or game.transitioning: return
	var downed_orbit=game.is_fire_siege() and game.encounters.hero_dead and event is InputEventMouseMotion and (event.button_mask&MOUSE_BUTTON_MASK_RIGHT)!=0
	if event is InputEventMouseMotion and (Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or downed_orbit):
		yaw-=event.relative.x*0.0025*sens
		pitch=clampf(pitch+event.relative.y*0.0021*sens,0.14,1.15)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=clampf(distance-0.65,7,18)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=clampf(distance+0.65,7,18)

func _process(delta):
	if not game.playing or not is_instance_valid(player): return
	if game.paused or game.transitioning: return
	if game.rogue_battle_mode:
		game.rogue_view.update_camera(delta);return
	var town=game.world.get("furnished_town")
	if is_instance_valid(town):town.update_cutaway(player.global_position,yaw)
	var indoors=is_instance_valid(town) and town.indoor
	var speed=Vector2(player.velocity.x,player.velocity.z).length()
	var fast=clampf((speed-8)/10,0,1)
	var lead=Vector3(player.velocity.x,0,player.velocity.z)*0.08
	var target=player.global_position+Vector3.UP*1.4*player.growth_multiplier()+lead
	if game.descent_mode:target.y-=clampf(-player.velocity.y*.1,0,3.5)
	if player.sky_strike.active:target=player.sky_strike.origin.lerp(player.sky_strike.landing,.5)+Vector3.UP*(1.4+player.sky_strike.arc_height*.3)
	follow.x=lerpf(follow.x,target.x,1-exp(-delta*22))
	follow.z=lerpf(follow.z,target.z,1-exp(-delta*22))
	follow.y=lerpf(follow.y,target.y,1-exp(-delta*12))
	var desired=distance*sqrt(player.growth_multiplier())+fast*1.2+(1.6 if game.boss_active else 0)
	if player.sky_strike.active:desired=maxf(desired,player.sky_strike.origin.distance_to(player.sky_strike.landing)*.85+10)
	if indoors:desired=8.0
	var view_pitch=maxf(pitch,.74) if indoors else pitch
	var offset=Vector3(sin(yaw)*cos(view_pitch),sin(view_pitch),cos(yaw)*cos(view_pitch))
	var safe=desired
	# Five parallel probes protect the camera volume at doorway and cave edges.
	for probe in [Vector3.ZERO,Vector3(0.24,0,0),Vector3(-0.24,0,0),Vector3(0,0.22,0),Vector3(0,-0.22,0)]:
		var query=PhysicsRayQueryParameters3D.create(follow+probe,follow+offset*desired+probe,1)
		if indoors:query.exclude=town.camera_exclusions
		var hit=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): safe=minf(safe,maxf(0.55,follow.distance_to(hit.position)-0.38))
	current_distance=lerpf(current_distance,safe,1-exp(-delta*(32 if safe<current_distance else 6)))
	current_distance=minf(current_distance,safe+0.08)
	camera.global_position=follow+offset*current_distance
	camera.look_at(follow,Vector3.UP)
	camera.fov=lerpf(camera.fov,63+fast*6,delta*5)
	var bank=-player.velocity.dot(Vector3(cos(yaw),0,-sin(yaw)))*fast*0.0009
	camera.rotation.z=bank
	kick_age+=delta
	impulse=move_toward(impulse,0,delta*1.5)
	if impulse>0:
		camera.h_offset=randf_range(-impulse,impulse)*0.35
		camera.v_offset=randf_range(-impulse,impulse)*0.25
	else:
		camera.h_offset=0
		camera.v_offset=0

	var envelope=exp(-kick_age*32)*cos(kick_age*48)
	camera.h_offset+=kick_direction.x*kick_strength*envelope
	camera.v_offset+=kick_direction.y*kick_strength*envelope
