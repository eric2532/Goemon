extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class CountedModel extends Model:
	var rays=0
	func _line_visible(a:Vector2i,b:Vector2i,high:bool)->bool:
		rays+=1
		return super._line_visible(a,b,high)
var failures=0
var checks=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():run.call_deferred()
func reference(m,hero:Vector3)->Dictionary:
	var visible={}
	var sources=[[m.cell_of(hero),6,false]]
	for b in m.buildings.values():sources.append([m.cell_of(m.center(b)),m.SIGHT[b.kind],b.kind=="tower"])
	for w in m.workers.values():
		if w.state!="wounded":sources.append([m.cell_of(w.pos),3,false])
	for d in m.defenders.values():
		if d.hp>0:sources.append([m.cell_of(d.pos),5,false])
	for source in sources:
		for x in range(-source[1],source[1]+1):
			for y in range(-source[1],source[1]+1):
				var cell:Vector2i=source[0]+Vector2i(x,y)
				if x*x+y*y<=source[1]*source[1] and m.REGION.has_point(cell) and m._line_visible(source[0],cell,source[2]):visible[cell]=true
	return visible
func same_cells(a:Dictionary,b:Dictionary)->bool:
	if a.size()!=b.size():return false
	for key in a:
		if not b.has(key):return false
	return true
func populate(m):
	for i in 120:m.defenders[i]={"id":i,"hp":100.0,"pos":Vector3.ZERO,"targetable":true}
func move_army(m,step:int):
	for i in m.defenders:
		var group:int=i/10
		m.defenders[i].pos=Vector3((-24+(step+group*3)%48)*6,0,(-24+(step/6+group*5)%48)*6)
func run():
	var m=CountedModel.new();m.reset(90824);populate(m)
	var expected=Model.new();expected.reset(90824);populate(expected)
	var explored=expected.explored.duplicate()
	var durations=[];var warm_recasts=0
	for step in 90:
		move_army(m,step);move_army(expected,step)
		var hero=Vector3((step%24-12)*6,0,(step/24-2)*6)
		if step==45:
			# Navigation edits invalidate sight even while the source cell is unchanged.
			m.trees[Vector2i.ZERO]=1.0;expected.trees[Vector2i.ZERO]=1.0
			m.rebuild_navigation();expected.rebuild_navigation()
		var begin=Time.get_ticks_usec();m.update_vision(hero)
		durations.append((Time.get_ticks_usec()-begin)/1000.0)
		var wanted=reference(expected,hero)
		for cell in wanted:explored[cell]=true
		check(same_cells(m.visible_cells,wanted),"Moving army visibility matches exhaustive reference at step %d"%step)
		check(same_cells(m.explored,explored),"Exploration memory matches reference at step %d"%step)
		m.rays=0;m.update_vision(hero);warm_recasts+=m.rays
		check(m.sight_cache.size()<=512,"Visibility cache remains bounded")
	check(warm_recasts==0,"Repeated current sight sources never recast after cache eviction (rays=%d)"%warm_recasts)
	# Dead defenders and wounded workers stop revealing cells immediately.
	for d in m.defenders.values():d.hp=0
	for d in expected.defenders.values():d.hp=0
	for w in m.workers.values():w.state="wounded"
	for w in expected.workers.values():w.state="wounded"
	m.update_vision(Vector3.ZERO)
	check(same_cells(m.visible_cells,reference(expected,Vector3.ZERO)),"Dead allies and wounded workers lose shared sight")
	durations.sort()
	print("MOVING_VISION_PROFILE ",JSON.stringify({"median_ms":durations[45],"p95_ms":durations[85],"max_ms":durations[-1],"warm_recasts":warm_recasts}))
	print("MOVING_VISION_CACHE_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
