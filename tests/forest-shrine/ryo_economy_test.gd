extends SceneTree
## Guards against kill auto-credit, duplicate payouts, remote/dead pickups and lost mass-kill value.
var failures=0
var checks=0
var economy_script:Script
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func fixture()->Array:
	var model=load("res://scripts/forest/forest_model.gd").new()
	model.reset(42,{},{"deposits":[],"trees":[],"buildings":[]})
	model.workers.clear();model.phase="wave";model.gold=0
	return [model,economy_script.new(model)]
func enemy(id:int,variant:int=0,point:Vector3=Vector3.ZERO)->Dictionary:
	return {"id":id,"variant":variant,"hp":0.0,"pos":point}
func collector(id:String,point:Vector3,hp:float=100)->Dictionary:
	return {"id":id,"pos":point,"hp":hp,"active":true,"dead":false,"state":"idle"}
func advance(ryo,collectors:Array,steps:int=80):
	for i in range(steps):ryo.tick(.02,collectors)
func run():
	check(ResourceLoader.exists("res://scripts/forest/forest_ryo_economy.gd"),"The authoritative physical ryo economy exists")
	if failures:finish();return
	economy_script=load("res://scripts/forest/forest_ryo_economy.gd")
	var f=fixture();var m=f[0];var r=f[1]
	var alive=enemy(1);alive.hp=1.0
	check(r.spawn_enemy_drop(alive)==-1 and r.drops.is_empty(),"A living enemy cannot produce loot")
	var drop_id=r.spawn_enemy_drop(enemy(1))
	check(drop_id>=0 and r.uncollected_value()==12 and m.gold==0,"A killed ordinary enemy leaves twelve physical ryo without crediting gold")
	r.spawn_enemy_drop(enemy(1));r.spawn_enemy_drop(enemy(1))
	check(r.uncollected_value()==12 and r.drops.size()==1,"Repeated actor and model death notifications produce one bounty")
	for row in [[2,1],[3,2],[4,3],[5,4]]:r.spawn_enemy_drop(enemy(row[0],row[1],Vector3(row[0]*4,0,0)))
	check(r.uncollected_value()==346 and m.gold==0,"Ordinary, giant and boss drops retain their twelve, sixty and 250 ryo bounties")
	advance(r,[collector("far",Vector3(100,0,0))])
	check(m.gold==0 and r.uncollected_value()==346,"Distant allies never credit ground ryo")
	r.reset();m.gold=0
	drop_id=r.spawn_enemy_drop(enemy(10))
	var player=collector("player",Vector3(8,0,0))
	advance(r,[],30)
	var before:Vector3=r.drops[drop_id].pos
	r.tick(.05,[player])
	check(r.drops.has(drop_id) and r.drops[drop_id].pos.x>before.x and m.gold==0,"A nearby player attracts visible ryo through space before receiving gold")
	advance(r,[player])
	check(r.drops.is_empty() and m.gold==12,"The player collects without standing on the death point")
	var events:Array=r.take_collected_events()
	check(events.size()==1 and events[0].value==12 and events[0].collector_id=="player" and r.take_collected_events().is_empty(),"One drainable pickup summary records the credited value")
	r.spawn_enemy_drop(enemy(10))
	check(r.drops.is_empty() and m.gold==12,"A consumed enemy bounty cannot respawn after collection")
	r.reset();m.gold=0
	drop_id=r.spawn_enemy_drop(enemy(20))
	var helper=collector("helper:-2",Vector3(7,0,0))
	advance(r,[],30);r.tick(.05,[collector("player",Vector3(100,0,0)),helper])
	check(r.drops[drop_id].target_id=="helper:-2" and r.drops[drop_id].pos.x>0 and m.gold==0,"A living summoned ally attracts a coin while the player is far away")
	helper.hp=0
	var abandoned:Vector3=r.drops[drop_id].pos
	r.tick(.05,[helper])
	check(r.drops.has(drop_id) and r.drops[drop_id].target_id=="" and is_equal_approx(r.drops[drop_id].pos.x,abandoned.x) and m.gold==0,"A collector dying mid-flight drops its coin without credit")
	var worker=collector("worker:8",Vector3(-5,0,0))
	r.tick(.05,[helper,worker])
	check(r.drops[drop_id].target_id=="worker:8" and r.drops[drop_id].pos.x<abandoned.x,"An abandoned coin retargets to the closest living worker")
	advance(r,[helper,worker])
	check(m.gold==12 and r.drops.is_empty(),"An allied worker deposits the same shared gold as the player")
	r.reset();m.gold=0;drop_id=r.spawn_enemy_drop(enemy(30))
	var wounded=collector("worker:9",Vector3.ZERO);wounded.state="wounded"
	var inactive=collector("helper:3",Vector3.ZERO);inactive.active=false
	advance(r,[collector("dead",Vector3.ZERO,0),wounded,inactive],60)
	check(m.gold==0 and r.uncollected_value()==12,"Dead, wounded and inactive collectors cannot collect")
	before=r.drops[drop_id].pos
	r.tick(10,[collector("player",Vector3.ZERO)],true)
	check(r.drops[drop_id].pos==before and m.gold==0,"Pause freezes physical motion and gold collection")
	r.tick(1,[collector("player",Vector3(4,0,0))],false,func(_a:Vector3,_b:Vector3)->bool:return false)
	check(r.drops.has(drop_id) and r.drops[drop_id].pos.x==before.x and m.gold==0,"Solid cover prevents attraction and collection")
	r.tick(.02,[collector("blocked-near",Vector3(2,0,0)),collector("clear-ally",Vector3(-5,0,0))],false,func(_a:Vector3,b:Vector3)->bool:return b.x<0)
	check(r.drops[drop_id].target_id=="clear-ally","A blocked nearby collector does not hide a clear nearby ally")
	m.phase="preparing";r.tick(.02,[])
	check(r.uncollected_value()==12,"Wave preparation retains every uncollected ryo")
	m.phase="wave";advance(r,[collector("player",Vector3(3,0,0))])
	check(m.gold==12 and r.drops.is_empty(),"Leftover ryo remains collectible in the following wave")
	r.reset();m.gold=0
	for i in range(600):r.spawn_enemy_drop(enemy(i,0,Vector3(float(i%3)*.2,0,float(i%5)*.1)))
	check(r.uncollected_value()==7200 and r.drops.size()<=6 and m.gold==0,"Six hundred clustered kills merge physical drops while preserving all 7,200 ryo")
	advance(r,[collector("player",Vector3(7,0,0))],140)
	check(m.gold==7200 and r.uncollected_value()==0,"Collecting clustered drops credits the exact mass-kill bounty once")
	r.spawn_enemy_drop(enemy(999,4));r.reset()
	check(r.drops.is_empty() and r.uncollected_value()==0 and r.take_collected_events().is_empty(),"Run reset removes ground drops and pending feedback")
	r.spawn_enemy_drop(enemy(1))
	check(r.uncollected_value()==12,"Run reset permits reused model enemy identities")
	r.reset();m.gold=0
	drop_id=r.spawn_enemy_drop(enemy(1100))
	advance(r,[],30)
	var moving_collector=collector("moving",Vector3(8,0,0))
	for i in range(7):r.tick(.05,[moving_collector])
	r.tick(.02,[])
	var flown:Vector3=r.drops[drop_id].pos
	var new_id=r.spawn_enemy_drop(enemy(1101))
	check(flown.x>2 and new_id!=drop_id and r.drops[new_id].pos.x<1,"A new death never merges into a coin that has flown away from its spawn point")
	r.reset();m.gold=0
	drop_id=r.spawn_enemy_drop(enemy(1200,0,Vector3(-10.1,0,-10.1)))
	advance(r,[collector("negative",Vector3(-3.1,0,-10.1))])
	check(m.gold==12,"Collectors work across negative spatial bucket boundaries")
	r.reset();m.gold=0;drop_id=r.spawn_enemy_drop(enemy(1300))
	advance(r,[collector("high-garrison",Vector3(0,20,0))])
	check(m.gold==0 and r.drops.has(drop_id),"A high tower crew cannot vacuum coins twenty metres below its actual feet")
	m.phase="defeat";before=r.drops[drop_id].pos;r.tick(10,[collector("player",Vector3.ZERO)])
	check(m.gold==0 and r.drops[drop_id].pos==before,"Defeat stops collection even if a stale collector snapshot remains")
	r.reset();m.phase="wave";m.gold=0
	r.spawn_enemy_drop(enemy(1400))
	advance(r,[],30)
	var crowded_collectors:Array=[]
	for i in range(120):crowded_collectors.append(collector("ally:%d"%i,Vector3(7,0,0)))
	var queries=[0]
	r.tick(.02,crowded_collectors,false,func(_a:Vector3,_b:Vector3)->bool:queries[0]+=1;return true)
	check(queries[0]==1,"A dense 120-ally formation needs only one visibility query for equally close eligible collectors")
	finish()
func finish():
	print("FOREST_RYO_ECONOMY_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
