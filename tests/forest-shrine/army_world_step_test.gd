extends SceneTree
class CountedModel extends "res://scripts/forest/forest_model.gd":
	var steps=0
	var elapsed=0.0
	func tick(delta:float,hero:Vector3):
		steps+=1;elapsed+=delta;super.tick(delta,hero)
var checks=0
var failures=0
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():run.call_deferred()
func run():
	var game=load("res://scripts/forest/forest_game.gd").new()
	check(game.has_method("_advance_world"),"Army simulation can batch world work independently from character physics")
	if not game.has_method("_advance_world"):game.free();finish();return
	var helper=Node.new();helper.set_script(load("res://scripts/forest/explorer_helpers.gd"));game.explorer_helpers=helper
	var player=load("res://scripts/player.gd").new();game.player=player
	var model=CountedModel.new();model.reset(90824);game.model=model
	model.start_wave();model.waves.pending=999;model.waves.spawn_clock=10000
	for i in 120:game._advance_world(1.0/60)
	check(model.steps==120 and game.model_tick_serial==120,"Small fights retain sixty world steps per second")
	check(absf(model.elapsed-2)<.00001,"Small fight simulation conserves elapsed time")
	helper.living_count=48;model.steps=0;model.elapsed=0
	var before=model.waves.spawn_clock
	for i in 120:game._advance_world(1.0/60)
	check(model.steps==60 and game.model_tick_serial==180,"Large armies halve repeated world preparation")
	check(absf(model.elapsed-2)<.00001 and absf(before-model.waves.spawn_clock-2)<.001,"Wave clock still advances by the full two seconds")
	game._advance_world(1.0/60);helper.living_count=0;model.steps=0;model.elapsed=0
	game._advance_world(1.0/60)
	check(model.steps==1 and absf(model.elapsed-1.0/30)<.00001,"Leaving army mode flushes accumulated time without losing it")
	helper.free();player.free();game.free();finish()
func finish():
	print("ARMY_WORLD_STEP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
