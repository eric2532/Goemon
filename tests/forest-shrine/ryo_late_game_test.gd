extends SceneTree
## Retained remote loot must not keep querying terrain, and must wake immediately.
const Economy=preload("res://scripts/forest/forest_ryo_economy.gd")
const Renderer=preload("res://scripts/forest/forest_ryo_drops.gd")
class FlatModel extends RefCounted:
	var phase="wave"
	var gold=0
	var height_queries=0
	func surface_height(_x:float,_z:float)->float:
		height_queries+=1
		return 0.0
class RenderHost extends Node3D:
	var player:Node3D
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func collector(point:Vector3)->Array:
	return [{"id":"player","pos":point,"hp":100,"active":true}]
func fixture(count:int)->Array:
	var m=FlatModel.new();var r=Economy.new(m)
	for i in range(count):
		r.spawn_enemy_drop({"id":i,"hp":0,"variant":0,"pos":Vector3(100+float(i%60)*3,0,100+float(i/60)*3)})
	for i in range(90):r.tick(1.0/60,[])
	return [m,r]
func benchmark():
	var rows=[]
	for count in [0,256,1000,3000]:
		var f=fixture(count);var m=f[0];var r=f[1]
		var collectors=collector(Vector3.ZERO)
		for i in range(10):r.tick(1.0/60,collectors)
		m.height_queries=0
		var start=Time.get_ticks_usec()
		for i in range(120):r.tick(1.0/60,collectors)
		var tick_us=float(Time.get_ticks_usec()-start)/120
		var host=RenderHost.new();host.player=Node3D.new();root.add_child(host);host.add_child(host.player)
		var renderer=Renderer.new();renderer.game=host
		start=Time.get_ticks_usec()
		for i in range(20):renderer._select_visible(r)
		var selection_us=float(Time.get_ticks_usec()-start)/20
		rows.append({"drops":count,"tick_us":tick_us,"selection_us":selection_us,"height_queries_per_tick":m.height_queries/120.0})
		renderer.free();host.free()
	print("RYO_LATE_GAME_BENCHMARK "+JSON.stringify(rows))
func run():
	benchmark()
	var f=fixture(1000);var m=f[0];var r=f[1]
	m.height_queries=0
	for i in range(30):r.tick(1.0/60,collector(Vector3.ZERO))
	check(m.height_queries==0,"Settled remote loot performs no terrain support queries")
	check(r.drops.size()==1000 and r.uncollected_value()==12000 and m.gold==0,"Sleeping distant loot preserves every bounty")
	var id=r.drops.keys()[0];var before:Vector3=r.drops[id].pos
	check(absf(r.age_of(r.drops[id])-2.0)<.00001,"Sleeping coins retain their full visual animation age")
	r.tick(5,[],true)
	check(absf(r.age_of(r.drops[id])-2.0)<.00001,"Pause freezes sleeping coin animation age")
	r.tick(1.0/60,collector(Vector3(108,0,100)),false,func(_a:Vector3,_b:Vector3)->bool:return false)
	check(r.drops[id].pos==before and m.gold==0,"A sleeping coin wakes to check cover before moving")
	r.tick(1.0/60,collector(Vector3(108,0,100)))
	check(r.drops.has(id) and r.drops[id].pos.x>before.x,"A collector entering range wakes and attracts settled loot on the same tick")
	var in_flight:Vector3=r.drops[id].pos
	r.tick(1.0/60,[])
	check(r.drops[id].target_id=="" and is_equal_approx(r.drops[id].pos.x,in_flight.x),"Losing the collector stops flight without losing the bounty")
	for i in range(120):r.tick(1.0/60,collector(Vector3(108,0,100)))
	check(m.gold>0 and m.gold+r.uncollected_value()==12000,"Woken drops deposit exact value once")
	var host=RenderHost.new();host.player=Node3D.new();root.add_child(host);host.add_child(host.player)
	var renderer=Renderer.new();renderer.game=host
	for focus in [Vector3(100,0,100),Vector3(280,0,150),Vector3(190,20,126)]:
		host.player.position=focus;renderer._select_visible(r)
		check(renderer.visible_ids.size()==256,"The visible nearest selection stays bounded")
		var farthest_selected=0.0
		for selected in renderer.visible_ids:farthest_selected=maxf(farthest_selected,r.drops[selected].pos.distance_squared_to(focus))
		var omitted_nearer=false
		for candidate in r.drops:
			if not renderer.visible_ids.has(candidate) and r.drops[candidate].pos.distance_squared_to(focus)<farthest_selected:omitted_nearer=true
		check(not omitted_nearer,"The visual cap retains the exact nearest coins after moving the focus")
	renderer.free();host.free()
	r.reset();m.gold=0;r.tick(1000,[])
	id=r.spawn_enemy_drop({"id":1,"hp":0,"variant":0,"pos":Vector3.ZERO})
	for i in range(7):r.tick(.02,collector(Vector3(8,0,0)))
	check(r.drops[id].pos.x==0,"Even late in a run the launch magnet delay is preserved")
	r.tick(.02,collector(Vector3(8,0,0)))
	check(r.drops[id].pos.x>0,"The initial attraction starts at the original 160ms boundary late in a run")
	r.reset();m.gold=0
	id=r.spawn_enemy_drop({"id":1,"hp":0,"variant":0,"pos":Vector3(-10.1,0,-10.1)})
	for i in range(90):r.tick(1.0/60,[])
	r.tick(.02,collector(Vector3(-3.1,0,-10.1)))
	check(r.drops[id].pos.x>-10.1,"A settled coin wakes across negative pickup cell boundaries after reset")
	print("FOREST_RYO_LATE_GAME_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
