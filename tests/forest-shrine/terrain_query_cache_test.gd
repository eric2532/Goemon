extends SceneTree
## Regresses arrow shape/query allocation, stale motion and stale hero exclusion.
## The frozen original query is an independent collision-contact oracle.
const Combat=preload("res://scripts/rogue_roster_combat.gd")
class BareHero extends "res://scripts/player.gd":
	func _ready():pass
	func _physics_process(_delta):pass
var checks=0
var failures=0
var scene: Node3D
var combat
var first_hero
var second_hero
func _initialize():run.call_deferred()
func check(ok: bool,note: String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",note)
	if not ok:failures+=1
func block(position: Vector3,size_: Vector3,layer: int=1):
	var body=StaticBody3D.new();body.collision_layer=layer;body.collision_mask=0
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box;body.add_child(shape)
	scene.add_child(body);body.position=position
func bare_hero(position: Vector3):
	var hero=BareHero.new();hero.position=position;hero.collision_layer=1;hero.collision_mask=0
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.4;capsule.height=2
	collision.shape=capsule;collision.position.y=1;hero.add_child(collision);scene.add_child(hero);hero.set_physics_process(false)
	return hero
func original_hit(owner,from: Vector3,to: Vector3,radius: float=0.0,sphere_collision: bool=false)->Dictionary:
	if from.distance_squared_to(to)<.000001 or not is_instance_valid(owner.hero) or not owner.hero.is_inside_tree():return {}
	var space=owner.hero.get_world_3d().direct_space_state
	if radius>.01:
		var shape: Shape3D
		if sphere_collision:
			var sphere=SphereShape3D.new();sphere.radius=radius;shape=sphere
		else:
			var box=BoxShape3D.new();box.size=Vector3(radius*2,minf(radius,.22)*2,.08);shape=box
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.exclude=[owner.hero.get_rid()]
		var direction=(to-from).normalized();var up=Vector3.RIGHT if absf(direction.dot(Vector3.UP))>.99 else Vector3.UP
		query.transform=Transform3D(Basis.looking_at(direction,up),from)
		if not space.intersect_shape(query,1).is_empty():return {"position":from}
		query.motion=to-from
		var fractions=space.cast_motion(query)
		if fractions.size()>=1 and fractions[0]<.99999:return {"position":from.lerp(to,fractions[0])}
		return {}
	var ray=PhysicsRayQueryParameters3D.create(from,to,1);ray.exclude=[owner.hero.get_rid()]
	return space.intersect_ray(ray)
func compare(from: Vector3,to: Vector3,radius: float,sphere: bool,hit_expected: bool,note: String):
	var expected=original_hit(combat,from,to,radius,sphere)
	var actual=combat._terrain_hit(from,to,radius,sphere)
	var equal=actual.is_empty()==expected.is_empty()
	if equal and not actual.is_empty():equal=actual.position.distance_to(expected.position)<.00001
	check(equal and actual.is_empty()!=hit_expected,note)
func run():
	scene=Node3D.new();root.add_child(scene);current_scene=scene
	block(Vector3(0,-.5,0),Vector3(50,1,50))
	block(Vector3(5,1.5,0),Vector3(.3,3,8))
	block(Vector3(0,.3,-10),Vector3(.3,.6,4))
	block(Vector3(2,1,10),Vector3(.3,2,2),2)
	first_hero=bare_hero(Vector3.ZERO);second_hero=bare_hero(Vector3(0,0,10))
	combat=Combat.new();combat.hero=first_hero;scene.add_child(combat)
	await physics_frame;await physics_frame
	var cover_from=Vector3(0,1,0);var cover_to=Vector3(10,1,0)
	compare(cover_from,cover_to,.25,false,true,"Grounded cover contact matches the original query")
	var query=combat.get("_terrain_shape_query")
	var shape=query.shape if query is PhysicsShapeQueryParameters3D else null
	check(query is PhysicsShapeQueryParameters3D and shape is BoxShape3D,"A thick projectile retains its real query and shape for reuse")
	combat._terrain_hit(Vector3(-4,2,10),Vector3(-1,2,10),.25,false)
	var repeated=combat.get("_terrain_shape_query")
	check(query!=null and repeated==query and query.shape==shape and query.transform.origin==Vector3(-4,2,10) and query.motion==Vector3(3,0,0),"Another arrow reuses the same query and same width shape with fresh transform and motion")
	compare(Vector3(5,1,0),Vector3(9,1,0),.25,false,true,"Initial overlap after a prior sweep retains the original immediate contact")
	check(query!=null and query.motion==Vector3.ZERO,"Initial-overlap testing resets the previous projectile motion")
	compare(Vector3(-5,5,0),Vector3(-5,-1,0),.25,false,true,"Vertical thin-wave contact matches the original orientation")
	compare(Vector3(-5,5,0),Vector3(-5,-1,0),.25,true,true,"Vertical sphere contact matches the original sweep")
	compare(Vector3(-5,-.2,0),Vector3(-5,5,0),.2,true,true,"A sphere starting in ground still resolves its initial overlap")
	compare(Vector3(0,1.2,4.45),Vector3(10,1.2,4.45),.2,false,false,"A narrow wave passes beside the cover")
	compare(Vector3(0,1.2,4.45),Vector3(10,1.2,4.45),.8,false,true,"A wide wave retains the cover-edge contact")
	check(shape!=null and shape.size==Vector3(.5,.44,.08),"Using a wider wave does not mutate the cached narrow shape")
	compare(Vector3(-4,1.2,-10),Vector3(4,1.2,-10),.8,false,false,"A thin wave passes above low cover")
	compare(Vector3(-4,1.2,-10),Vector3(4,1.2,-10),.8,true,true,"A full sphere of the same width contacts low cover")
	var sphere_query=combat.get("_terrain_shape_query")
	var sphere=sphere_query.shape if sphere_query is PhysicsShapeQueryParameters3D else null
	check(sphere is SphereShape3D and sphere!=shape and is_equal_approx(sphere.radius,.8),"Sphere and wave caches retain different immutable geometry at the same width")
	combat._terrain_hit(cover_from,cover_to,.25,false)
	check(query!=null and combat.get("_terrain_shape_query")==query and query.shape==shape,"Returning to a prior width reuses its original wave shape")
	compare(Vector3(-4,2,10),Vector3(-1,2,10),0,false,false,"Ray fallback ignores a collider outside terrain mask one")
	compare(cover_from,cover_to,0,false,true,"Ray fallback retains ordinary cover contact")
	compare(cover_from,cover_from,.25,false,false,"A stationary segment still returns no query contact")
	combat.hero=second_hero
	compare(Vector3(0,1,10),Vector3(3,1,10),.25,false,false,"Changing heroes excludes the new owner and still ignores mask-two cover")
	compare(Vector3(0,1,0),Vector3(3,1,0),.25,false,true,"Changing heroes releases the prior hero from the exclusion list")
	check(query!=null and query.exclude==[second_hero.get_rid()] and query.collision_mask==1,"The reused query retains the current hero RID and terrain mask")
	var other=Combat.new();other.hero=first_hero;scene.add_child(other);other._terrain_hit(cover_from,cover_to,.25,false)
	check(query!=null and other.get("_terrain_shape_query")!=null and other.get("_terrain_shape_query")!=query,"Separate hero facades retain independent query state")
	var eviction_contacts_match=true
	for i in 48:
		for sphere_mode in [false,true]:
			var radius=.02+float(i)*.013
			var from=Vector3(0,1.2,4.45);var to=Vector3(10,1.2,4.45)
			var expected=original_hit(combat,from,to,radius,sphere_mode)
			var actual=combat._terrain_hit(from,to,radius,sphere_mode)
			if expected.is_empty()!=actual.is_empty() or (not actual.is_empty() and actual.position.distance_to(expected.position)>.00001):eviction_contacts_match=false
	var boxes=combat.get("_terrain_box_shapes");var spheres=combat.get("_terrain_sphere_shapes")
	check(boxes is Dictionary and spheres is Dictionary and boxes.size()+spheres.size()<=32,"Varying growth and projectile widths keeps the shape cache bounded")
	check(eviction_contacts_match,"Ninety-six alternating sphere and wave widths preserve original cover contacts across cache evictions")
	scene.queue_free();await process_frame;await process_frame
	print("TERRAIN_QUERY_CACHE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
