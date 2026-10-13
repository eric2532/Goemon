extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42)
	check(m.has_method("start_wave"),"The forest simulation can start and resolve a finite wave")
	if failures:finish();return
	check(m.workers.size()==6,"A new settlement has its starting workforce")
	var mine=m.build("mine",Vector2i(-5,1),0)
	check(not mine.is_empty(),"The starter deposit remains buildable with workers present")
	var initial=m.gold
	m.tick(100,Vector3(0,0,18))
	check(m.gold==initial,"Waiting in preparation never produces gold")
	check(m.start_wave(),"A ready settlement can start the first wave")
	m.waves.spawn_clock=10000
	m.rally(true,Vector3(0,0,18));m.rally(false,Vector3(-24,0,18))
	var assigned=0
	for w in m.workers.values():
		if w.job==mine.id:assigned+=1
	check(assigned==3,"Mine capacity reserves exactly three jobs; surplus workers are idle")
	for i in range(700):m.tick(.1,Vector3(0,0,18))
	check(m.gold>initial,"Workers physically collect and deliver gold")
	var worker=m.workers.values()[0];m.damage_worker(worker.id,1000)
	check(worker.state=="wounded" and worker.job==-1,"Wounding releases the job and removes work for this wave")
	m.rally(true,worker.pos)
	check(not worker.follow,"Wounded workers cannot be recalled")
	m.rally(false,worker.pos)
	m.waves.pending=0;m.enemies.clear();m.tick(.1,Vector3(0,0,18))
	check(m.phase=="preparing" and worker.state=="idle" and worker.hp==worker.max_hp,"Wave completion recovers wounded workers during preparation")
	m.gold=1000
	var wall=m.build("wall",Vector2i(3,5),0)
	var tower=m.build("tower",Vector2i(4,5),0)
	check(not wall.is_empty() and not tower.is_empty(),"Walls and towers fit in the large opening clearing")
	wall.hp=100
	m.start_wave();m.waves.spawn_clock=10000
	for w in m.workers.values():w.pos=Vector3(18,0,24);w.state="idle";w.job=-1
	m.rally(true,Vector3(18,0,24));m.rally(false,Vector3(18,0,30))
	var repairers=0
	for w in m.workers.values():
		if w.job==wall.id:repairers+=1
	check(repairers==2,"Nearby damaged wall receives repairers before a farther mine")
	var before=wall.hp
	for i in range(100):m.tick(.1,Vector3(18,0,24))
	check(wall.hp>before,"Assigned workers restore real wall health")
	m.damage_building(wall.id,1000)
	check(not m.buildings.has(wall.id) and not m.occupancy.has(Vector2i(3,5)),"Destroyed walls immediately clear navigation occupancy")
	check(m.enemies.is_empty(),"Delayed wave fixture does not create unintended enemies")
	m.reset(42);m.workers.clear();m.gold=10000
	m.build("gate",Vector2i(0,5),0)
	for x in range(-3,4):
		m.build("wall",Vector2i(x,-3),0)
		if x not in [0,1]:m.build("wall",Vector2i(x,5),0)
	for y in range(-2,5):
		m.build("wall",Vector2i(-3,y),0);m.build("wall",Vector2i(3,y),0)
	check(not m.route(Vector2i(0,7),Vector2i(0,2)).is_empty(),"A walled shrine retains its friendly gate route")
	m.start_wave();m.waves.spawn_clock=10000;m.waves.spawn_one()
	var raider=m.enemies.values()[0];raider.pos=Vector3(0,0,48)
	for i in range(1100):m.tick(.1,Vector3(120,0,120))
	check(m.shrine().hp<1000,"Enemies breach blocking defenses and reach a fully enclosed shrine")
	finish()
func finish():print("FOREST_SIMULATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
