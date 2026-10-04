class_name DefenseFlameTower
extends DefenseCannon
## A wall-mounted fire projector. Blender owns its model and licking flame
## animation; this controller owns targeting, cover checks and timed damage.

const FLAME_SCENE="res://assets/models/defense/fire_stream.glb"
const TOWER_SCENE="res://assets/models/defense/fire_tower.glb"
const NOZZLE=Vector3(0,1.1,-1.6)
const AUTHORED_LENGTH=6.0
const BURST_DURATION=1.1
const PULSE_INTERVAL=.12
const POOL_DURATION=3.0
const POOL_INTERVAL=.25
static var pool_mesh: ArrayMesh
var flame_visual: Node3D
var flame_animation: AnimationPlayer
var flame_animation_name=""
var burst_left=0.0
var fire_age=0.0
var pulse_left=0.0
var flame_direction=Vector3.FORWARD
var flame_origin=Vector3.ZERO
var damage_pulses=0
var animation_seconds=0.0
var pool_visual: Node3D
var pool_left=0.0
var pool_tick_left=POOL_INTERVAL
var pool_position=Vector3.ZERO
var pool_pending=false
var pool_damage_pulses=0

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	target_clock=float(get_instance_id()%15)/60.0
	cooldown=.3+target_clock
	pivot=Node3D.new();add_child(pivot)
	var model=load(TOWER_SCENE).instantiate();pivot.add_child(model)
	flame_visual=load(FLAME_SCENE).instantiate();add_child(flame_visual)
	flame_visual.set_as_top_level(true);flame_visual.hide()
	for animator in flame_visual.find_children("*","AnimationPlayer",true,false):
		flame_animation=animator;break
	assert(flame_animation!=null,"Blender fire export must contain an AnimationPlayer")
	if flame_animation!=null:
		flame_animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in flame_animation.get_animation_list():
			# Godot consumes Blender's _loop suffix as an import hint.
			if clip=="flame" or "flame_loop" in clip:
				flame_animation_name=clip
				flame_animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
				break
		assert(not flame_animation_name.is_empty(),"Blender fire export must contain flame_loop")
	for mesh in flame_visual.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	badge=Label3D.new();badge.text="FIRE I";badge.position=Vector3(0,3.1,0)
	badge.font_size=28;badge.pixel_size=.018;badge.modulate=Color("ffb261")
	badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED;badge.visibility_range_end=85;add_child(badge)
	refresh_upgrades()

func upgrade(new_level: int):
	level=clampi(new_level,1,3);cooldown=minf(cooldown,.2)
	refresh_upgrades()

func refresh_upgrades():
	if not is_instance_valid(badge):return
	var title="WIDE FIRE" if fire_branch()=="wide" else ("EMBER POOL" if fire_branch()=="pool" else "FIRE")
	badge.text="%s %s" % [title,["I","II","III"][level-1]]
	badge.modulate=Color("ffce70") if fire_branch()=="wide" else (Color("ff8960") if fire_branch()=="pool" else Color("ffb261"))
	if fire_branch()!="pool" and is_instance_valid(pool_visual):pool_left=0;pool_visual.hide()

func attack_range()->float:
	var path_factor=.9 if fire_branch()=="wide" else (.8 if fire_branch()=="pool" else 1.0)
	return [42.0,50.0,58.0][level-1]*sight_factor()*path_factor
func damage()->float:return [200.0,290.0,420.0][level-1]*(1.0+.25*mini(3,upgrade_level("hot_flames")))
func fire_interval()->float:return [2.0,1.8,1.6][level-1]*reload_factor()
func cone_factor()->float:return 1.6 if fire_branch()=="wide" else 1.0
func splash_radius()->float:return (1.0+attack_range()*.16)*cone_factor()
func pool_radius()->float:return 4.0
func pool_damage()->float:return 50.0*(1.0+.25*mini(3,upgrade_level("hot_flames")))

