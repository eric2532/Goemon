extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Arrows=preload("res://scripts/forest/forest_enemy_projectiles.gd")
class CountArrows extends "res://scripts/forest/forest_enemy_projectiles.gd":
	var worker_checks=0
	var candidate_checks=0
	func worker_point(w:Dictionary)->Vector3:
		worker_checks+=1
		return super.worker_point(w)
	func _candidates(rows:Array,grid:Dictionary,from:Vector3,to:Vector3)->Array:
		var result=super._candidates(rows,grid,from,to)
		candidate_checks+=result.size()
		return result
# Freeze the exhaustive flight loop as an independent optimization oracle.
# Literal fixtures below also protect priorities and same-tick damage behavior.
class Exhaustive extends "res://scripts/forest/forest_enemy_projectiles.gd":
	func tick(projectiles: Dictionary,delta: float,hero: Vector3):
		for id in projectiles.keys():
			var a: Dictionary=projectiles[id];var distance=minf(a.left,SPEED*delta);var steps=maxi(1,ceili(distance/.35));var impacted=false
			for step in range(steps):
				var before: Vector3=a.pos;a.pos+=a.direction*distance/steps;a.left-=distance/steps
				if not navigation.line_clear(before,a.pos,-1 if a.ignore_building<0 else a.ignore_building):impacted=true;break
				# Endpoint sampling complements line_clear's interior samples for short segments.
				if not navigation.line_clear(before,a.pos+a.direction*.5,a.ignore_building):impacted=true;break
				if a.target_kind=="hero" and m.hero_targetable and hero.y-m.surface_height(hero.x,hero.z)<5:
					var contact=Geometry3D.get_closest_point_to_segment(hero+Vector3.UP*1.3,before,a.pos)
					if contact.distance_to(hero+Vector3.UP*1.3)<.85:
						m.events.append({"kind":"hero_hit","amount":a.damage,"from":a.from,"projectile":true});impacted=true;break
				for d in m.defenders.values():
					if d.hp<=0 or not d.targetable:continue
					var contact=Geometry3D.get_closest_point_to_segment(d.pos+Vector3.UP*1.3,before,a.pos)
					if contact.distance_to(d.pos+Vector3.UP*1.3)<.85:
						m.events.append({"kind":"defender_hit","id":d.id,"amount":a.damage,"from":a.from,"projectile":true});impacted=true;break
				if impacted:break
				for w in m.workers.values():
					if w.state!="wounded" and a.pos.distance_to(worker_point(w))<.85:m.damage_worker(w.id,a.damage);impacted=true;break
				if impacted:break
				if a.target_kind=="building" and m.buildings.has(a.target_id):
					var b: Dictionary=m.buildings[a.target_id]
					if a.pos.distance_to(navigation.building_point(b,a.pos)+Vector3.UP*1.6)<.8:m.damage_building(b.id,a.damage);impacted=true;break
			if impacted or a.left<=0:
				m.events.append({"kind":"enemy_arrow_impact","id":id,"point":a.pos});projectiles.erase(id)

var checks=0
var failures=0
var actual
var reference
var optimized
var exhaustive
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh():
	var m=Model.new();m.reset(42,{}, {"format":"forest_shrine_map","schema":1,"title":"Arrow contacts","buildings":[],"trees":[],"deposits":[]})
	m.workers.clear();m.phase="wave";return m
func defender(id:int,pos:Vector3,hp:float=100,targetable:bool=true)->Dictionary:
	return {"id":id,"pos":pos,"hp":hp,"targetable":targetable}
func worker(id:int,pos:Vector3,hp:float=100,state:String="idle")->Dictionary:
	return {"id":id,"pos":pos,"hp":hp,"max_hp":100.0,"state":state,"job":-1,"follow":false,"cargo":0,"timer":0.0,"safe":0.0,"path":[],"destination":Vector2i(-999,-999),"nav":-1}
