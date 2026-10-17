extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	var m=load("res://scripts/forest/forest_model.gd").new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m)
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
	m.rally(true,Vector3(0,0,18))
	check(m.workforce.has_method("preview_jobs"),"Live commands preview available jobs before release")
	if not m.workforce.has_method("preview_jobs"):finish();return
	var preview=m.workforce.preview_jobs(Vector3(-24,0,18))
	check(preview.mine==3 and preview.idle==3 and m.workers.values().all(func(w):return w.follow),"Preview respects capacity without changing selection or assigning jobs")
	m.rally(false,Vector3(-24,0,18))
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
	for x in range(3,11):
		for y in range(5,7):m.explored[Vector2i(x,y)]=true
	var wall=m.build("wall",Vector2i(3,5),0)
	var tower=m.build("tower",Vector2i(9,5),0)
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
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.workers.clear();m.gold=10000
	for x in range(-12,13):
		for y in range(-12,13):m.explored[Vector2i(x,y)]=true
	for offset in range(0,18,6):
		m.build("wall",Vector2i(-9+offset,-9),0)
		m.build("wall",Vector2i(9,-9+offset),1)
		m.build("wall",Vector2i(-8+offset,9),0)
		m.build("wall",Vector2i(-9,-8+offset),1)
	m.build("gate",Vector2i(0,9),0)
	check(not m.route(Vector2i(0,11),Vector2i(0,2)).is_empty(),"A walled shrine retains its friendly gate route")
	m.start_wave();m.waves.spawn_clock=10000
	# Lantern owns shrine pressure; Raiders now prioritize the targetable hero.
	var raider=m.waves.spawn_enemy(3,Vector3(0,0,72))
	for i in range(1100):m.tick(.1,Vector3(120,0,120))
	check(m.shrine().hp<m.shrine().max_hp,"Enemies breach blocking defenses and reach a fully enclosed shrine")
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.start_wave()
	for attempt in range(8):
		m.waves.pending=10;m.enemies.clear();m.waves.spawn_one()
		if not m.enemies.is_empty():
			var entry: Vector3=m.enemies.values()[0].pos
			check(not m.ALLIED_REGION.has_point(m.cell_of(entry)) and entry.z>absf(entry.x),"Enemies enter from the southern perimeter, attempt %d"%attempt)
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);var threatened_mine=m.build("mine",Vector2i(-5,1),0);m.workforce.assign_idle(threatened_mine.id);m.start_wave()
	m.waves.spawn_one();var threat=m.enemies.values()[0];threat.pos=m.point(m.entry(threatened_mine))
	var fleeing=m.workers.values()[0];fleeing.pos=threat.pos;m.damage_worker(fleeing.id,1)
	var returned_to_threat=false
	for i in range(80):
		m.workforce.tick(.1,Vector3.ZERO)
		if fleeing.job==threatened_mine.id:returned_to_threat=true
	check(not returned_to_threat,"Retreat does not send a worker back to a workplace still under attack")
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m)
	for wave_index in range(5):
		check(m.start_wave(),"Each prepared wave can start")
		for step in range(200):
			m.waves.spawn_clock=0;m.tick(.1,Vector3(0,0,18))
			for id in m.enemies.keys():m.damage_enemy(id,10000)
			if m.phase!="wave":break
	check(m.phase=="victory" and m.wave==5 and not m.start_wave(),"The fifth finite wave ends in victory with no sixth wave")
	finish()
func finish():print("FOREST_SIMULATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
