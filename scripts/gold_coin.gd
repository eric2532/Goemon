class_name GoldCoin
extends "res://scripts/character_projectile.gd"

var coin_count=1
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
var cross_ornament:Node3D
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
		if cross_slash:
			cross_ornament=ComboEnergy.arc(self,-slash_tilt);cross_ornament.scale=Vector3(1.1,.6,1)*(1.4 if piercing else 1.0)
		ornament.scale=Vector3(1.1,.6,1)*(1.4 if piercing else 1.0)
		look_at(global_position+velocity.normalized(),Vector3.UP if absf(velocity.normalized().y)<.98 else Vector3.RIGHT)
	else:
		if get_meta("original_goemon_coin",false):
			ornament=preload("res://scripts/recovered_goemon_weapons.gd").create_coin(get_meta("original_goemon_charged_coin",false));add_child(ornament);ornament.scale=Vector3.ONE*visual_size
		else:ornament=make_mesh(self,visual_size)
		if game.camera_combat():
			painted_wake=preload("res://assets/rogue/scripts/ink_brush_style.gd").attach_wake(self,Color("ffd487"),visual_size)
			if not velocity.is_zero_approx():painted_wake.quaternion=Quaternion(Vector3.FORWARD,velocity.normalized())

func restart_visual():
	if not is_instance_valid(ornament):return
	ornament.rotation=Vector3.ZERO
	if combo_energy:
		ornament.rotation.z=slash_tilt;ornament.scale=Vector3(1.1,.6,1)*(1.4 if piercing else 1.0)
		if is_instance_valid(cross_ornament):cross_ornament.rotation.z=-slash_tilt;cross_ornament.scale=ornament.scale
		look_at(global_position+velocity.normalized(),Vector3.UP if absf(velocity.normalized().y)<.98 else Vector3.RIGHT)
	else:ornament.scale=Vector3.ONE*visual_size
	if is_instance_valid(painted_wake):
		painted_wake.scale=Vector3.ONE*visual_size
		painted_wake.quaternion=Quaternion(Vector3.FORWARD,velocity.normalized())
	for material in get_meta("ink_materials",[]):material.set_shader_parameter("brush_clock",0.0)

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning: return
	if is_instance_valid(painted_wake):preload("res://assets/rogue/scripts/ink_brush_style.gd").animate(self,delta)
	lifetime-=delta
	if lifetime<=0:
		retire()
		return
	var next=global_position+velocity*delta
	# Sweep the entire travelled segment, so fast coins cannot tunnel through walls.
	var wall=AttackChain.world_ray(self,global_position,next,3 if hostile else 1)
	var end=next if wall.is_empty() else wall.position
	if not hostile:
		var targets=AttackChain.segment_enemy_candidates(game,global_position,end,hit_radius)
		if get_meta("original_goemon_charged_coin",false):
			var nearest=_nearest_charged_target(end)
			targets=[nearest] if is_instance_valid(nearest) else []
		for victim in targets:
			if not is_instance_valid(victim) or victim.dead or hit_enemies.has(victim.get_instance_id()): continue
			var contact=AttackChain.segment_contact(victim,global_position,end,hit_radius)
			if contact.is_empty():continue
			var point=AttackChain.aim_point(victim,contact.point)
			var nearest: Vector3=contact.point
			if not AttackChain.clear_line(self,nearest,point,[],false):continue
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
				retire()
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
		retire()
		return
	global_position=next
	update_visual(delta)

func impact(point: Vector3):
	if get_meta("original_goemon_charged_coin",false) and get_meta("original_goemon_coin",false):
		preload("res://scripts/recovered_goemon_charge_vfx.gd").impact(game,point,original_impact_scale)

func _nearest_charged_target(end:Vector3)->Ninja:
	var nearest:Ninja
	var first=INF
	for victim in AttackChain.segment_enemy_candidates(game,global_position,end,hit_radius):
		if not is_instance_valid(victim) or victim.dead or hit_enemies.has(victim.get_instance_id()):continue
		var contact=AttackChain.segment_contact(victim,global_position,end,hit_radius)
		if contact.is_empty() or float(contact.t)>=first:continue
		var point=AttackChain.aim_point(victim,contact.point)
		if not AttackChain.clear_line(self,contact.point,point,[],false):continue
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
