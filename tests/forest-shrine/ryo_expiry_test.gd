extends SceneTree
## Expiry must remove distant sleeping loot, not just currently simulated coins.
const Economy=preload("res://scripts/forest/forest_ryo_economy.gd")
const Renderer=preload("res://scripts/forest/forest_ryo_drops.gd")
var checks=0
var failures=0
class RenderHost extends Node3D:
	var model:Dictionary
	var player:Node3D
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",label_)
	if not ok:failures+=1
func death(id:int,point:Vector3=Vector3.ZERO)->Dictionary:
	return {"id":id,"hp":0,"variant":0,"pos":point}
func run():
	var m=load("res://scripts/forest/forest_model.gd").new()
	m.reset(42,{},{"buildings":[],"trees":[],"deposits":[]});m.phase="wave";m.gold=0
	var r=Economy.new(m)
	var id=r.spawn_enemy_drop(death(1))
	r.tick(.5,[]);r.tick(9.499,[])
	check(r.drops.has(id) and r.uncollected_value()==12,"Sleeping gold remains collectible until ten seconds")
	r.tick(.001,[])
	check(r.drops.is_empty() and r.uncollected_value()==0,"Distant sleeping gold disappears at ten seconds")
	check(m.gold==0 and r.take_collected_events().is_empty(),"Expired gold never credits money or pickup feedback")
	check(r.spawn_enemy_drop(death(1))==-1,"Expiry cannot reissue an already claimed enemy bounty")
	var fresh=r.spawn_enemy_drop(death(2))
	check(fresh!=id and r.uncollected_value()==12,"Fresh loot at an expired pile location creates a new collectible")
	r.reset();id=r.spawn_enemy_drop(death(3));r.tick(9,[]);r.tick(100,[],true)
	check(r.drops.has(id),"Pause freezes the gold expiry timer")
	r.tick(1,[]);check(r.drops.is_empty(),"Gold expires after the remaining active second")
	r.reset();id=r.spawn_enemy_drop(death(4));r.tick(9.8,[])
	var player=[{"id":"player","pos":Vector3(8,0,0),"hp":100,"active":true}]
	r.tick(.1,player)
	check(r.drops.has(id) and r.drops[id].target_id=="player","Nearly expired gold can still start magnet flight")
	r.tick(.1,player)
	check(r.drops.is_empty() and m.gold==0,"In-flight gold also expires without depositing its bounty")
	r.reset();id=r.spawn_enemy_drop(death(5));r.tick(9,[])
	check(r.spawn_enemy_drop(death(6,Vector3(.2,0,0)))==id and r.uncollected_value()==24,"A new nearby kill merges into the existing pile")
	r.tick(1,[])
	check(r.drops.has(id),"A fresh merged bounty is not lost to the older expiry event")
	r.tick(8.999,[])
	check(r.drops.has(id),"Merged gold gets ten seconds from its latest contribution")
	r.tick(.001,[]);check(r.drops.is_empty(),"A refreshed pile still expires after ten active seconds")
	r.reset();r.spawn_enemy_drop(death(7));r.reset();r.tick(5,[])
	id=r.spawn_enemy_drop(death(8));r.tick(5,[])
	check(r.drops.has(id),"Reset discards old expiry events before IDs are reused")
	r.tick(5,[]);check(r.drops.is_empty(),"Reused IDs retain their new expiry deadline")
	r.reset()
	for i in 3000:r.spawn_enemy_drop(death(100+i,Vector3(100+(i%60)*3,0,100+floori(i/60.0)*3)))
	var host=RenderHost.new();host.model={"ryo":r};host.player=Node3D.new();root.add_child(host);host.add_child(host.player)
	var renderer=Renderer.new();renderer.game=host;host.add_child(renderer);renderer.set_process(false);renderer.sync()
	check(renderer.batch.multimesh.visible_instance_count==256,"A large distant loot field uses the existing bounded renderer")
	r.tick(.5,[]);r.tick(9.5,[]);renderer.sync()
	check(r.drops.is_empty() and renderer.batch.multimesh.visible_instance_count==0,"Expiry clears all three thousand drops and cached coin visuals")
	check(r.moving_drops.is_empty() and r.resting_buckets.is_empty() and r.merge_buckets.is_empty(),"Expired loot leaves no simulation or spatial-index work behind")
	r.reset();m.gold=0
	r.spawn_enemy_drop(death(0))
	for i in range(1,1100):r.spawn_enemy_drop(death(i,Vector3(100+i*3,0,100)))
	r.tick(5,[])
	for i in range(1100,2200):r.spawn_enemy_drop(death(i,Vector3(100+i*3,0,100)))
	r.tick(.02,[{"id":"player","pos":Vector3.ZERO,"hp":100,"active":true}])
	check(m.gold==12 and r.drops.size()==2199,"Early collection leaves a stale expiry event without losing other piles")
	r.tick(4.98,[])
	check(r.drops.size()==1100 and r.uncollected_value()==13200,"Compacting expired events preserves every later deadline")
	r.tick(4.999,[]);check(r.drops.size()==1100,"Later drops retain their full pickup window after queue compaction")
	r.tick(.001,[])
	check(r.drops.is_empty() and m.gold==12,"Compacted future events expire once without duplicate collection credit")
	host.queue_free();await process_frame
	r=null;m=null;renderer=null;host=null;Renderer.coin_mesh=null
	print("RYO_EXPIRY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