func tick(delta: float):
	if not director.active or not game.playing or game.paused or game.transitioning:return
	tick_pool(delta)
	cooldown=maxf(0,cooldown-delta);target_clock-=delta
	if target_clock<=0:
		acquire_target();target_clock=TARGET_INTERVAL
	if valid_target(target):
		var to_target=target.position-global_position
		pivot.rotation.y=lerp_angle(pivot.rotation.y,atan2(-to_target.x,-to_target.z),minf(1,delta*9))
		if cooldown<=0 and burst_left<=0:fire_at(target)
	if burst_left<=0:
		flame_visual.hide();return
	burst_left=maxf(0,burst_left-delta);fire_age+=delta
	flame_origin=pivot.to_global(NOZZLE)
	if valid_target(target):
		var aim=target.position+Vector3.UP*.95*maxf(1,target.defense_scale)
		flame_direction=(aim-flame_origin).normalized()
	var sweep=sin(fire_age*TAU/.8)*deg_to_rad(6)
	var direction=flame_direction.rotated(Vector3.UP,sweep)
	var length=attack_range()
	var ray=PhysicsRayQueryParameters3D.create(flame_origin,flame_origin+direction*length,1)
	var wall=get_world_3d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():length=maxf(.2,flame_origin.distance_to(wall.position))
	flame_visual.global_position=flame_origin
	flame_visual.look_at(flame_origin+direction,Vector3.UP)
	# Keep the authored tongues, then stretch their forward travel to the
	# physical reach. The root transform never replaces Blender's animation.
	flame_visual.scale=Vector3((1.0+length*.12)*cone_factor(),1.4+length*.055,length/AUTHORED_LENGTH)
	flame_visual.visible=global_position.distance_squared_to(game.player.position)<EFFECT_DISTANCE*EFFECT_DISTANCE
	if flame_animation!=null:
		flame_animation.advance(delta);animation_seconds+=delta
	pulse_left-=delta
	if pulse_left<=0:
		pulse_left=PULSE_INTERVAL
		burn_cone(direction,PULSE_INTERVAL)
	if burst_left<=0:flame_visual.hide()

func fire_at(enemy: Ninja):
	if not valid_target(enemy) or burst_left>0:return
	target=enemy
	var offset=enemy.position-global_position
	pivot.rotation.y=atan2(-offset.x,-offset.z)
	flame_origin=pivot.to_global(NOZZLE)
	flame_direction=(enemy.position+Vector3.UP*.95*maxf(1,enemy.defense_scale)-flame_origin).normalized()
	burst_left=BURST_DURATION;fire_age=0;pulse_left=0
	pool_pending=fire_branch()=="pool"
	cooldown=fire_interval();shots_fired+=1
	if flame_animation!=null:
		flame_animation.play(flame_animation_name)
		flame_animation.seek(0,true)
	if global_position.distance_squared_to(game.player.position)<85*85 and claim_feedback("sound",2):game.sound("fire_cast",.4,true)

func burn_cone(direction: Vector3,seconds: float):
	damage_pulses+=1
	var space=get_world_3d().direct_space_state
	var reach=attack_range()
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.defense_lane<0:continue
		var point=enemy.position+Vector3.UP*.95*maxf(1,enemy.defense_scale)
		var offset=point-flame_origin
		var along=offset.dot(direction)
		if along<0 or along>reach+enemy.body_radius:continue
		var width=(1.0+along*.16)*cone_factor()+enemy.body_radius
		if (offset-direction*along).length_squared()>width*width:continue
		var obstruction=space.intersect_ray(PhysicsRayQueryParameters3D.create(flame_origin,point,1))
		if not obstruction.is_empty():continue
		var feedback=point.distance_squared_to(game.player.position)<60*60 and claim_feedback("number",6)
		var push=direction;push.y=0
		if pool_pending:
			ignite_pool(enemy.position)
			pool_pending=false
		enemy.take_hit(shatter_damage(enemy,damage()*seconds),push,false,{"tower":true,"tower_feedback":feedback,"element":"fire"})

