extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh():
	var m=Model.new()
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m)
	m.trees.clear();m.gold=10000;m.rebuild_navigation()
	return m
func keep_workers(m,count_: int):
	while m.workers.size()>count_:m.workers.erase(m.workers.keys().back())
func work(m,seconds: float):
	for i in range(roundi(seconds/.05)):m.workforce.tick(.05,m.hero_position)
func build_(m,kind: String,cell_: Vector2i,rotation_: int=0,span_: int=0)->Dictionary:
	var b=m._make_building(kind,cell_,rotation_,span_);m.rebuild_navigation();return b
func crew(m,id: int)->Array:
	return m.workers.values().filter(func(w):return w.job==id)
func run():
	permanent_walls_do_not_request_repairs()
	busy_miners_repair_and_return()
	busy_garrisons_repair_and_return()
	reachable_door_faces()
	protected_and_exposed_workers()
	repair_rate_and_funds()
	breached_removed_and_rebuilt_doors()
	manual_orders_and_blocked_jobs()
	print("AUTO_WALL_REPAIR_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)

func busy_miners_repair_and_return():
	# Legacy mines exercise reassignment without depending on playable map content.
	var m=fresh()
	var west=build_(m,"mine",Vector2i(-5,1))
	var east=build_(m,"mine",Vector2i(5,1))
	m.deposits[west.cell]=1200;m.deposits[east.cell]=1200
	for i in range(6):
		var w: Dictionary=m.workers.values()[i]
		m.workforce._assign(w,west if i<3 else east)
	var tower=build_(m,"tower",Vector2i(5,5))
	m.workforce.recruit(true)
	var guard: Dictionary=m.workers.values().back()
	m.workforce._assign(guard,tower);guard.state="garrison";guard.pos=m.center(tower)
	var door=build_(m,"gate",Vector2i(-7,-5))
	var guards=crew(m,tower.id)
	var guard_jobs={}
	for w in m.workers.values():
		if w.state=="garrison":guard_jobs[w.id]=w.job
	var mine_jobs={}
	for w in m.workers.values():
		if w.state!="garrison":mine_jobs[w.id]=w.job
	door.hp-=400
	m.workforce.auto_assign()
	check(crew(m,door.id).size()==2,"A fully busy legacy workforce automatically sends two miners to a damaged door")
	check(guard_jobs.keys().all(func(id):return m.workers[id].job==guard_jobs[id] and m.workers[id].state=="garrison"),"Automatic door repairs keep every tower garrison in place")
	work(m,35)
	check(door.hp==door.max_hp,"Workers repair a damaged door between waves")
	check(mine_jobs.keys().all(func(id):return m.workers[id].job==mine_jobs[id]),"Finished repairs restore each borrowed worker's original mine")
	check(guards.size()>0,"Fixture retains the real starting tower crew")
	m=fresh();keep_workers(m,3)
	var mine=build_(m,"mine",Vector2i(-5,1))
	var nearby=m.workers.values()[0];nearby.pos=m.point(Vector2i(2,6))
	m.workforce._assign(nearby,mine)
	var farther=m.workers.values()[1];farther.pos=m.point(Vector2i(-10,10));m.workforce._assign(farther,mine)
	var idle=m.workers.values()[2];idle.pos=m.point(Vector2i(-12,12))
	door=build_(m,"gate",Vector2i(0,8));door.hp-=200
	m.workforce.auto_assign()
	check(idle.job==door.id and nearby.job==door.id and farther.job==mine.id,"Repair dispatch prefers idle workers, then the nearest busy miner")

func busy_garrisons_repair_and_return():
	var m=fresh();keep_workers(m,3)
	var tower=build_(m,"tower",Vector2i(3,4))
	for w in m.workers.values():
		m.workforce._assign(w,tower);w.state="garrison";w.pos=m.center(tower)
	var door=build_(m,"gate",Vector2i(2,8));door.hp-=200
	m.workforce.auto_assign()
	check(crew(m,door.id).size()==2 and crew(m,tower.id).size()==1,"Without mines or idle workers, spare tower guards repair while one guard remains")
	m.gold=0;m.workforce.auto_assign()
	check(crew(m,tower.id).size()==3,"Unfunded repairs immediately return borrowed guards to their tower")
	m.gold=10000;m.workforce.auto_assign()
	work(m,30)
	check(door.hp==door.max_hp and crew(m,tower.id).size()==3 and crew(m,tower.id).all(func(w):return w.state=="garrison"),"Borrowed guards finish repair and return to their original tower")
	m=fresh();keep_workers(m,1);tower=build_(m,"tower",Vector2i(3,4))
	var guard: Dictionary=m.workers.values()[0]
	m.workforce._assign(guard,tower);guard.state="garrison";guard.pos=m.center(tower)
	door=build_(m,"gate",Vector2i(2,8));door.hp-=200;m.workforce.auto_assign()
	check(guard.job==tower.id,"Automatic repairs preserve the final guard in an occupied tower")

func reachable_door_faces():
	for rotation_ in [0,1,2,3]:
		var m=fresh();keep_workers(m,1)
		var door=build_(m,"gate",Vector2i(5,5),rotation_);door.hp-=100
		var w: Dictionary=m.workers.values()[0]
		var inside=Vector2i(5,4) if rotation_%2==0 else Vector2i(4,5)
		w.pos=m.point(inside)
		m.trees[m.entry(door)]=1.0;m.rebuild_navigation()
		m.workforce.auto_assign();work(m,5)
		check(door.hp==door.max_hp,"Door repairs use an accessible nearby face when its default entrance is blocked, rotation %d"%rotation_)
		check(m.cell_of(w.pos).distance_to(inside)<3,"Door repairer stays near the reachable door face, rotation %d"%rotation_)

func protected_and_exposed_workers():
	var m=fresh();keep_workers(m,1)
	var door=build_(m,"gate",Vector2i(-1,6));door.hp-=200
	var w: Dictionary=m.workers.values()[0];w.pos=m.point(Vector2i(0,5))
	m.phase="wave";m.enemies[900]={"id":900,"hp":100.0,"pos":Vector3(0,0,39)}
	m.workforce.auto_assign();work(m,1)
	check(w.job==door.id and w.state=="repair" and door.hp>door.max_hp-200,"An enemy attacking the opposite door face does not chase protected repairers away")
	check(m.cell_of(w.pos).y==5,"Repairer remains on the inner door face under outside attack")
	m.enemies[900].pos=Vector3(0,0,28);work(m,.1)
	check(w.state=="retreat" and w.job==-1,"An enemy on the repairer's exposed side forces a retreat")
	m.workforce.damage(w.id,1000)
	check(w.state=="wounded" and w.hp==0,"Direct damage still wounds exposed workers")

func repair_rate_and_funds():
	var m=fresh();keep_workers(m,1)
	var door=build_(m,"gate",Vector2i(-1,6));door.hp-=200
	var w: Dictionary=m.workers.values()[0];w.pos=m.point(Vector2i(0,5))
	m.gold=20;m.workforce.auto_assign();work(m,1)
	check(is_equal_approx(door.hp,1840) and m.gold==16,"One worker restores 40 HP per second for four integer ryo during preparation")
	m.gold=2;var before=door.hp;work(m,1)
	check(is_equal_approx(door.hp,before+20) and m.gold==0,"Insufficient funds stop repair exactly at the affordable health without negative gold")
	before=door.hp;work(m,2)
	check(door.hp==before and m.gold==0 and w.job==-1,"Unfunded repair workers release the job and never heal for free")
	m.gold=10;door.hp=door.max_hp-3;m.workforce.auto_assign();work(m,1)
	check(door.hp==door.max_hp and m.gold==9,"The final partial repair pulse costs one ryo and never overfills health")
	work(m,1)
	check(m.gold==9,"A full door never consumes further ryo")
	door.hp-=100;m.gold=0;work(m,20)
	m.gold=10;m.workforce.auto_assign();before=door.hp;work(m,.2)
	check(door.hp==before and m.gold==10,"Time without funds cannot accumulate a free immediate repair burst")
	work(m,.05)
	check(door.hp==before+10 and m.gold==9,"Funding a new repair starts the normal quarter-second paid cadence")
	m=fresh();keep_workers(m,2);door=build_(m,"gate",Vector2i(-1,6));door.hp-=10
	for worker in m.workers.values():worker.pos=m.point(Vector2i(0,5))
	m.gold=1;m.workforce.auto_assign();work(m,.5)
	check(door.hp==door.max_hp and m.gold==0,"Two repairers cannot overspend the same last ryo or repair already restored health")

func breached_removed_and_rebuilt_doors():
	var m=fresh();keep_workers(m,1)
	var mine=build_(m,"mine",Vector2i(-5,1))
	var door=build_(m,"gate",Vector2i(-1,6));door.hp=1000
	var w: Dictionary=m.workers.values()[0];w.pos=m.point(Vector2i(0,5));m.workforce._assign(w,mine)
	m.workforce.auto_assign();m.phase="wave"
	var original_id=door.id
	m.damage_building(door.id,10000)
	check(m.buildings.has(original_id) and door.hp==0 and door.breached,"A destroyed door retains its repairable building ID at zero health")
	m.phase="preparing";var before=m.gold;work(m,1)
	check(w.job==door.id and door.hp==40 and m.gold==before-4 and door.breached,"A borrowed miner rebuilds the same zero-health door with the normal paid cadence")
	work(m,50)
	check(door.hp==2000 and not door.breached and door.id==original_id and w.job==mine.id,"Completing the breached door preserves its ID and restores the borrowed miner's prior job")
	# Explicit map removal must still cancel an obsolete repair reservation.
	door.hp-=100;w.pos=m.point(Vector2i(0,5));m.workforce.auto_assign()
	m._remove_building(door.id);m.rebuild_navigation();before=m.gold;work(m,1)
	check(w.job==mine.id and m.gold==before,"Removing a door stops spending and restores the borrowed miner's prior job")
	door=build_(m,"gate",Vector2i(-1,6));door.hp-=100
	m.workforce.auto_assign()
	check(door.id!=original_id and w.job==door.id,"A replacement door receives a new repair assignment without stale building IDs")
	m.phase="wave";m.workforce.damage(w.id,1000);before=door.hp;work(m,1)
	check(w.state=="wounded" and door.hp==before,"A wounded repairer stops repairing immediately")
	m.phase="preparing";m.workforce.recover();m.workforce.auto_assign();work(m,20)
	check(door.hp==door.max_hp,"Recovered workers can repair replacement doors")

func manual_orders_and_blocked_jobs():
	var m=fresh();keep_workers(m,1)
	var w: Dictionary=m.workers.values()[0]
	var door=build_(m,"gate",Vector2i(-1,6));door.hp-=100
	m.phase="wave";m.workforce.rally(true,w.pos);m.workforce.auto_assign()
	check(w.state=="follow" and w.job==-1,"Automatic repair does not override a held manual rally")
	m.workforce.rally(false,m.point(Vector2i(15,15)));m.workforce.auto_assign()
	check(w.state=="move" and w.job==-1,"Automatic repair does not override a manual movement order")
	m=fresh();keep_workers(m,2)
	var blocked=build_(m,"gate",Vector2i(-9,6));blocked.hp-=100
	for x in range(-10,-6):
		m.trees[Vector2i(x,5)]=1.0;m.trees[Vector2i(x,7)]=1.0
	m.trees[Vector2i(-10,6)]=1.0;m.trees[Vector2i(-7,6)]=1.0
	var reachable=build_(m,"gate",Vector2i(4,6));reachable.hp-=100
	m.workforce.auto_assign()
	check(crew(m,blocked.id).is_empty() and crew(m,reachable.id).size()==2,"One inaccessible door never prevents the crew repairing another reachable door")
	var before=reachable.hp
	for x in range(3,7):
		m.trees[Vector2i(x,5)]=1.0;m.trees[Vector2i(x,7)]=1.0
	m.trees[Vector2i(3,6)]=1.0;m.trees[Vector2i(6,6)]=1.0;m.rebuild_navigation()
	work(m,1)
	check(crew(m,reachable.id).is_empty() and reachable.hp==before,"A repair face blocked after assignment releases its workers without remote healing")

func permanent_walls_do_not_request_repairs():
	var m=fresh();keep_workers(m,2)
	var wall=build_(m,"wall",Vector2i(-3,6));m.phase="wave"
	var before=m.gold;m.damage_building(wall.id,100000)
	check(wall.hp==7500 and m.buildings.has(wall.id),"Permanent walls retain full health under incoming attacks")
	# Even an old or externally altered health value must never create wall work.
	wall.hp=7400;m.phase="preparing";m.workforce.auto_assign();work(m,2)
	check(crew(m,wall.id).is_empty() and m.workers.values().all(func(w):return w.job==-1) and wall.hp==7400 and m.gold==before,"Permanent walls never borrow crew, heal, or consume repair ryo")
	check(m.workforce.assign_workers(wall.id)==0 and not m.repair(wall.id) and m.gold==before,"Explicit worker and instant-repair orders cannot spend resources on permanent walls")
