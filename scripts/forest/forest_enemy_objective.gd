extends Ninja
## Static fort targets share contact/damage behavior; the model owns each HP pool.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Castle=preload("res://scripts/forest/forest_enemy_castle.gd")
var objective_index=0
var section_index=-1
var castle_owner
var local_bounds:AABB
var castle_bounds:AABB
var target_boxes:Array[AABB]=[]
var ruins:Node3D
var visual:Node3D
var physical:StaticBody3D
var seen_hp=-1.0
var seen_camps=-1
var seen_revision=-1
var wall_damage:Array=[]
var castle_impact:Node3D
var castle_art:Dictionary={}
var castle_ruins:Dictionary={}
var sections:Array=[]
var targets:Array=[]
var shown_panel
func data()->Dictionary:
	var camp:Dictionary=game.model.enemy_statue if objective_index<0 else game.model.portals[objective_index]
	return camp.sections[section_index] if section_index>=0 else camp
func _ready():
	set_physics_process(false);set_process(false);collision_layer=4;collision_mask=0;body_radius=0
	PhysicsServer3D.body_set_mode(get_rid(),PhysicsServer3D.BODY_MODE_STATIC)
	max_hp=data().max_hp;hp=data().hp;targets.append(self)
	game.enemy_objective_targets.append(self)
	if not game.enemies.has(self):game.enemies.append(self)
	if section_index>=0:
		for box in Castle.section_boxes(castle_owner.data(),section_index):target_boxes.append(box.grow(.06))
		visual=castle_owner.castle_art.nodes[section_index];castle_impact=castle_owner.castle_impact
		physical=visual.find_children("*","StaticBody3D",true,false)[0]
	else:
		var solid_boxes:Array[AABB]=Castle.statue_boxes(data()) if data().get("castle",false) else [AABB(Vector3(-8.5,0,-8.5),Vector3(17,6,17))]
		if data().get("castle",false):
			for box in solid_boxes:target_boxes.append(box.grow(.06))
		else:target_boxes.append(AABB(Vector3(-9,0,-9),Vector3(18,33,18) if objective_index<0 else Vector3(18,11,18)))
		visual=Node3D.new();add_child(visual)
		if objective_index<0:preload("res://scripts/forest/forest_stone_fort.gd").shrine(visual)
		elif data().get("castle",false):Castle.build_statue(visual,data())
		elif game.model.terrain_source=="wind_meadow":preload("res://scripts/forest/forest_wind_meadow_assets.gd").building(visual,"barracks")
		else:preload("res://scripts/forest/forest_barracks_art.gd").build(visual)
		ruins=Node3D.new();add_child(ruins);ruins.hide()
		physical=StaticBody3D.new();physical.collision_layer=1;physical.collision_mask=0;add_child(physical)
		for box in solid_boxes:
			var shape=BoxShape3D.new();shape.size=box.size
			var collider=CollisionShape3D.new();collider.shape=shape;collider.position=box.get_center();physical.add_child(collider)
	local_bounds=target_boxes[0]
	for box in target_boxes:
		local_bounds=local_bounds.merge(box)
		var shape=BoxShape3D.new();shape.size=box.size
		var collider=CollisionShape3D.new();collider.shape=shape;collider.position=box.get_center();add_child(collider)
	if section_index<0 and data().get("castle",false):
		castle_art=Castle.build(visual,data());castle_ruins=Castle.build_ruins(ruins,data(),castle_art);ruins.show()
		castle_bounds=local_bounds
		var points=PackedVector3Array()
		for box in Castle.boxes(data()):
			castle_bounds=castle_bounds.merge(box.grow(.06));points.append(Vector3(box.get_center().x,2,box.get_center().z))
		castle_impact=preload("res://scripts/forest/forest_castle_impact.gd").new();add_child(castle_impact);castle_impact.setup(points)
		for i in Castle.pieces.size():
			var part=load("res://scripts/forest/forest_enemy_objective.gd").new()
			part.game=game;part.objective_index=objective_index;part.section_index=i;part.castle_owner=self
			add_child(part);sections.append(part);targets.append(part)
	elif section_index<0:
		for offset in [Vector3(-5,.5,2),Vector3(3,.35,-4),Vector3(4,.6,5)]:Geo.box(ruins,offset,Vector3(4,1,3),preload("res://scripts/forest/forest_stone_fort.gd").material())
	if section_index>=0:wall_damage=visual.find_children("WallDamage","",true,false)
	name_tag=Label3D.new();name_tag.position=local_bounds.get_center();name_tag.position.y=local_bounds.end.y+2
	name_tag.font_size=42;name_tag.pixel_size=.025;name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.modulate=Color("ffcb98");name_tag.outline_size=10;add_child(name_tag)
	if section_index>=0 or data().get("castle",false):name_tag.no_depth_test=true;name_tag.font_size=32;name_tag.pixel_size=.018
	if section_index<0 and data().get("castle",false):name_tag.position.y=castle_bounds.end.y+2
	if section_index>=0:name_tag.hide()
	sync()