func ignite_pool(point: Vector3):
	# Called only for a real, unobstructed flame hit. A pool never appears
	# through the parapet or behind other cover that stopped the stream.
	pool_position=point
	var floor_ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*12,1)
	var floor_hit=get_world_3d().direct_space_state.intersect_ray(floor_ray)
	if not floor_hit.is_empty():pool_position.y=floor_hit.position.y+.08
	else:pool_position.y=point.y+.04
	pool_left=POOL_DURATION;pool_tick_left=POOL_INTERVAL
	if not is_instance_valid(pool_visual):
		pool_visual=Node3D.new();pool_visual.name="BurningPool";add_child(pool_visual);pool_visual.set_as_top_level(true)
		_prepare_pool_mesh()
		var embers=MeshInstance3D.new();embers.mesh=pool_mesh;embers.material_override=Geo.mat("f45a1a",0,.65)
		embers.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;pool_visual.add_child(embers)
		var rim=Geo.torus(pool_visual,Vector3(0,.015,0),.90,1.0,Geo.mat("ffba40",0,.65))
		rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool_visual.global_position=pool_position;pool_visual.scale=Vector3(pool_radius(),1,pool_radius())
	pool_visual.visible=pool_position.distance_squared_to(game.player.position)<EFFECT_DISTANCE*EFFECT_DISTANCE

static func _prepare_pool_mesh():
	if pool_mesh!=null:return
	var builder=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in range(12):
		var a=float(section)*TAU/12;var b=float(section+1)*TAU/12
		builder.add_vertex(Vector3.ZERO);builder.add_vertex(Vector3(cos(a)*.94,0,sin(a)*.94));builder.add_vertex(Vector3(cos(b)*.94,0,sin(b)*.94))
	for lick in range(6):
		var angle=float(lick)*TAU/6
		var center=Vector3(cos(angle)*.59,.02,sin(angle)*.59)
		var tip=center+Vector3(.05,.65+float(lick%3)*.2,.045)
		var corners=[center+Vector3(.1,0,0),center+Vector3(0,0,.1),center+Vector3(-.1,0,0),center+Vector3(0,0,-.1)]
		for side in range(4):
			builder.add_vertex(corners[side]);builder.add_vertex(corners[(side+1)%4]);builder.add_vertex(tip)
	builder.generate_normals();pool_mesh=builder.commit()

func tick_pool(delta: float):
	if pool_left<=0:return
	var active_delta=minf(maxf(0,delta),pool_left)
	pool_left=maxf(0,pool_left-active_delta);pool_tick_left-=active_delta
	while pool_tick_left<=.00001:
		pool_tick_left+=POOL_INTERVAL
		burn_pool(POOL_INTERVAL)
	if is_instance_valid(pool_visual):
		pool_visual.visible=pool_left>0 and pool_position.distance_squared_to(game.player.position)<EFFECT_DISTANCE*EFFECT_DISTANCE
		pool_visual.rotation.y+=active_delta*.6
		pool_visual.scale.y=.9+.12*sin((POOL_DURATION-pool_left)*11)

func burn_pool(seconds: float):
	pool_damage_pulses+=1
	var space=get_world_3d().direct_space_state
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.defense_lane<0:continue
		var offset=enemy.position-pool_position
		if absf(offset.y)>3 or Vector2(offset.x,offset.z).length_squared()>pow(pool_radius()+enemy.body_radius,2):continue
		var point=enemy.position+Vector3.UP*.95*maxf(1,enemy.defense_scale)
		var ray=PhysicsRayQueryParameters3D.create(pool_position+Vector3.UP*.25,point,1)
		if not space.intersect_ray(ray).is_empty():continue
		var feedback=point.distance_squared_to(game.player.position)<60*60 and claim_feedback("number",6)
		enemy.take_hit(shatter_damage(enemy,pool_damage()*seconds),Vector3.ZERO,false,{"tower":true,"tower_feedback":feedback,"element":"fire","burning_pool":true})

func retire_wave_effects():
	burst_left=0;fire_age=0;pulse_left=0;target=null;cooldown=maxf(cooldown,.3)
	pool_left=0;pool_pending=false
	if is_instance_valid(pool_visual):pool_visual.hide()
	if is_instance_valid(flame_visual):flame_visual.hide()
	if is_instance_valid(flame_animation):flame_animation.pause()
