extends "res://scripts/goemon_run_pacing_tour.gd"
## Capture the production two-handed carry at real-time run/sprint cadence.
func setup_studio():
	super.setup_studio()
	actors[0].free()
	var actor=Actor.new();stage.add_child(actor);actor.setup("magic-swordsman");actor.seed=0
	actors[0]=actor
	header.text="MAGIC SWORDSMAN  ·  TWO-HANDED LOW SWORD CARRY"
	var labels=["REAR THREE-QUARTER","RIGHT SIDE","FRONT THREE-QUARTER"]
	for i in cameras.size():
		cameras[i].size=6.0
		var panel=cameras[i].get_parent().get_parent()
		for child in panel.get_children():
			if child is Label:child.text=labels[i]

func pose_run(speed: float,time: float):
	actors[0].position+=Vector3.BACK*speed*STEP
	actors[0].animate_pose({"grounded":true,"isPlayer":true,"motionSpeed":speed,"localMotion":Vector3.BACK*speed},STEP,time,1)

func position_cameras():
	var base=actors[0].global_position
	for i in cameras.size():
		cameras[i].global_position=base+[Vector3(7,2.8,-10),Vector3(10,2.8,0),Vector3(7,2.8,10)][i]
		cameras[i].look_at(base+Vector3(0,1.65,0))
