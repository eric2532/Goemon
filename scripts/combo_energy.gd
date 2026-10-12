class_name ComboEnergy
extends RefCounted
# Shared opaque emissive ribbons: no lights, particle bursts or shadow passes.
static var ribbon: ArrayMesh
static var red: StandardMaterial3D
static var core: StandardMaterial3D
const MAX_EFFECTS=24
const MELEE_DAMAGE=24.0

static func warmup():
	if ribbon!=null:return
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		var vertices=[]
		for step in [i,i+1]:
			var t=step/24.0;var a=lerpf(-1.35,1.35,t)
			var width=sin(t*PI)*.32
			vertices.append(Vector3(sin(a)*2,cos(a)*2-1,0))
			vertices.append(Vector3(sin(a)*(2-width),cos(a)*(2-width)-1,0))
		for j in [0,1,2,2,1,3]:
			surface.set_uv(Vector2((i+(1 if j>=2 else 0))/24.0,1.0 if j%2==0 else 0.0));surface.set_normal(Vector3.BACK);surface.add_vertex(vertices[j])
	ribbon=surface.commit()
	red=Geo.mat("ff193b",0,2.4).duplicate();red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;red.cull_mode=BaseMaterial3D.CULL_DISABLED
	core=Geo.mat("ffd1d7",0,2.0).duplicate();core.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;core.cull_mode=BaseMaterial3D.CULL_DISABLED

static func arc(parent: Node3D,tilt: float=0.0)->Node3D:
	warmup()
	var root=Node3D.new();parent.add_child(root);root.rotation.z=tilt
	for inner in [false,true]:
		var ink=preload("res://assets/rogue/scripts/ink_brush_style.gd").material(Color("ffd1d7") if inner else Color("ff193b"),.8,.5 if inner else .9)
		var mesh=Geo.mesh(root,ribbon,Vector3(0,0,.012 if inner else 0),ink)
		mesh.scale=Vector3(.96,.82,1) if inner else Vector3.ONE
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func slash(game: Node3D,point: Vector3,direction: Vector3,size: float=1.0,double: bool=false)->Node3D:
	if game.get_tree().get_nodes_in_group("combo_energy").size()>=MAX_EFFECTS:return null
	var root=Node3D.new();game.add_child(root);root.add_to_group("combo_energy")
	root.position=point;root.rotation.y=atan2(-direction.x,-direction.z)
	root.scale=Vector3.ONE*size
	for i in range(2 if double else 1):
		var sweep=arc(root,-.78 if i==0 else .78)
		sweep.rotation.x=0 if double else -PI*.25
	var tween=root.create_tween().set_parallel(true)
	tween.tween_property(root,"rotation:y",root.rotation.y+.6,.18)
	tween.tween_property(root,"scale",Vector3.ONE*.01,.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(root.queue_free)
	return root

static func melee_attack(hero: Hero,source: Dictionary,reach: float,cross: bool):
	var origin=hero.global_position+Vector3.UP*1.2*hero.growth_multiplier()
	var direction=hero.facing
	var effect=slash(hero.game,origin+direction*2.3*hero.growth_multiplier(),direction,minf(1.5*hero.growth_multiplier(),reach/4.0),cross)
	if effect!=null:
		effect.add_to_group("combo_bonus_attacks");effect.set_meta("cross",cross)
	var ticket=hero.attack_chain.bonus_ticket(source)
	BreakableBuilding.hit_area(hero.game,origin,reach,MELEE_DAMAGE*hero.damage_multiplier(),ticket,direction,.5)
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var offset=enemy.global_position-hero.global_position
		var flat=Vector3(offset.x,0,offset.z)
		if flat.length()>reach+enemy.body_radius or absf(offset.y)>3.5*hero.growth_multiplier():continue
		if flat.length()>.1 and direction.dot(flat.normalized())<.5:continue
		var point=AttackChain.aim_point(enemy)
		if not hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,point,1)).is_empty():continue
		enemy.take_hit(MELEE_DAMAGE*hero.damage_multiplier(),direction,false,ticket)
		hero.game.confirm_impact(enemy,point,direction,1,true)
