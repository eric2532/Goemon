extends SceneTree
## Catch whole-crowd bursts, lost logical time and stale work after reset.
class MeasuredWaves extends "res://scripts/forest/forest_waves.gd":
	var counts:Dictionary={}
	var times:Dictionary={}
	func tick_enemy(e:Dictionary,delta:float,_hero:Vector3):
		counts[e.id]=int(counts.get(e.id,0))+1
		times[e.id]=float(times.get(e.id,0))+delta
class MeasuredModel extends "res://scripts/forest/forest_model.gd":
	var synchronous_steps=0
	func tick(delta:float,hero:Vector3):
		synchronous_steps+=1;super.tick(delta,hero)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",label_)
	if not ok:failures+=1
func total(waves)->int:
	var result=0
	for value in waves.counts.values():result+=int(value)
	return result
func populate(model,count_:int):
	model.waves=MeasuredWaves.new(model);model.start_wave()
	model.waves.pending=999;model.waves.spawn_clock=10000
	for i in count_:model.waves.spawn_enemy(0,Vector3(0,0,90))
func run():
	var game=load("res://scripts/forest/forest_game.gd").new()
	var helper=load("res://scripts/forest/explorer_helpers.gd").new();game.explorer_helpers=helper
	var player=load("res://scripts/player.gd").new();game.player=player
	var model=MeasuredModel.new();model.reset(42,{},{"buildings":[],"trees":[],"deposits":[]});model.workers.clear();game.model=model
	populate(model,240)
	var original_wave=model.waves
	var worst=0;var updates=[];var changed=[]
	for frame in 120:
		var before=total(model.waves);var advanced=game._advance_world(1.0/60)
		var work=total(model.waves)-before;worst=maxi(worst,work)
		if frame<5:updates.append(work);changed.append(advanced)
	check(worst<=80,"No physics frame simulates more than eighty of the 240 enemies")
	check(updates==[0,0,80,80,80],"One existing 20Hz logical update is spread over three frames")
	check(changed==[false,false,true,true,true],"Every slice dispatches combat events immediately instead of waiting for cycle completion")
	# Finish the already-funded tail without advancing any additional game time.
	if model.has_method("wave_step_active"):
		for i in 3:
			if not model.wave_step_active():break
			game._advance_world(0.0)
	var conserved=true
	for id in model.enemies:
		if absf(float(model.waves.times.get(id,0))-2.0)>.00001:conserved=false
	check(conserved,"Every enemy receives exactly two seconds after two seconds and the pending tail")
	check(absf(10000.0-model.waves.spawn_clock-2.0)<.001,"Slicing advances the spawn clock exactly once per logical update")
	check(model.synchronous_steps==0,"Crowded runtime avoids the synchronous whole-crowd path")
	# A paused game must retain its partly executed cycle without accruing time.
	for i in 3:game._advance_world(1.0/60)
	var before_pause=total(model.waves);var clock_before=float(model.waves.spawn_clock)
	game.last_phase="wave";game.paused=true
	for i in 60:game._physics_process(1.0/60)
	check(total(model.waves)==before_pause and model.waves.spawn_clock==clock_before,"Pause freezes pending actor work and world clocks")
	game.paused=false;game._advance_world(1.0/60)
	check(total(model.waves)-before_pause<=80,"Resuming a partial cycle keeps its frame budget")
	# Reset reuses enemy IDs: the old captured roster must never reach new state.
	model.reset(43,{},{"buildings":[],"trees":[],"deposits":[]});model.workers.clear();populate(model,16)
	game._advance_world(1.0/60)
	check(total(model.waves)==16 and model.synchronous_steps==1,"Reset cancels an old cycle before new small-fight IDs are reused")
	check(model.waves!=original_wave,"Reset uses the new wave owner")
	for i in 119:game._advance_world(1.0/60)
	check(model.synchronous_steps==120,"Small fights retain their full sixty world updates per second")
	check(model.enemies.values().all(func(e):return not e.has("simulation_revision")),"Synchronous actors retain legacy snapshot invalidation")
	model.reset(44,{},{"buildings":[],"trees":[],"deposits":[]});model.workers.clear();populate(model,48)
	game._advance_world(1.0/60);game._advance_world(1.0/60)
	check(total(model.waves)==24 and model.wave_step_active(),"A medium crowd starts a two-frame logical cycle")
	var roster=model.enemies.keys()
	for index in range(12,roster.size()):model.enemies.erase(roster[index])
	game._advance_world(1.0/60)
	check(not model.wave_step_active() and total(model.waves)==24 and absf(10000-model.waves.spawn_clock-1.0/30)<.001,"Crossing below the crowd threshold finishes the captured cycle without ticking a survivor twice")
	game._advance_world(1.0/60)
	check(model.enemies.keys().all(func(id):return absf(model.waves.times[id]-1.0/15)<.00001),"Returning to small-fight cadence preserves the accumulated next-cycle time")
	helper.free();player.free();game.free()
	print("ENEMY_FRAME_BUDGET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