func sync():
	if section_index<0 and data().get("castle",false) and seen_revision!=data().damage_revision:
		seen_revision=data().damage_revision
		for part in sections:part.sync()
	hp=data().hp;max_hp=data().max_hp
	var camps:int=game.model.active_enemy_camps()
	if hp==seen_hp and camps==seen_camps:return
	seen_hp=hp;seen_camps=camps
	for damage in wall_damage:damage.sync_health(hp,max_hp,0)
	if not wall_damage.is_empty():set_process(hp>0 and wall_damage[0].impact_left>0)
	var title="ENEMY CASTLE STATUE" if objective_index<0 else (["WEST CAMP","EAST CAMP","CASTLE CAMP"][objective_index] if objective_index<3 else "ENEMY CAMP")
	if game.model.terrain_source=="wind_meadow":title=["NORTH FARM","EAST FARM","SOUTH FARM","WEST FARM"][objective_index] if objective_index<4 else "ENEMY FARM"
	if data().get("castle",false):title=title.replace("FARM","SKULLPION STATUE")
	if section_index>=0:title={"wall":"WALL PANEL","gate":"GATE","tower":"GUARD TOWER"}[data().kind]
	name_tag.text=title+"\n"+("DESTROYED" if hp<=0 else ("Destroy the %d camps first"%camps if objective_index<0 and camps>0 else "%d / %d HP"%[ceili(hp),ceili(max_hp)]))
	if hp<=0 and not dead:
		dead=true;collision_layer=0;physical.collision_layer=0;visual.hide();set_process(false)
		for body:StaticBody3D in visual.find_children("*","StaticBody3D",true,false):body.collision_layer=0
		if section_index>=0:
			Castle.breach(castle_owner.castle_art,castle_owner.castle_ruins,section_index);name_tag.hide()
		else:
			ruins.show();name_tag.position=Vector3(0,8,0)
			if not castle_ruins.is_empty():castle_ruins.keep.show()
		game.enemies.erase(self);game.enemy_objective_targets.erase(self)
func _process(delta:float):
	for damage in wall_damage:damage.sync_health(hp,max_hp,delta)
	if wall_damage.is_empty() or wall_damage[0].impact_left<=0:set_process(false)
func combat_candidates(center:Vector3,radius:float)->Array:
	if dead:return []
	var local=center-global_position;var bound=castle_bounds if not sections.is_empty() else local_bounds
	if local.distance_squared_to(local.clamp(bound.position,bound.end))>radius*radius:return []
	var result=[]
	for target in targets:
		if target.dead:continue
		var box:AABB=target.local_bounds
		if local.distance_squared_to(local.clamp(box.position,box.end))<=radius*radius:result.append(target)
	return result
func combat_bounds()->AABB:return AABB(local_bounds.position+global_position,local_bounds.size)
func combat_contact_point(point:Vector3)->Vector3:
	var closest=global_position;var distance=INF
	for local in target_boxes:
		var box=AABB(local.position+global_position,local.size);var candidate=point.clamp(box.position,box.end)
		var next=point.distance_squared_to(candidate)
		if next<distance:distance=next;closest=candidate
	return closest
func combat_aim_point(point:Vector3)->Vector3:return combat_contact_point(point)
func combat_segment_contact(from:Vector3,to:Vector3,radius:float)->Dictionary:
	if dead:return {}
	var first=INF
	for local in target_boxes:
		var span=Contact._box_interval(AABB(local.position+global_position,local.size),from,to,radius)
		if span.x>=0:first=minf(first,span.x)
	return {"t":first,"point":combat_contact_point(from.lerp(to,first))} if is_finite(first) else {}
func combat_segment_hit(from:Vector3,to:Vector3,radius:float)->bool:return not combat_segment_contact(from,to,radius).is_empty()
func combat_knockback(_direction:Vector3,_strength:float,_flinch:float):pass
func apply_rogue_bash(_direction:Vector3):pass
func freeze_for(_seconds:float):pass
func apply_defense_slow(_factor:float,_seconds:float):pass
func take_hit(amount:float,_direction:Vector3,heavy:bool,ticket:Dictionary={}):
	if dead or not is_finite(amount) or amount<=0 or game.model.phase!="wave":return
	if objective_index<0 and game.model.active_enemy_camps()>0:
		game.toast("Destroy the three camps to expose the enemy statue.");return
	var source_ref=ticket.get("source_hero");var source=source_ref.get_ref() if source_ref is WeakRef else game.player
	if not ticket.get("tower",false) and is_instance_valid(source):
		amount*=source.attack_chain.damage_for(ticket);source.attack_chain.confirm(ticket)
	var origin=source.global_position if is_instance_valid(source) else game.player.global_position
	var point=combat_contact_point(origin+Vector3.UP*2)
	if is_instance_valid(castle_impact):game.wall_audio.impact({"id":-1000-objective_index*100-section_index,"point":point,"damage":minf(amount,hp),"max_hp":max_hp,"destroyed":amount>=hp})
	game.model.damage_enemy_objective(objective_index,amount,section_index);sync()
	if not ticket.get("quiet_contact",false):game.damage_number(point,ceili(amount),heavy)
	if is_instance_valid(castle_impact):
		castle_impact.play(to_local(point),dead,section_index<0)
		if not dead:
			if section_index>=0:
				if is_instance_valid(castle_owner.shown_panel):castle_owner.shown_panel.name_tag.hide()
				castle_owner.shown_panel=self
			name_tag.position=to_local(point)+Vector3.UP*4;name_tag.show()
	else:game.burst(point,Color("d7b493"),4,.6)
	if dead:
		if section_index>=0:game.toast("Wall breached — destroy the Skullpion statue inside." if data().kind=="wall" else "Fortification destroyed — the Skullpion statue is still active.")
		else:game.toast("Enemy statue destroyed!" if objective_index<0 else ("Skullpion statue destroyed — reinforcements stopped here." if data().get("castle",false) else "Camp destroyed — reinforcements stopped here."))
