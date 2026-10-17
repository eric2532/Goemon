extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	var m=Model.new();m.reset(42)
	check(m.gold==1000000,"A new testing run has one million spendable gold")
	var mines=m.buildings.values().filter(func(b):return b.kind=="mine")
	check(mines.size()==2,"The starting deposits have usable mines")
	check(m.workers.size()==8 and m.workers.values().all(func(w):return w.job!=-1 and w.state in ["travel","garrison"]),"All eight workers start with useful jobs without commands")
	for mine in mines:check(m.workforce.count_job(mine.id)==3,"Each starter mine receives three workers")
	var origins={}
	for w in m.workers.values():origins[w.id]=w.pos
	for i in range(120):m.tick(.1,m.hero_position)
	var miners=m.workers.values().filter(func(w):return m.buildings[w.job].kind=="mine")
	check(miners.all(func(w):return w.state=="mine") and miners.any(func(w):return w.pos!=origins[w.id]),"Starting miners reach both mines during preparation")
	check(m.workers.values().filter(func(w):return w.state=="garrison").size()==2,"Dedicated guards remain ready on both towers")
	check(m.gold==1000000,"Free starter mines and preparation leave the testing treasury intact")
	m.start_wave();m.waves.spawn_clock=10000
	for i in range(200):m.tick(.1,m.hero_position)
	check(m.gold>1000000,"Starting crews deliver mined gold during the first wave")
	m.reset(7)
	check(m.gold==1000000 and m.workers.values().all(func(w):return w.job!=-1),"Retry restores the testing treasury and automatic starting jobs")
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.workers.clear()
	for x in range(-15,16):
		for y in range(-15,16):m.explored[Vector2i(x,y)]=true
	var wall=m.build("wall",Vector2i(-10,7),0)
	check(not wall.is_empty() and range(-10,-4).all(func(x):return m.occupancy.has(Vector2i(x,7))),"A wall occupies six cells along its full length")
	check(m.build("tower",Vector2i(-5,7),0).is_empty(),"The newly extended wall end prevents overlapping construction")
	var gate=m.build("gate",Vector2i(-8,7),0)
	check(not gate.is_empty() and [Vector2i(-10,7),Vector2i(-9,7),Vector2i(-6,7),Vector2i(-5,7)].all(func(c):return m.occupancy.has(c) and m.buildings[m.occupancy[c]].kind=="wall"),"A gate preserves both ends of the doubled wall")
	var before=m.gold
	m.demolish(m.occupancy.get(Vector2i(-10,7),-1));m.demolish(m.occupancy.get(Vector2i(-5,7),-1))
	check(m.gold==before+2,"Split wall refunds remain proportional to the original purchase")
	print("FOREST_TESTING_START_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
