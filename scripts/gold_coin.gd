class_name GoldCoin
extends Node3D

var coin_count=1
var game: Node
var velocity=Vector3.ZERO
var lifetime=1.6
var damage=20.0
var heavy=false
var hostile=false
var piercing=false
var hit_radius=0.3
var visual_size=1.0
var original_impact_scale=.016
var hit_enemies: Dictionary={}
var hit_buildings: Dictionary={}
var ornament: Node3D
var trail_clock=0.0
var painted_wake: MeshInstance3D
var combo_energy=false
var slash_tilt=0.0
var cross_slash=false
var attack_ticket: Dictionary={}

static func make_mesh(parent: Node3D, size: float=1.0) -> Node3D:
	return GameAssets.place(parent,"weapons/koban",Vector3.ZERO,Vector3.ONE*size)

func _ready():
	add_to_group("projectiles")
	process_mode=Node.PROCESS_MODE_PAUSABLE
	if hostile:
		ornament=Node3D.new()
		add_child(ornament)
		Geo.spike(ornament,Vector3(0,-0.35,0),Vector3(0,0.35,0),0.17,Geo.mat("ca78ec",0.4,0.6))
	elif combo_energy:
		ornament=ComboEnergy.arc(self,slash_tilt)
		if cross_slash:ComboEnergy.arc(self,-slash_tilt).scale=Vector3(1.1,.6,1)*(1.4 if piercing else 1.0)
		ornament.scale=Vector3(1.1,.6,1)*(1.4 if piercing else 1.0)
		look_at(global_position+velocity.normalized(),Vector3.UP if absf(velocity.normalized().y)<.98 else Vector3.RIGHT)
	else:
		if get_meta("original_goemon_coin",false):
			ornament=preload("res://scripts/recovered_goemon_weapons.gd").create_coin();add_child(ornament);ornament.scale=Vector3.ONE*visual_size
		else:ornament=make_mesh(self,visual_size)
		if game.camera_combat():
			painted_wake=preload("res://assets/rogue/scripts/ink_brush_style.gd").attach_wake(self,Color("ffd487"),visual_size)
			painted_wake.quaternion=Quaternion(Vector3.FORWARD,velocity.normalized())

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning: return
	if is_instance_valid(painted_wake):preload("res://assets/rogue/scripts/ink_brush_style.gd").animate(self,delta)
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
		var targets=game.enemies
		if get_meta("original_goemon_charged_coin",false):
			var nearest=_nearest_charged_target(end)
			targets=[nearest] if is_instance_valid(nearest) else []
		for victim in targets:
			if not is_instance_valid(victim) or victim.dead or hit_enemies.has(victim.get_instance_id()): continue
			var contact=AttackChain.segment_contact(victim,global_position,end,hit_radius)
			if contact.is_empty():continue
			var point=AttackChain.aim_point(victim,contact.point)
			var nearest: Vector3=contact.point
			var sight=PhysicsRayQueryParameters3D.create(nearest,point,1)
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): continue
			hit_enemies[victim.get_instance_id()]=true
			victim.take_hit(damage,velocity.normalized(),heavy,attack_ticket)
			if attack_ticket.get("allied",false):game.confirm_ally_impact(victim,nearest,velocity.normalized(),2 if heavy else 0,true,1 if get_meta("original_goemon_coin",false) else 0)
			else:
				if get_meta("original_goemon_coin",false):game.confirm_impact(victim,nearest,velocity.normalized(),2 if heavy else 0,true,1)
				else:game.confirm_impact(victim,nearest,velocity.normalized(),2 if heavy else 0,true)
				game.chain+=1
				game.chain_timer=3
			preload("res://scripts/recovered_goemon_audio.gd").charged_coin_contact(self)
			if not piercing:
				impact(nearest)
				queue_free()
				return
	if not wall.is_empty():
		if hostile and wall.collider is Hero: wall.collider.take_hit(damage,velocity.normalized(),true)
		if not hostile:
			var building=BreakableBuilding.from_collider(wall.collider)
			if building!=null:
				hit_buildings[building.get_instance_id()]=true;building.take_hit(damage,attack_ticket,end)
			game.sound("environment_hit",0.35)
		impact(end)
		game.burst(end,Color("cf90f3") if hostile else Color("ffe291"),7)
		queue_free()
		return
	global_position=next
	update_visual(delta)

func impact(point: Vector3):
	if get_meta("original_goemon_charged_coin",false) and get_meta("original_goemon_coin",false):
		preload("res://scripts/recovered_goemon_charge_vfx.gd").impact(game,point,original_impact_scale)

func _nearest_charged_target(end:Vector3)->Ninja:
	var nearest:Ninja
	var first=INF
	for victim in game.enemies:
		if not is_instance_valid(victim) or victim.dead or hit_enemies.has(victim.get_instance_id()):continue
		var contact=AttackChain.segment_contact(victim,global_position,end,hit_radius)
		if contact.is_empty() or float(contact.t)>=first:continue
		var point=AttackChain.aim_point(victim,contact.point)
		var sight=PhysicsRayQueryParameters3D.create(contact.point,point,1)
		if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
		nearest=victim;first=float(contact.t)
	return nearest

func update_visual(delta: float):
	if not combo_energy:
		ornament.rotation.z+=delta*24
		ornament.rotation.y+=delta*8
	trail_clock-=delta
	if trail_clock<=0:
		trail_clock=0.09
		if not combo_energy:game.wind(global_position,-velocity.normalized())
