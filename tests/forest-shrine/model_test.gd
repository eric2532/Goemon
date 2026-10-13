extends SceneTree
var failures=0
var checks=0
func check(ok: bool, message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	call_deferred("run")
func run():
	var path="res://scripts/forest/forest_model.gd"
	check(ResourceLoader.exists(path),"Forest simulation exists for grid construction and fog")
	if failures:finish();return
	var m=load(path).new();m.reset(42)
	check(m.gold==400 and m.phase=="preparing","A fresh preparation starts with its own treasury")
	check(m.deposits.size()>=2,"Two starter deposits support the opening economy")
	for c in m.deposits:check(m.point(c).length()<48,"Starter deposits are next to the shrine")
	m.update_vision(Vector3(0,0,18))
	var gold=m.gold
	check(m.build("tower",Vector2i(30,30),0).is_empty() and m.gold==gold,"Unexplored placement spends nothing")
	var mine=m.build("mine",Vector2i(-5,1),0)
	check(not mine.is_empty() and m.gold==250,"A real deposit accepts a mine and deducts its price once")
	check(m.build("mine",Vector2i(-5,1),0).is_empty() and m.gold==250,"An occupied deposit cannot charge twice")
	check(m.build("mine",Vector2i(2,4),0).is_empty(),"Mines require an actual deposit")
	m.gold=5
	check(m.build("tower",Vector2i(3,4),0).is_empty() and m.gold==5,"Unaffordable placement cannot spend or build")
	m.gold=400
	var gate=m.build("gate",Vector2i(0,5),0)
	check(not gate.is_empty(),"A gate can be placed in the clearing")
	check(not m.allied_grid.is_point_solid(Vector2i(0,5)),"Gates permit allied pathfinding")
	m.phase="wave"
	check(m.build("wall",Vector2i(4,4),0).is_empty() and m.gold==370,"Construction is unavailable during a wave")
	m.phase="preparing"
	m.update_vision(Vector3(84,0,0))
	check(m.visible_at(Vector3(84,0,0)),"Hero vision reveals the ground at the hero")
	m.update_vision(Vector3(0,0,18))
	check(m.explored_at(Vector3(84,0,0)) and not m.visible_at(Vector3(84,0,0)),"Exploration persists after current sight moves away")
	m.reset(42)
	check(not m.explored_at(Vector3(84,0,0)),"New runs clear fog memory")
	check(m.has_method("build_wall_line"),"Wall drags are an atomic transaction")
	if m.has_method("build_wall_line"):
		m.gold=15
		check(m.build_wall_line([Vector2i(4,4),Vector2i(5,4)],0).is_empty() and m.gold==15,"An unaffordable wall line places nothing")
		m.gold=100
		check(m.build_wall_line([Vector2i(4,4),Vector2i(5,4)],0).size()==2 and m.gold==80,"A valid wall line charges its complete previewed price")
	check(m.entry({"kind":"mine","cell":Vector2i(4,4),"rotation":1})==Vector2i(6,5),"Rotating a mine moves its worker entrance to the rotated front")
	finish()
func finish():
	print("FOREST_MODEL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
