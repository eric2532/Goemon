extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():run.call_deferred()
func run():
	var m=load("res://scripts/forest/forest_model.gd").new()
	preload("res://tests/forest-shrine/empty_settlement.gd").reset(m)
	check(m.has_method("food_capacity"),"Recruitment has a shared food limit")
	if not m.has_method("food_capacity"):finish();return
	while m.workers.size()<10:check(m.workforce.recruit(),"Base housing can fill to ten workers")
	var money=m.gold
	check(not m.workforce.recruit() and m.gold==money,"A full population rejects recruitment without charging")
	var b=m.build("barracks",Vector2i(5,5),0)
	check(not b.is_empty() and m.gold==money-250,"Placing a barracks charges once")
	if b.is_empty():finish();return
	check(m.food_capacity()==15 and m.food_used()==10,"One barracks adds five shared food")
	m.fighter_count=2
	check(m.food_used()==14 and not m.can_recruit(2) and m.can_recruit(1),"Two fighters use four food leaving room for one worker")
	check(m.workforce.recruit() and not m.workforce.recruit(),"Last food can recruit exactly one worker")
	m.phase="wave";m.damage_building(b.id,1000)
	check(b.hp==2500,"Barracks armor halves incoming damage")
	var w=m.workers.values()[0]
	check(m.workforce._assign(w,b),"A reachable damaged barracks accepts a repair worker")
	w.pos=m.point(m.entry(b));m.workforce.tick(.25,Vector3.ZERO)
	check(w.get("sheltered_building",-1)==b.id and b.hp>2500,"Worker enters the barracks and repairs from inside")
	var hp=w.hp;m.damage_worker(w.id,1000)
	check(w.hp==hp and not m.worker_targetable(w.id),"Interior repair worker cannot be targeted or damaged")
	m.damage_building(b.id,100000)
	check(not m.buildings.has(b.id) and m.food_capacity()==10 and not m.can_recruit(1),"Destroyed barracks removes capacity without removing the population")
	check(not w.has("sheltered_building") and m.worker_targetable(w.id) and not m.allied_grid.is_point_solid(m.cell_of(w.pos)),"Destruction safely ejects the repair worker")
	m.phase="preparing";m.fighter_count=0
	var restored=m.build("barracks",Vector2i(5,5),0);restored.hp=2990
	check(m.workforce._assign(w,restored),"Surviving worker can take a new interior repair job")
	w.pos=m.point(m.entry(restored));m.workforce.tick(.25,Vector3.ZERO)
	check(restored.hp==3000 and not w.has("sheltered_building"),"Finishing repairs releases the worker outside")
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original()
	doc.data.buildings.append({"kind":"barracks","x":16,"z":16,"rotation":0,"span":0})
	check(doc.validate(doc.data).is_empty(),"Saved maps accept barracks structures")
	finish()
func finish():
	print("BARRACKS_MODEL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