func shot(id:int,from:Vector3,direction:Vector3=Vector3.RIGHT,kind:String="worker")->Dictionary:
	return {"id":id,"from":from,"to":from+direction*20,"pos":from,"direction":direction,"left":20.0,"target_kind":kind,"target_id":-1,"damage":10.0,"ignore_building":-1}
func load_targets(ds:Array,ws:Array):
	for m in [actual,reference]:
		m.defenders.clear();m.workers.clear();m.events.clear();m.phase="wave";m.hero_targetable=true
		for d in ds:m.defenders[d.id]=d.duplicate(true)
		for w in ws:m.workers[w.id]=w.duplicate(true)
func compare(arrows:Array,delta:float,hero:Vector3=Vector3(0,0,-120),label_:String=""):
	var first={};var second={}
	for arrow in arrows:first[arrow.id]=arrow.duplicate(true);second[arrow.id]=arrow.duplicate(true)
	optimized.tick(first,delta,hero);exhaustive.tick(second,delta,hero)
	check(first==second and actual.events==reference.events and actual.workers==reference.workers,"Filtered flight matches exhaustive collision, damage and event order "+label_)
	return first
func run():
	actual=fresh();reference=fresh();optimized=CountArrows.new(actual,actual.waves.navigation);exhaustive=Exhaustive.new(reference,reference.waves.navigation)
	load_targets([defender(201,Vector3(16.3,0,72)),defender(202,Vector3(15.7,0,72))],[])
	compare([shot(1,Vector3(15.2,1.3,72))],1.0/60,Vector3(0,0,-120),"cross-bucket priority")
	check(actual.events[0].kind=="defender_hit" and actual.events[0].id==201,"First inserted defender wins when two bodies overlap the same segment")
	load_targets([defender(201,Vector3(-16.3,0,-72))],[])
	compare([shot(1,Vector3(-17.2,1.3,-72),Vector3.RIGHT,"hero")],1.0/60,Vector3(-16.7,0,-72),"hero priority at negative coordinates")
	check(actual.events[0].kind=="hero_hit","Hero contact keeps priority over overlapping defenders")
	load_targets([], [worker(301,Vector3(16.3,0,72),10),worker(302,Vector3(15.7,0,72))])
	compare([shot(1,Vector3(15.2,1.6,72)),shot(2,Vector3(15.2,1.6,72))],1.0/60,Vector3(0,0,-120),"same-tick wounded worker")
	check(actual.workers[301].state=="wounded" and actual.workers[302].hp==90,"A later arrow skips a worker wounded by the preceding arrow")
	load_targets([], [worker(401,Vector3(-16,0,72),100,"garrison")])
	compare([shot(1,Vector3(-16.6,21.6,72))],1.0/60,Vector3(0,0,-120),"tower elevation")
	check(actual.workers[401].hp==90,"Garrison contacts retain the twenty-metre deck offset")
	load_targets([], [worker(402,Vector3(-16,0,72),100,"wounded")])
	compare([shot(1,Vector3(-16.6,1.6,72))],1.0/60)
	check(actual.workers[402].hp==100,"Already wounded workers do not consume arrows")
	for offset in [.849,.85,.851]:
		load_targets([defender(403,Vector3(0,0,72))],[])
		compare([shot(1,Vector3(-offset,1.3,72),Vector3.ZERO)],0.0,Vector3(0,0,-120),"stationary contact radius %s"%offset)
		if offset!=.85:check(actual.events.is_empty()==(offset>.85),"Stationary contact retains the exact spherical radius across a cell edge")
	load_targets([defender(405,Vector3(-56,0,72))],[])
	compare([shot(1,Vector3(-60.450016021728516,1.3,72))],.1,Vector3(0,0,-120),"accumulated float32 crosses a bucket edge")
	check(actual.events.any(func(e):return e.kind=="defender_hit" and e.id==405),"Cumulative flight rounding cannot exclude an actual contact at a bucket edge")
	var tower_id=-1
	for m in [actual,reference]:
		var tower=m._make_building("tower",Vector2i(20,20),0);tower_id=tower.id;m.rebuild_navigation()
	var tower_worker=worker(404,actual.center(actual.buildings[tower_id]),100,"garrison");tower_worker.job=tower_id
	load_targets([], [tower_worker])
	var first_shot=shot(1,tower_worker.pos+Vector3(-1,21.6,0));first_shot.ignore_building=tower_id
	var second_shot=first_shot.duplicate(true);second_shot.id=2
	compare([first_shot,second_shot],1.0/60,Vector3(0,0,-120),"garrison retreat within one volley")
	check(actual.workers[404].hp==80 and actual.workers[404].state=="retreat" and actual.workers[404].deck_height==20,"Retreating garrison remains hittable at its live deck height later in the tick")
	# The next tick must rebuild locations and validation after live edits.
	load_targets([defender(501,Vector3(120,0,120),0,false)],[])
	compare([shot(1,Vector3(15.2,1.3,72))],1.0/60)
	for m in [actual,reference]:m.defenders[501].pos=Vector3(15.7,0,72);m.defenders[501].hp=100;m.defenders[501].targetable=true;m.events.clear()
	compare([shot(2,Vector3(15.2,1.3,72))],1.0/60)
	check(actual.events[0].id==501,"Moved or revived defenders are indexed at the next flight tick")
	var rng=RandomNumberGenerator.new();rng.seed=8008135
	for trial in 180:
		var base=Vector3(rng.randi_range(-20,20)*8.0,0,rng.randi_range(-20,20)*8.0)
		# Keep random collision fixtures away from the permanent shrine.
		if base.length()<30:base.z+=72
		var ds=[];var ws=[]
		for index in 24:
			var offset=Vector3(rng.randf_range(-4,4),rng.randf_range(-2,3),rng.randf_range(-4,4))
			ds.append(defender(1000+index,base+offset,0 if index%7==0 else 100,index%5!=0))
			ws.append(worker(2000+index,base+Vector3(rng.randf_range(-4,4),0,rng.randf_range(-4,4)),10 if index%3==0 else 100,["idle","garrison","wounded"][index%3]))
		for index in 120:ds.append(defender(3000+index,Vector3(160+index*.1,0,-160)))
		load_targets(ds,ws)
		var height=[1.3,1.6,21.6][trial%3]
		var direction=Vector3(rng.randf_range(-1,1),rng.randf_range(-.5,.5),rng.randf_range(-1,1)).normalized()
		var arrows=[]
		for index in 4:arrows.append(shot(index,base+Vector3(rng.randf_range(-3,3),height,rng.randf_range(-3,3)),direction,"hero" if index%2==0 else "worker"))
		compare(arrows,[0.0,1.0/60,1.0/30,.2][trial%4],base+Vector3(1,0,1),"random %d"%trial)
	# Native cover checks must still run before either candidate list.
	for m in [actual,reference]:m.trees[Vector2i(2,12)]=1.0;m.rebuild_navigation()
	load_targets([defender(601,Vector3(12,0,72))],[])
	compare([shot(1,Vector3(10.2,1.3,72))],.1)
	check(not actual.events.any(func(e):return e.kind=="defender_hit"),"A trunk still consumes the arrow before a covered defender")
	# Distant workers should add no narrow contact work to a local volley.
	var workers=[];var defenders=[];var volley=[]
	for index in 24:workers.append(worker(700+index,Vector3(120+index,0,-120)))
	for index in 120:defenders.append(defender(800+index,Vector3(-120,0,-120+index*.1)))
	for index in 80:volley.append(shot(index,Vector3(70+index*.01,1.6,72)))
	load_targets(defenders,workers);optimized.worker_checks=0;optimized.candidate_checks=0
	compare(volley,1.0/30)
	print("ENEMY_ARROW_CONTACT_WORK workers=24 defenders=120 arrows=80 worker_checks=",optimized.worker_checks," candidate_checks=",optimized.candidate_checks)
	check(optimized.worker_checks<80,"Distant armies do not trigger per-arrow worker narrow contact scans")
	check(optimized.candidate_checks<80,"Distant defenders and workers are excluded before per-step contact work")
	print("ENEMY_ARROW_BROADPHASE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
