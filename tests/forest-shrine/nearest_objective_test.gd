extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
	var m=Model.new();m.reset(42);m.workers.clear();m.buildings.clear();m.occupancy.clear();m.next_id=1
	m._make_building("shrine",Vector2i(-1,-1),0)
	var hero=Vector3(100,0,100)
	var tower=m._make_building("tower",Vector2i(10,10),0)
	m.defenders[101]={"id":101,"pos":Vector3(70,0,60),"hp":100,"targetable":true}
	for variant in [0,1,2,3,4]:
		var e=m.waves.spawn_enemy(variant,Vector3(55,0,60));m.waves.choose_target(e,hero)
		check(e.target_kind=="building" and e.target_id==tower.id,"Role %d chooses the nearer building over a helper"%variant)
		m.defenders[101].pos=Vector3(0,0,60);e.pos=Vector3(0,0,100);m.waves.choose_target(e,hero)
		check(e.target_kind=="defender" and e.target_id==101,"Role %d pursues a nearer helper beyond the old aggro radius"%variant)
		m.defenders[101].pos=Vector3(70,0,60)
	m.workers[201]={"id":201,"pos":Vector3(0,0,35),"hp":100,"state":"idle","job":-1}
	for variant in [0,1,2,3,4]:
		var e=m.waves.spawn_enemy(variant,Vector3(0,0,40));m.waves.choose_target(e,hero)
		check(e.target_kind=="worker" and e.target_id==201,"Role %d chooses the nearest exposed worker"%variant)
	var enemy=m.waves.spawn_enemy(0,Vector3(0,0,40))
	m.workers[201].sheltered_building=tower.id;m.waves.choose_target(enemy,hero)
	check(enemy.target_kind!="worker","A worker repairing inside a bunker is excluded")
	m.workers[201].erase("sheltered_building");m.workers[201].hp=0;m.defenders[101].targetable=false
	m.waves.begin_defender_snapshot(hero);m.waves.choose_target(enemy,hero)
	check(enemy.target_kind=="building","Dead workers and untargetable helpers are excluded from a shared snapshot")
	m.waves.defender_snapshot_active=false;m.defenders[101].targetable=true;m.defenders[101].taunting=true
	m.waves.choose_target(enemy,hero)
	check(enemy.target_kind=="defender" and enemy.target_id==101,"Knight taunt still overrides distance")
	m.defenders[101].taunting=false;hero=Vector3(0,0,41);enemy.retaliation=2.0
	m.waves.choose_target(enemy,hero)
	check(enemy.target_kind=="hero","An enemy still retaliates when the player attacks")
	m.defenders[101].pos=Vector3(0,0,55);enemy.retaliation_defender=101;m.waves.choose_target(enemy,hero)
	check(enemy.target_kind=="defender" and enemy.target_id==101,"A helper's hit still provokes retaliation")
	m.rebuild_navigation()
	check(not m.route(Vector2i(0,20),Vector2i(0,35)).is_empty(),"Allies can navigate beyond the settlement to hunt across the map")
	check(not m.placement_error("tower",Vector2i(0,35),0).is_empty(),"Map-wide pursuit keeps construction inside the settlement")
	for variant in [0,1,3]:
		var fort=Model.new();fort.reset(42,{}, {"buildings":[{"kind":"gate","x":0,"z":7,"rotation":0}],"trees":[],"deposits":[]},false)
		fort.workers.clear();fort.hero_targetable=false;fort.phase="wave"
		var inside=fort.waves.spawn_enemy(variant,Vector3(3,0,30));var start:Vector3=inside.pos;var attacked=false
		for i in 120:
			fort.waves.flow.begin_tick();fort.waves.tick_enemy(inside,.05,Vector3.ZERO)
			attacked=attacked or inside.strike_kind=="building"
		check(inside.pos.distance_to(start)>1 or attacked,"Role %d can approach or attack its nearest gate from inside the fort"%variant)
	print("NEAREST_OBJECTIVE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
