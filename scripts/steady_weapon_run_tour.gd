extends "res://scripts/goemon_run_pacing_tour.gd"
var fighter="samurai"
func setup_studio():
	super.setup_studio();actors[0].free()
	var actor=Actor.new();stage.add_child(actor);actor.setup(fighter);actor.seed=0;actors[0]=actor
	header.text={"samurai":"SAMURAI","magic-swordsman":"MAGIC SWORDSMAN","ranger":"RANGER"}[fighter]+"  ·  STEADY WEAPON CARRY / FULL LEG STRIDE"
	for i in cameras.size():
		cameras[i].size=5.8
		for child in cameras[i].get_parent().get_parent().get_children():
			if child is Label:child.text=["FRONT THREE-QUARTER","SIDE","REAR THREE-QUARTER"][i]
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fighter="):fighter=arg.trim_prefix("--fighter=")
	await super.run()
func pose_run(speed: float,time: float):
	actors[0].position+=Vector3.BACK*speed*STEP
	actors[0].animate_pose({"grounded":true,"isPlayer":true,"motionSpeed":speed,"localMotion":Vector3.BACK*speed},STEP,time,1)
func position_cameras():
	var base=actors[0].global_position
	for i in cameras.size():
		cameras[i].global_position=base+[Vector3(7,2.8,10),Vector3(10,2.8,0),Vector3(7,2.8,-10)][i]
		cameras[i].look_at(base+Vector3(0,1.65,0))
