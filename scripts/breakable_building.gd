class_name BreakableBuilding
extends Node
# Static scenery keeps its authored rendering/collision until it is destroyed.
const HEALTH=240.0
const MAX_RUBBLE=96
var building: Node3D
var world: Node3D
var bounds: AABB
var max_hp=HEALTH
var hp=HEALTH
var objective_island=-1
var damage_stage=0
var damage_meshes: Array=[]
static var crack_materials: Dictionary={}
var destroyed=false
var label: Label3D
var label_time=0.0
var impact_cooldown=0.0

static func attach(root: Node3D,owner_world: Node3D)->BreakableBuilding:
	var part=BreakableBuilding.new();part.building=root;part.world=owner_world
	root.add_child(part);part.set_process(false)
	var first=true
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		var box=mesh.global_transform*mesh.mesh.get_aabb()
		part.bounds=box if first else part.bounds.merge(box);first=false
	for body in root.find_children("*","StaticBody3D",true,false):body.set_meta("breakable_building",part)
	owner_world.breakable_buildings.append(part)
	return part

func nearest(point: Vector3)->Vector3:
	return Vector3(clampf(point.x,bounds.position.x,bounds.end.x),clampf(point.y,bounds.position.y,bounds.end.y),clampf(point.z,bounds.position.z,bounds.end.z))

func take_hit(amount: float,ticket: Dictionary,point: Vector3):
	if destroyed or amount<=0 or ticket.is_empty():return
	var game=world.get_parent();var hero=game.player
	if ticket.get("generation",-1)!=hero.attack_chain.generation:return
	amount*=hero.attack_chain.damage_for(ticket)
	hero.attack_chain.confirm(ticket);hp=maxf(0,hp-amount)
	var normal=(hero.global_position-bounds.get_center()).normalized()
	var surface=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*hero.growth_multiplier(),bounds.get_center(),1))
	if not surface.is_empty() and from_collider(surface.collider)==self:
		point=surface.position;normal=surface.normal
	update_damage_visual(point,normal)
	game.hud.building_target=self;game.hud.building_target_time=3.0
	game.damage_number(point,int(amount),false)
	if impact_cooldown<=0:
		game.burst(point,Color("dfb783"),4,.65);game.sound("environment_hit",.45)
		impact_cooldown=.12
	if hp<=0:destroy();return
	if not is_instance_valid(label):
		label=Label3D.new();building.add_child(label);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size=32;label.pixel_size=.018;label.modulate=Color("ffd695");label.no_depth_test=true
	label.global_position=point+Vector3.UP;label.text="BUILDING · %d / %d" % [ceili(hp),max_hp]
	label.show();label_time=2;set_process(true)

func update_damage_visual(_point: Vector3,_normal: Vector3):
	var stage=2 if hp<=max_hp*.4 else (1 if hp<=max_hp*.75 else 0)
	if stage<=damage_stage or hp<=0:return
	if not crack_materials.has(stage):
		var material=ShaderMaterial.new();material.shader=preload("res://scripts/building_damage.gdshader")
		material.set_shader_parameter("stage",float(stage));crack_materials[stage]=material
	if damage_meshes.is_empty():damage_meshes=building.find_children("*","MeshInstance3D",true,false)
	for mesh in damage_meshes:mesh.material_overlay=crack_materials[stage]
	if stage==2:lose_roof()
	damage_stage=stage

func lose_roof():
	# Authored roofs are separate pieces. Remove one roof and its matching collision.
	var candidates=[]
	for node in building.find_children("*","Node3D",true,false):
		if (node is MeshInstance3D and str(node.name).trim_prefix("CP_")=="Roof") or node.scene_file_path.ends_with("/edo/roof.glb"):
			candidates.append(node)
	if candidates.is_empty():return
	candidates.sort_custom(func(a,b):return a.global_position.y>b.global_position.y)
	var roof=candidates[0];roof.hide();roof.set_meta("damage_hidden",true)
	for node in building.find_children("*","Node3D",true,false):
		if node is StaticBody3D and (roof.is_ancestor_of(node) or "roof" in str(node.name).to_lower()):
			node.collision_layer=0;node.collision_mask=0
		elif node.scene_file_path.ends_with("/architecture/temple_roof.glb") and absf(node.global_position.y-roof.global_position.y)<.1:
			for body in node.find_children("*","StaticBody3D",true,false):body.collision_layer=0;body.collision_mask=0
	world.get_parent().burst(roof.global_position+Vector3.UP,Color("bea07a"),10,1.4)
	world.invalidate_building_navigation()

func _process(delta):
	impact_cooldown=maxf(0,impact_cooldown-delta)
	label_time-=delta
	if label_time<=0:label.hide();set_process(false)

func destroy():
	if destroyed:return
	destroyed=true;building.set_meta("destroyed",true);building.hide();set_process(false)
	for body in building.find_children("*","StaticBody3D",true,false):
		body.collision_layer=0;body.collision_mask=0
		for shape in body.find_children("*","CollisionShape3D",true,false):shape.set_deferred("disabled",true)
	var game=world.get_parent()
	game.player.grow_from_building()
	world.invalidate_building_navigation()
	game.adventure.building_reward(self,nearest(game.player.global_position))
	# Cosmetic rubble only: no rigid bodies or permanent obstacles to simulate.
	var spare=maxi(0,MAX_RUBBLE-game.get_tree().get_nodes_in_group("building_rubble").size())
	for i in range(mini(8,spare)):
		var point=bounds.get_center()+Vector3(cos(i*2.399963)*2,0,sin(i*2.399963)*2)
		point.y=(building.global_position.y if objective_island>=0 else world.height_at(point.x,point.z))+.25
		var rubble=Geo.box(game,point,Vector3(.7,.4,1.0),Geo.mat("9a7959"))
		rubble.add_to_group("building_rubble");rubble.rotation=Vector3(.15,i*.9,.12)
		var tween=rubble.create_tween();tween.tween_interval(4)
		tween.tween_property(rubble,"scale",Vector3.ONE*.01,.6);tween.tween_callback(rubble.queue_free)
	game.burst(nearest(game.player.global_position)+Vector3.UP,Color("c2ac8b"),10,1.4)
	game.sound("heavy_hit",.7)

static func from_collider(collider)->BreakableBuilding:
	return collider.get_meta("breakable_building") if is_instance_valid(collider) and collider.has_meta("breakable_building") else null

static func hit_area(game: Node,origin: Vector3,radius: float,damage: float,ticket: Dictionary,direction: Vector3=Vector3.ZERO,min_dot: float=-1.0,struck: Dictionary={}):
	var space=game.get_world_3d().direct_space_state
	for part in game.world.breakable_buildings:
		if part.destroyed or struck.has(part.get_instance_id()):continue
		var point=part.nearest(origin);var offset=point-origin
		if offset.length()>radius:continue
		var flat=Vector3(offset.x,0,offset.z)
		if flat.length()>.1 and direction!=Vector3.ZERO and direction.dot(flat.normalized())<min_dot:continue
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point+offset.normalized()*.15,1))
		if not hit.is_empty() and from_collider(hit.collider)!=part:continue
		struck[part.get_instance_id()]=true;part.take_hit(damage,ticket,point)

static func hit_segment(game: Node,a: Vector3,b: Vector3,damage: float,ticket: Dictionary,struck: Dictionary={}):
	var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
	if hit.is_empty():return
	var part=from_collider(hit.collider)
	if part!=null and not struck.has(part.get_instance_id()):
		struck[part.get_instance_id()]=true;part.take_hit(damage,ticket,hit.position)
