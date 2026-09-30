class_name GoldCoin
extends Node3D

var game: Node
var velocity=Vector3.ZERO
var lifetime=1.6
var damage=20.0
var heavy=false
var hostile=false
var piercing=false
var hit_radius=0.3
var visual_size=1.0
var hit_enemies: Dictionary={}
var ornament: Node3D
var trail_clock=0.0

static func make_mesh(parent: Node3D, size: float=1.0) -> Node3D:
	return GameAssets.place(parent,"weapons/koban",Vector3.ZERO,Vector3.ONE*size)

func _ready():
	add_to_group("projectiles")
	process_mode=Node.PROCESS_MODE_PAUSABLE
	if hostile:
		ornament=Node3D.new()
		add_child(ornament)
		Geo.spike(ornament,Vector3(0,-0.35,0),Vector3(0,0.35,0),0.17,Geo.mat("ca78ec",0.4,0.6))
	else:
		ornament=make_mesh(self,visual_size)

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning: return
	lifetime-=delta
	if lifetime<=0:
		queue_free()
		return
	var next=global_position+velocity*delta
	# Sweep the entire travelled segment, so fast coins cannot tunnel through walls.
	var query=PhysicsRayQueryParameters3D.create(global_position,next,3 if hostile else 1)
	query.hit_from_inside=true
	var wall=get_world_3d().direct_space_state.intersect_ray(query)
	var end=next if wall.is_empty() else wall.position
	if not hostile:
		for victim in game.enemies:
			if not is_instance_valid(victim) or victim.dead or hit_enemies.has(victim.get_instance_id()): continue
			var point=victim.global_position+Vector3.UP*(1.5 if victim.boss else 1.1)
			var nearest=Geometry3D.get_closest_point_to_segment(point,global_position,end)
			if nearest.distance_to(point)>hit_radius+victim.body_radius: continue
			var sight=PhysicsRayQueryParameters3D.create(nearest,point,1)
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): continue
			hit_enemies[victim.get_instance_id()]=true
			victim.take_hit(damage,velocity.normalized(),heavy)
			game.confirm_impact(victim,nearest,velocity.normalized(),2 if heavy else 0,true)
			game.chain+=1
			game.chain_timer=3
			if not piercing:
				impact(nearest)
				queue_free()
				return
	if not wall.is_empty():
		if hostile and wall.collider is Hero: wall.collider.take_hit(damage,velocity.normalized())
		if not hostile: game.sound("environment_hit",0.35)
		impact(end)
		game.burst(end,Color("cf90f3") if hostile else Color("ffe291"),7)
		queue_free()
		return
	global_position=next
	update_visual(delta)

func impact(_point: Vector3):
	pass

func update_visual(delta: float):
	ornament.rotation.z+=delta*24
	ornament.rotation.y+=delta*8
	trail_clock-=delta
	if trail_clock<=0:
		trail_clock=0.09
		game.wind(global_position,-velocity.normalized())
