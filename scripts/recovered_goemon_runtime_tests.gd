extends SceneTree
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)
func run():
	var script=load("res://scripts/recovered_goemon_model.gd")
	check(script!=null,"Goemon has an isolated original-ROM model adapter")
	if script==null:quit(1);return
	var model=script.new();root.add_child(model)
	await process_frame
	check(Hero.ROSTER[1].model==script,"Only roster Goemon selects the ROM adapter")
	var edo_model:Variant=Hero.ROSTER[2].model
	check(edo_model.resource_path.contains("musashi_model"),"Edo retains his current model")
	var shared_chain=ChainPipeVisual.new()
	check(is_equal_approx(model.chain_pipe.link_thickness,1.0) and is_equal_approx(shared_chain.link_thickness,2.6),"Original chain links preserve native proportions without changing other fighters")
	shared_chain.free()
	var loc=model.locomotion
	check(loc.get_script().resource_path.ends_with("recovered_goemon_locomotion.gd"),"Goemon uses original motion selection")
	model.locomotion_velocity=Vector3(0,0,-8)
	model.animate(.1,8,true,0,0,false,1,false);model.sync_skeleton()
	check(loc.source_action==0x0F,"Running samples verified original full-stick run selector")
	check(not model.pipe.visible,"Original run graph leaves the weapon hand empty")
	model.animate(.1,8,false,10,0,false,1,false);model.sync_skeleton()
	check(loc.source_action==0x18,"Rising jump samples original jump action")
	model.animate(.6,8,false,10,0,false,1,false);model.sync_skeleton()
	model.animate(.1,8,false,-10,0,false,1,false);model.sync_skeleton()
	check(loc.source_action==0x19,"Falling samples original airborne action")
	check(loc.source_time<=.1,"Fall action begins at its own first frame")
	loc.reference_jump_flip=.5
	model.animate(.1,8,false,8,0,false,1,false);model.sync_skeleton()
	check(loc.reference_jump_flip==.5,"Original jump leaves double-jump turning state intact")
	for stage in [1,2,3]:
		model.pipe_combo_active=true
		model.animate(.01,0,true,0,.5,false,stage,false);model.sync_skeleton()
		check(loc.source_action==0x67+stage,"Pipe stage %d uses its distinct original clip"%stage)
	var grip=model.skeleton.to_global(model.skeleton.get_bone_global_pose(model.skeleton.find_bone("Hand_L")).origin)
	check(model.chain_pipe.global_position.distance_to(grip)<.001,"Original chain pipe mounts to the animated source weapon hand")
	check(model.coin.global_position.distance_to(grip)<.001,"Held original coin mounts to the animated source weapon hand")
	model.set_surge(true)
	model.animate(.01,0,true,0,0,false,1,false);model.sync_skeleton()
	check(loc.source_action==0x82,"R begins original transformation action")
	check(not model.pipe.visible,"Original transformation graph hides the pipe")
	check(not model.hair_gold.visible,"Transformation gold appearance waits for original frame 10")
	model.animate(1,0,true,0,0,false,1,false);model.sync_skeleton()
	check(model.hair_gold.visible,"Transformation enables gold hair at original cue")
	model.set_surge(false)
	check(not model.hair_gold.visible and model.hair_normal.visible,"Ending R restores original normal head")
	var fx_parent=Node3D.new();fx_parent.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(fx_parent)
	var effect=load("res://scripts/recovered_goemon_vfx.gd").hit(fx_parent,Vector3.ZERO)
	var before_age=effect.age
	paused=true;await create_timer(.05,true).timeout
	check(is_instance_valid(effect) and is_equal_approx(effect.age,before_age),"Original hit effects pause with the game")
	paused=false;fx_parent.queue_free()
	model.queue_free();await process_frame
	print("RECOVERED_GOEMON_RUNTIME_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
