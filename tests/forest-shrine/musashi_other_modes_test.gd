extends SceneTree
## Exercise Hero's shared non-forest recovery contract with the real world/body.
class OtherModeHero extends Hero:
	func constrain_forest_bounds()->bool:return false
var checks=0
var failures=0
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
	var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
	var game=await fixture.make_game("original");Engine.physics_ticks_per_second=60;Engine.time_scale=1
	fixture.clear_targets();game.player.free();var p=OtherModeHero.new();p.game=game;game.player=p;game.add_child(p);p.set_physics_process(false);p.select_character(13);game.camera_rig.player=p
	game.descent_mode=false;game.checkpoint=Vector3(0,.15,60);p.position=Vector3(1000,-10,1000)
	await physics_frame;p._physics_process(1.0/60.0)
	check(p.position.distance_to(game.checkpoint)<.01,"Musashi retains the sanctuary recovery path outside forest scenes")
	game.descent_mode=true;var bounds=game.world.playable_bounds.grow(-2);p.position=Vector3(bounds.end.x+100,4,60)
	await physics_frame;p._physics_process(1.0/60.0)
	check(p.position.x<=bounds.end.x,"Musashi retains the descent world boundary clamp")
	await fixture.close();fixture.queue_free();await process_frame
	print("MUSASHI_OTHER_MODES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
