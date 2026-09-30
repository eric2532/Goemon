class_name TownProps
extends RefCounted
## Original Blender street dressing. Only TidefallTown invokes this, with no RNG calls.
## Opaque static meshes: no skeletons, scripts, particles, dynamic lights or NPC nodes.
static func add_to(town: Node3D):
	assert(town.world.area_index==0)
	var kit=Node3D.new();kit.name="TidefallProps";town.add_child(kit)
	# Gate spans the northern street. Solid supports sit outside its 13m opening.
	var gate=ground(kit,town.world,"tidefall_gate",Vector2(-2,52))
	for side in [-1,1]:hull(gate,Vector3(side*7,2.5,0),Vector3(.95,5,.9))
	hull(gate,Vector3(0,4.85,0),Vector3(15,.45,.65))
	# Small counters face the street, in frontage margins away from original routes.
	for item in [["noodle_stall",Vector2(-10.8,30),PI/2],["dumpling_stall",Vector2(-10.8,15),PI/2]]:
		var stall=ground(kit,town.world,item[0],item[1]);stall.rotation.y=item[2]
		hull(stall,Vector3(0,.63,0),Vector3(2.95,1.26,1.5))
	# Quiet wayside arrangement, outside the original principal routes and courts.
	var shrine=ground(kit,town.world,"wayside_shrine",Vector2(-25,26))
	hull(shrine,Vector3(0,1.25,0),Vector3(2.7,2.5,2.25))
	var offering=ground(kit,town.world,"offering_box",Vector2(-25,27.9))
	hull(offering,Vector3(0,.45,0),Vector3(1.44,.9,.8))
	for x in [-27, -23]:
		var stone=ground(kit,town.world,"stone_lantern",Vector2(x,27.5))
		hull(stone,Vector3(0,1,0),Vector3(.78,2,.78))
	# Accessories are attached to existing solid fronts at head height or above.
	for i in [1,2,4,8,13,18,22]:
		var house=town.buildings[i]
		var lantern=GameAssets.place(house,"town_props/paper_lantern",Vector3(3.3,2.05,3.3))
		lantern.name="ShopPaperLantern"
		var sign=GameAssets.place(house,"town_props/bowl_shop_sign",Vector3(-3.05,2.15,3.22))
		sign.name="ShopBowlSign"
	for i in [0,9]:
		var curtain=GameAssets.place(town.buildings[i],"town_props/indigo_noren",Vector3(0,2.15,3.22))
		curtain.name="IndigoNoren"

static func ground(parent: Node3D,world,id: String,p: Vector2)->Node3D:
	var visual=GameAssets.place(parent,"town_props/"+id,Vector3(p.x,world.height_at(p.x,p.y),p.y))
	visual.name=id;visual.set_meta("asset_id","town_props/"+id)
	return visual

static func hull(parent: Node3D,center: Vector3,size: Vector3):
	var body=StaticBody3D.new();body.name="PropCollision";parent.add_child(body)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size
	shape.shape=box;shape.position=center;body.add_child(shape)
