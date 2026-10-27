extends SceneTree
const Balance=preload("res://scripts/forest/core_balance.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
var failures=0
var checks=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: wave roster timeout");quit(1))
	run.call_deferred()
func drain(model,expected:Array):
	var counts=[];counts.resize(Balance.TYPES.size());counts.fill(0)
	for attempt in 200:
		if model.waves.pending==0:break
		model.waves.spawn_batch()
		for enemy in model.enemies.values():counts[Balance.TYPES.find(enemy.variant)]+=1
		model.enemies.clear()
	check(counts==expected and model.waves.pending==0,"Wave releases the exact selected enemy counts: "+str(expected))
func run():
	check(Balance.TYPES.size()==Roles.WAVE_TYPES.size()+4,"Every current enemy and crawling form has a separate slot")
	for type in Roles.WAVE_TYPES+[Roles.VAMBEE_TORSO,Roles.BOSS,Roles.DARK_LUMINA_2,Roles.DARK_LUMINA_3]:check(Balance.TYPES.has(type),"Selectable type "+str(type))
	check(not Balance.TYPES.has(2) and not Balance.ENEMIES.has("Daruma Breaker"),"Daruma is absent from wave choices")
	var invalid=Balance.sanitized({"waves":[[-1,INF,NAN,"bad",10001,2.8,0,3]],"bosses_per_portal":"bad"})
	check(invalid.waves[0]==[0,0,0,0,10000,2,0,3,0,0],"New rows clamp counts and reject nonnumeric or nonfinite data")
	var old={"population_version":1,"bosses_per_portal":0,"waves":[[11,7,9,5]]}
	var migrated=Balance.from_saved(old)
	var total=0
	for count in migrated.waves[0]:total+=count
	check(total==23 and migrated.waves[0][Balance.TYPES.find(Roles.BOSS)]==0,"Saved mixed families retain the effective total and disabled boss")
	check(old.waves==[[11,7,9,5]] and Balance.from_saved(migrated)==migrated,"Migration preserves the source and runs once")
	var model=Model.new();model.reset(42,{"waves":[[1,2,3,4,5,6,7,2]]},{},false)
	check(model.start_wave() and model.waves.pending==30,"Each boss is included in the wave total")
	drain(model,[1,2,3,4,5,6,7,2,0,0])
	check(model.balance.waves[0]==[1,2,3,4,5,6,7,2,0,0],"Draining preserves saved composition")
	model.waves.tick(.01,model.hero_position);check(model.phase=="victory","Finite wave finishes normally")
	for slot in Balance.TYPES.size():
		var wave=[];wave.resize(Balance.TYPES.size());wave.fill(0);wave[slot]=2
		model.reset(42,{"waves":[wave]},{},false);model.start_wave();drain(model,wave)
	var portal_layout=preload("res://scripts/forest/forest_map_document.gd").new();portal_layout.capture(model);portal_layout.data.portals=[{"x":0,"z":24,"rotation":0}]
	model.reset(42,{"waves":[[1,2,3,4,5,6,7,2]]},portal_layout.data,false);model.start_wave();drain(model,[1,2,3,4,5,6,7,2,0,0])
	var camps=preload("res://scripts/forest/forest_camp_prototype.gd").layout()
	model.reset(42,{"waves":[[0,0,0,0,2,0,0,0]]},camps,false);model.start_wave()
	for cycle in 3:
		check(model.waves.spawn_batch()>0 and model.enemies.values().all(func(e):return e.variant==Roles.HAYA_WOLF),"Camps repeat only the chosen reinforcement type")
		model.enemies.clear()
	model.reset(42,{"waves":[[0,0,0,0,0,0,0,0]]},camps,false);model.start_wave()
	check(model.waves.spawn_batch()==0 and model.enemies.is_empty(),"An empty camp mix spawns no unselected fallback enemies")
	print("WAVE_ROSTER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
