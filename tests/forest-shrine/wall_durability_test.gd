extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
const EmptySettlement=preload("res://tests/forest-shrine/empty_settlement.gd")
var checks=0
var failures=0

func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)

func run():
	starter_and_authored_walls()
	construction_and_incoming_damage()
	damaged_gate_split_and_repair()
	print("FOREST_WALL_DURABILITY_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)

func starter_and_authored_walls():
	var m=Model.new();m.reset(42)
	var full_walls=m.buildings.values().filter(func(b):return b.kind=="wall" and b.span==6)
	var short_walls=m.buildings.values().filter(func(b):return b.kind=="wall" and b.span==1)
	check(not full_walls.is_empty() and full_walls.all(func(b):return b.hp==7500 and b.max_hp==7500),"Fresh six-tile fort walls start with five times the former 1500 HP")
	check(not short_walls.is_empty() and short_walls.all(func(b):return b.hp==1250 and b.max_hp==1250),"Short fort ends retain proportional health at 1250 HP per tile")
	check(m.shrine().hp==3000,"Shrine health is unchanged")
	check(m.buildings.values().filter(func(b):return b.kind=="tower").all(func(b):return b.hp==500),"Tower health is unchanged")
	check(m.buildings.values().filter(func(b):return b.kind=="gate").all(func(b):return b.hp==2000),"Gate health is unchanged")
	var long_wall=m._make_building("wall",Vector2i(-12,12),0,12)
	check(long_wall.hp==15000 and long_wall.max_hp==15000,"Long wall health still scales with its twelve-tile span")
	var doc=Document.new()
	var saved_layout={"format":"forest_shrine_map","schema":1,"title":"Existing wall map","buildings":[
		{"kind":"wall","x":4,"z":4,"rotation":0,"span":6},
		{"kind":"wall","x":12,"z":4,"rotation":1,"span":2}
	],"trees":[],"deposits":[]}
	var error=doc.decode(JSON.stringify(saved_layout))
	check(error.is_empty(),"An existing schema-one map with authored wall spans still loads")
	if not error.is_empty():return
	m.reset(42,{},doc.data)
	check(m.buildings[m.occupancy[Vector2i(4,4)]].hp==7500,"A loaded full wall receives current durability without changing its saved map")
	check(m.buildings[m.occupancy[Vector2i(12,4)]].hp==2500,"A loaded short wall receives span-proportional durability")

func construction_and_incoming_damage():
	var m=Model.new();EmptySettlement.reset(m)
	for x in range(4,16):m.explored[Vector2i(x,4)]=true
	var before=m.gold
	var walls=m.build_wall_line([Vector2i(4,4),Vector2i(10,4)],0)
	check(walls.size()==2 and m.gold==before-20,"A wall drag keeps its construction cost and creates both sections")
	if walls.size()!=2:return
	var wall: Dictionary=walls[0]
	check(wall.hp==7500 and wall.max_hp==7500,"A newly built wall starts at the increased maximum")
	m.phase="wave"
	# Former 1500 HP walls broke on the tenth 150-damage hit. The same real
	# damage operation must now take fifty hits, without scaling incoming damage.
	for hit in range(49):m.damage_building(wall.id,150)
	check(m.buildings.has(wall.id) and wall.hp==150,"A wall survives forty-nine unchanged 150-damage hits")
	check(m.occupancy.get(Vector2i(4,4))==wall.id and m.allied_grid.is_point_solid(Vector2i(4,4)),"A nearly broken wall still blocks its occupied ground")
	m.damage_building(wall.id,150)
	check(not m.buildings.has(wall.id),"The fiftieth identical hit destroys the wall, five times the former ten hits")
	check(not m.occupancy.has(Vector2i(4,4)) and not m.allied_grid.is_point_solid(Vector2i(4,4)),"Destroying the stronger wall still clears occupancy and navigation")

func damaged_gate_split_and_repair():
	var m=Model.new();EmptySettlement.reset(m)
	for x in range(4,10):m.explored[Vector2i(x,4)]=true
	var wall=m.build("wall",Vector2i(4,4),0)
	check(not wall.is_empty(),"Split fixture constructs a real wall")
	if wall.is_empty():return
	m.phase="wave";m.damage_building(wall.id,3000);m.phase="preparing"
	check(m.buildings.has(wall.id),"A wall survives 3000 damage before a gate opening is cut")
	if not m.buildings.has(wall.id):return
	var gate=m.build("gate",Vector2i(6,4),0)
	check(not gate.is_empty(),"A gate can still cut an opening into a damaged wall")
	if gate.is_empty():return
	check(not m.buildings.has(wall.id) and gate.hp==2000,"Splitting removes the old wall and retains the gate's original health")
	var left: Dictionary=m.buildings[m.occupancy[Vector2i(4,4)]]
	var right: Dictionary=m.buildings[m.occupancy[Vector2i(8,4)]]
	check(left.span==2 and right.span==2 and left.max_hp==2500 and right.max_hp==2500,"Both two-tile wall ends retain the stronger proportional maximum")
	check(left.hp==1500 and right.hp==1500,"Cutting a damaged wall preserves its sixty-percent health on both ends")
	var before=m.gold
	check(m.repair(left.id) and m.gold==before-100 and left.hp==2500,"Repair restores the stronger left wall for the existing missing-HP cost")
	before=m.gold
	check(m.repair(right.id) and m.gold==before-100 and right.hp==2500,"Repair restores the stronger right wall for the existing missing-HP cost")
	check(not m.repair(left.id) and m.gold==before-100,"Repairing a full wall still costs nothing")
