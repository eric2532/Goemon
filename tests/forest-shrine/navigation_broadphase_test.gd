extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Navigation=preload("res://scripts/forest/forest_enemy_navigation.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
# Frozen pre-cache queries provide an independent oracle, including collision order.
func original_terrain_clear(m,p:Vector3,radius:float)->bool:
	if not m.terrain.disk_clear(p,14.75 if radius>=8.5 else radius):return false
	if radius>=8.5:radius=14.0
	if p.x-radius < -243 or p.z-radius < -243 or p.x+radius>237 or p.z+radius>237:return false
	var c:Vector2i=m.cell_of(p);var cells=ceili((radius+1.8)/m.CELL)+1
	for dx in range(-cells,cells+1):
		for dz in range(-cells,cells+1):
			var t=c+Vector2i(dx,dz)
			if not m.trees.has(t):continue
			var center:Vector3=m.point(t)
			var offset=Vector2(maxf(0,absf(p.x-center.x)-1.25),maxf(0,absf(p.z-center.z)-1.25))
			if offset.length()<radius+.05:return false
	return true
func original_blocker(m,nav,p:Vector3,radius:float)->int:
	var c:Vector2i=m.cell_of(p);var cells=ceili((radius+3)/6)+1;var ids={}
	for dx in range(-cells,cells+1):
		for dz in range(-cells,cells+1):
			var id:int=m.occupancy.get(c+Vector2i(dx,dz),-1)
			if id>=0:ids[id]=true
	for id in ids:
		var b:Dictionary=m.buildings.get(id,{})
		if not b.is_empty() and p.distance_to(nav.building_point(b,p))<radius+.05:return id
	return -1
func compare_queries(m,nav)->bool:
	for radius in [.8,.85,.9,8.5,14.0,14.75]:
		for x in [-243.01,-242.1,-18.0,-15.001,-15.0,-14.999,-9.001,-9.0,-8.999,-3.001,-3.0,-2.999,0.0,2.999,3.0,3.001,8.999,9.0,9.001,12.0,24.0,236.1,237.01]:
			for z in [-15.001,-15.0,-14.999,-3.001,-3.0,-2.999,0.0,2.999,3.0,3.001,12.0]:
				for height_ in [0.0,3.0,18.0]:
					var p=Vector3(x,height_,z)
					if nav.terrain_clear(p,radius)!=original_terrain_clear(m,p,radius):return false
					if nav.blocker(p,radius)!=original_blocker(m,nav,p,radius):return false
	return true
func blocker_cost(m,nav,cached:bool)->float:
	var samples=[];var sink=0
	for repeat_ in range(3):
		var start=Time.get_ticks_usec()
		for i in range(500):
			var p=Vector3(90.0+float(i%7)*.01,0,90.0+float(i%11)*.01)
			sink+=nav.blocker(p,.9) if cached else original_blocker(m,nav,p,.9)
		samples.append(float(Time.get_ticks_usec()-start))
	if sink!=-1500:printerr("Unexpected collision in the empty road fixture")
	samples.sort();return samples[1]
func collision_thresholds()->bool:
	var m=Model.new();var nav=Navigation.new(m)
	m.trees[Vector2i(-2,-1)]=1.0
	var b=m._make_building("tower",Vector2i(-1,-1),0)
	for radius in [.8,.85,.9,8.5,14.0,14.75]:
		var tree_radius=14.0 if radius>=8.5 else radius
		for epsilon in [-.0001,.0001]:
			var tree_point=Vector3(-12.0+1.25+tree_radius+.05+epsilon,0,-6)
			if nav.terrain_clear(tree_point,radius)!=(epsilon>0):return false
			var diagonal=Vector3(-12.0+1.25+(tree_radius+.05+epsilon)/sqrt(2),0,-6.0+1.25+(tree_radius+.05+epsilon)/sqrt(2))
			if nav.terrain_clear(diagonal,radius)!=(epsilon>0):return false
			var building_point=Vector3(3.0+radius+.05+epsilon,0,0)
			if nav.blocker(building_point,radius)!=(b.id if epsilon<0 else -1):return false
	return true
func run():
	var m=Model.new();var nav=Navigation.new(m)
	m.trees={Vector2i(-2,-1):1.0,Vector2i(2,1):1.0,Vector2i(0,3):1.0}
	var first=m._make_building("tower",Vector2i(-1,-1),0)
	m._make_building("wall",Vector2i(1,-1),0)
	m._make_building("wall",Vector2i(-4,1),1)
	m.navigation_revision+=1
	check(compare_queries(m,nav),"Broadphase preserves exhaustive collision results across negative cells, half-cell boundaries, role radii and raised points")
	check(collision_thresholds(),"Tree sides, rounded corners and building edges retain exact role collision thresholds")
	check(nav.blocker(Vector3(3,0,-6),.9)==first.id,"Simultaneous building contacts retain the original scan priority")
	# Prime empty neighborhoods before adding obstacles in those same cells.
	check(nav.terrain_clear(Vector3(60,0,60),.9) and nav.blocker(Vector3(60,0,60),.9)==-1,"Empty query fixture starts clear")
	m.trees[Vector2i(10,10)]=1.0
	var added=m._make_building("tower",Vector2i(10,10),0);m.navigation_revision+=1
	check(not nav.terrain_clear(Vector3(60,0,60),.9) and nav.blocker(Vector3(60,0,60),.9)==added.id,"A navigation revision exposes newly added trees and buildings immediately")
	m.trees.erase(Vector2i(10,10));m._remove_building(added.id);m.navigation_revision+=1
	check(nav.terrain_clear(Vector3(60,0,60),.9) and nav.blocker(Vector3(60,0,60),.9)==-1,"A navigation revision clears removed tree and building candidates")
	check(compare_queries(m,nav),"Candidate invalidation retains exhaustive query behavior")
	var before=blocker_cost(m,nav,false);var after=blocker_cost(m,nav,true)
	print("NAVIGATION_BROADPHASE_COST exhaustive_us=",before," current_us=",after," ratio=",after/maxf(1,before))
	check(after<before*.65,"Repeated clear road checks avoid rescanning all 25 empty occupancy cells")
	print("NAVIGATION_BROADPHASE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
