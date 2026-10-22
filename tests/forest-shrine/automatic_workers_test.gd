extends SceneTree

var failures=0
var checks=0

func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)

func _initialize():call_deferred("run")

func fresh():
	var m=load("res://scripts/forest/forest_model.gd").new()
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.gold=10000
	for x in range(-15,16):
		for y in range(-15,16):m.explored[Vector2i(x,y)]=true
	return m

func work(m,seconds: float):
	for i in range(ceili(seconds/.1)):m.workforce.tick(.1,m.hero_position)

func only_worker(m)->Dictionary:
	var w: Dictionary=m.workers.values()[0]
	for id in m.workers.keys():
		if id!=w.id:m.workers.erase(id)
	return w

func run():
	automatic_capacity_and_distance()
	reachable_and_safe_jobs()
	unusable_assignments_find_new_work()
	completed_repairs_release_workers()
	depleted_and_removed_jobs_preserve_cargo()
	manual_orders_and_wounds()
	preparation_reserves_without_production()
	explicit_reassignment()
	print("FOREST_AUTOMATIC_WORKERS_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)

func automatic_capacity_and_distance():
	var m=fresh()
	var west=m.build("mine",Vector2i(-5,1),0)
	var east=m.build("mine",Vector2i(5,1),0)
	for w in m.workers.values():w.pos=m.point(Vector2i(13,12))
	m.phase="wave";work(m,.6)
	check(m.workforce.count_job(west.id)==3 and m.workforce.count_job(east.id)==3,"Idle workers find both distant mines and reserve exactly three slots per mine")
	var jobs={}
	for w in m.workers.values():jobs[w.id]=w.job
	work(m,2)
	check(m.workers.values().all(func(w):return w.job==jobs[w.id]),"Productive assignments stay stable while workers travel")
	var before=m.gold
	work(m,45)
	check(m.gold>before,"Automatically assigned miners reach the mines and deposit real gold")

func reachable_and_safe_jobs():
	var m=fresh()
	var blocked=m.build("mine",Vector2i(-5,1),0)
	var reachable=m.build("mine",Vector2i(5,1),0)
	m.trees[m.entry(blocked)]=1.0;m.rebuild_navigation()
	m.phase="wave";work(m,.6)
	check(m.workforce.count_job(blocked.id)==0 and m.workforce.count_job(reachable.id)==3,"Automatic selection skips an unreachable entrance and fills reachable work")
	m=fresh()
	var danger=m.build("mine",Vector2i(-5,1),0)
	var safe=m.build("mine",Vector2i(5,1),0)
	m.start_wave();m.waves.spawn_one()
	var enemy: Dictionary=m.enemies.values()[0];enemy.pos=m.point(m.entry(danger))
	for w in m.workers.values():w.pos=m.point(Vector2i(0,6))
	work(m,.6)
	check(m.workforce.count_job(danger.id)==0 and m.workforce.count_job(safe.id)==3,"Automatic selection does not send idle workers into an attacked workplace")

func completed_repairs_release_workers():
	var m=fresh()
	var mine=m.build("mine",Vector2i(-5,1),0)
	m.update_vision(m.point(Vector2i(6,4)))
	var door=m.build("gate",Vector2i(4,6),0);door.hp=door.max_hp-10
	m.shrine().hp=m.shrine().max_hp-10
	m.phase="wave";work(m,.1)
	check(m.workforce.count_job(1)==2 and m.workforce.count_job(door.id)==2,"Workers prioritize damaged shrine and door repairs before mining")
	work(m,20)
	check(m.shrine().hp==m.shrine().max_hp and door.hp==door.max_hp,"Automatic repairers restore real shrine and door health")
	check(m.workforce.count_job(1)==0 and m.workforce.count_job(door.id)==0 and m.workforce.count_job(mine.id)==3,"Finished repair jobs release their crews to available mining work")
	m=fresh();m.update_vision(m.point(Vector2i(6,4)))
	door=m.build("gate",Vector2i(4,6),0);door.hp=100
	m.update_vision(m.point(Vector2i(7,3)))
	var tower=m.build("tower",Vector2i(10,4),0)
	m.gold=0;m.phase="wave";work(m,.6)
	check(m.workforce.count_job(door.id)==0 and m.workforce.count_job(tower.id)==3,"Workers avoid unaffordable repairs and staff available defenses")

func unusable_assignments_find_new_work():
	var m=fresh();var w=only_worker(m)
	var west=m.build("mine",Vector2i(-5,1),0)
	var east=m.build("mine",Vector2i(5,1),0)
	m.workforce.assign_idle(west.id)
	m.trees[m.entry(west)]=1.0;m.rebuild_navigation();m.phase="wave";work(m,.6)
	check(w.job==east.id,"A route that becomes blocked releases its reservation and sends the worker to reachable work")
	m=fresh();w=only_worker(m)
	var tower=m.build("tower",Vector2i(4,5),0);tower.hp=20
	m.phase="wave";work(m,20)
	check(w.job==-1 and w.state=="idle","Automatic workers avoid repeatedly entering and evacuating a collapsing tower")
	m=fresh();w=only_worker(m);tower=m.build("tower",Vector2i(4,5),0)
	m.workforce.assign_idle(tower.id);m.phase="wave";work(m,10)
	tower.hp=20;work(m,.1)
	var returned_to_tower=false
	for i in range(200):
		m.workforce.tick(.1,m.hero_position)
		if w.job==tower.id:returned_to_tower=true
	check(not returned_to_tower and w.state=="retreat","An evacuated tower crew waits safely while its saved tower is still collapsing")

func depleted_and_removed_jobs_preserve_cargo():
	var m=fresh();var w=only_worker(m)
	var mine=m.build("mine",Vector2i(-5,1),0)
	var tower=m.build("tower",Vector2i(4,5),0)
	m.deposits[mine.cell]=10;w.pos=m.point(m.entry(mine));m.phase="wave"
	var before=m.gold
	work(m,30)
	check(m.deposits[mine.cell]==0 and m.gold==before+10,"The final finite mine load reaches the treasury exactly once")
	check(w.job==tower.id and w.state=="garrison","A depleted mine releases its last worker to a productive tower job")
	m=fresh();w=only_worker(m);mine=m.build("mine",Vector2i(-5,1),0)
	w.pos=m.point(m.entry(mine));m.workforce.assign_idle(mine.id);m.phase="wave"
	work(m,5.1)
	check(w.cargo==10,"Removal fixture carries a real freshly mined load")
	before=m.gold;m.damage_building(mine.id,10000);work(m,10)
	check(m.gold==before+10 and w.cargo==0 and w.job==-1,"Destroying a workplace preserves cargo and sends it to the shrine even without another job")

func manual_orders_and_wounds():
	var assigned_model=fresh();var assigned_worker=only_worker(assigned_model)
	var assigned_tower=assigned_model.build("tower",Vector2i(4,5),0)
	assigned_model.build("mine",Vector2i(-5,1),0)
	assigned_model.workforce.assign_idle(assigned_tower.id);assigned_model.phase="wave";work(assigned_model,15)
	check(assigned_worker.job==assigned_tower.id and assigned_worker.state=="garrison","A manual tower assignment remains in place when higher-priority mining work is available")
	var m=fresh();var w=only_worker(m)
	var mine=m.build("mine",Vector2i(-5,1),0)
	w.pos=m.point(m.entry(mine));m.workforce.assign_idle(mine.id);m.phase="wave"
	work(m,5.1);var cargo=w.cargo
	m.rally(true,w.pos);work(m,2)
	check(w.follow and w.state=="follow" and w.job==-1 and w.cargo==cargo,"Automatic work respects held rally commands and preserves carried gold")
	m.rally(false,m.center(mine));work(m,.6)
	check(not w.follow and w.job==mine.id,"Releasing a rally keeps its explicit nearby job assignment")
	m.damage_worker(w.id,1000);work(m,2)
	check(w.state=="wounded" and w.job==-1,"Automatic assignment leaves wounded workers out of work")
	m=fresh();w=only_worker(m);mine=m.build("mine",Vector2i(-5,1),0)
	w.pos=m.point(m.entry(mine));m.workforce.assign_idle(mine.id);m.phase="wave";work(m,5.1)
	var before=m.gold
	m.rally(true,w.pos);m.rally(false,m.point(Vector2i(10,10)));work(m,.6)
	check(w.state=="move" and w.job==-1,"A manual rally release without nearby work completes its move before automatic reassignment")
	m.damage_building(mine.id,10000);work(m,45)
	check(w.cargo==0 and m.gold==before+10,"A manual move without a job still deposits its carried load after arriving")

func preparation_reserves_without_production():
	var m=fresh();var mine=m.build("mine",Vector2i(-5,1),0)
	var before=m.gold;var deposit=m.deposits[mine.cell]
	var positions={}
	for w in m.workers.values():positions[w.id]=w.pos
	m.tick(100,m.hero_position)
	check(m.workforce.count_job(mine.id)==3,"Preparation reserves useful work automatically")
	check(m.workers.values().any(func(w):return w.pos!=positions[w.id] and w.state=="mine"),"Preparation workers visibly walk to their reserved workplaces")
	check(m.gold==before and m.deposits[mine.cell]==deposit,"Preparation reservations do not mine or generate unlimited resources")
	m=fresh();m.shrine().hp-=100;before=m.gold;var hp=m.shrine().hp
	if m.workforce.has_method("prepare_tick"):
		for i in range(100):m.workforce.prepare_tick(.1)
	check(m.gold==before-10 and m.shrine().hp==hp+100,"Workers finish preparation repairs and spend only the ten ryo required to restore 100 health")

func explicit_reassignment():
	var m=fresh()
	check(m.workforce.has_method("assign_workers"),"The explicit building command can redirect active workers")
	if not m.workforce.has_method("assign_workers"):return
	var west=m.build("mine",Vector2i(-5,1),0)
	var east=m.build("mine",Vector2i(5,1),0)
	work(m,20)
	var tower=m.build("tower",Vector2i(4,5),0)
	check(m.workforce.assign_workers(tower.id)==3,"A new tower receives three workers even when both mines hold every worker")
	check(m.workforce.count_job(west.id)==3 and m.workforce.count_job(east.id)==0,"The redirect chooses the nearer active miners and leaves the distant mine productive")
	check(m.workforce.assign_workers(tower.id)==0 and m.workforce.count_job(tower.id)==3,"Repeated explicit assignments never exceed the selected building capacity")
	work(m,20)
	check(m.workforce.count_job(tower.id)==3 and m.workforce.count_job(west.id)==3,"Automatic work preserves the explicit tower assignment and the remaining productive mine crew")

	m=fresh();west=m.build("mine",Vector2i(-5,1),0);east=m.build("mine",Vector2i(5,1),0);work(m,20)
	tower=m.build("tower",Vector2i(4,5),0)
	m.workforce.recruit(true);m.workforce.recruit(true)
	var idle_ids=[]
	for w in m.workers.values():
		if w.state=="idle":idle_ids.append(w.id);w.pos=m.point(Vector2i(13,12))
	m.workforce.assign_workers(tower.id)
	check(idle_ids.size()==2 and idle_ids.all(func(id):return m.workers[id].job==tower.id),"Explicit reassignment uses idle workers before interrupting nearer productive crews")
	check(m.workforce.count_job(west.id)+m.workforce.count_job(east.id)==5,"Only the remaining empty tower slot redirects an active miner")

	m=fresh();var carrier=only_worker(m);west=m.build("mine",Vector2i(-5,1),0);tower=m.build("tower",Vector2i(4,5),0)
	carrier.pos=m.point(m.entry(west));m.workforce.assign_idle(west.id);m.phase="wave";work(m,5.1);m.phase="preparing"
	var before=m.gold
	check(carrier.cargo==10 and m.workforce.assign_workers(tower.id)==1 and carrier.cargo==10,"Redirecting a carrier preserves its freshly mined load")
	work(m,20)
	check(m.gold==before+10 and carrier.cargo==0 and carrier.job==tower.id and carrier.state=="garrison","The redirected miner deposits gold before taking up the tower job")
	var origin: Vector3=carrier.pos;var entrance=m.point(m.entry(tower))
	check(m.workforce.assign_workers(west.id)==1 and carrier.pos==origin,"Redirecting a garrison reserves its new job without teleporting off the deck")
	m.workforce.prepare_tick(.1)
	check(carrier.pos.distance_to(origin)<1.0 and carrier.pos.distance_to(entrance)<origin.distance_to(entrance) and carrier.get("deck_height",0)>0,"A redirected garrison descends gradually toward its old tower entrance")
	work(m,20)
	check(carrier.job==west.id and carrier.state=="mine" and not carrier.has("exit_point"),"The redirected garrison completes its exit and reaches the new workplace")

	m=fresh();tower=m.build("tower",Vector2i(4,5),0)
	var protected=m.workers.values()
	for i in range(4):protected[i].state=["wounded","retreat","follow","move"][i]
	protected[2].follow=true
	m.trees[m.entry(tower)]=1.0;m.rebuild_navigation()
	check(m.workforce.assign_workers(tower.id)==0,"Explicit assignment leaves everyone unchanged when the selected workplace is unreachable")
	m.trees.erase(m.entry(tower));m.rebuild_navigation()
	check(m.workforce.assign_workers(tower.id)==2 and protected.slice(0,4).all(func(w):return w.job==-1),"Explicit assignment respects wounded, retreating, following, and manually moving workers")
