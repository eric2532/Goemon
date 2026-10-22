extends "res://scripts/goemon_run_pacing_tour.gd"
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
func setup_studio():
	super.setup_studio();actors[0].free()
	var actor=Actor.new();stage.add_child(actor);actor.setup("knight");actor.seed=0;actors[0]=actor
	header.text="KNIGHT  ·  APPROVED CLAYMORE / LION SHIELD / DYNAMIC NAVY CAPE"
	for i in cameras.size():
		cameras[i].size=5.6
		for child in cameras[i].get_parent().get_parent().get_children():
			if child is Label:child.text=["FRONT THREE-QUARTER","LEFT SIDE","REAR THREE-QUARTER"][i]
func position_cameras():
	for i in cameras.size():
		cameras[i].global_position=actors[0].global_position+[Vector3(7,2.8,10),Vector3(10,2.8,0),Vector3(7,2.8,-10)][i]
		cameras[i].look_at(actors[0].global_position+Vector3(0,1.85,0))
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	out="res://docs/knight-integration";mode="closeup"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join("frames")))
	var ignore=FileAccess.open(out.path_join(".gdignore"),FileAccess.WRITE);ignore.store_string("");ignore.close()
	root.size=Vector2i(1440,810);root.content_scale_size=root.size;setup_studio()
	await physics_frame;await physics_frame
	for label_ in ["idle","run","guard","jump","strike"]:
		actors[0].reset_motion()
		var state={"grounded":label_!="jump","motionSpeed":10.2 if label_=="run" else 0.0,"vertical":8.0 if label_=="jump" else 0.0,"blocking":label_=="guard"}
		if label_=="strike":
			var a: Dictionary=Actions.PRIMARY.knight.duplicate();a.index=0;a.primary=true;a.time=a.contact;state.attack=a
		for frame in 45:actors[0].animate_pose(state,STEP,frame*STEP,1)
		phase_label.text=label_.to_upper();position_cameras();await capture(label_+".png")
	actors[0].reset_motion()
	for frame in 120:
		var time=frame*STEP;var state={"grounded":true}
		if time<1.0:phase_label.text="READY  ·  RELAXED UPWARD SWORD / CENTERED SHIELD GRIP"
		elif time<2.5:
			state.motionSpeed=10.2;state.localMotion=Vector3.BACK*10.2;phase_label.text="RUN  ·  SHIELD FACES LEFT / STEADY BODY / MOVING LEGS AND CAPE"
		elif time<2.99:
			var a: Dictionary=Actions.PRIMARY.knight.duplicate();a.index=0;a.primary=true;a.time=time-2.5;state.attack=a
			phase_label.text="HEAVY STRIKE  ·  REAL CLAYMORE CONTACT REACH"
		elif time<3.5:state.blocking=true;phase_label.text="GUARD  ·  SHIELD TURNS FORWARD"
		else:phase_label.text="READY  ·  RETURN TO NATURAL CARRY"
		actors[0].animate_pose(state,STEP,time,1);position_cameras();await capture("frames/%03d.png"%frame)
	stage.free();await create_timer(.2).timeout
	print("KNIGHT_DESIGN_TOUR captures=%d failures=%d"%[captures,failures]);quit(1 if failures else 0)
func capture(path: String):
	await process_frame;RenderingServer.force_draw(false)
	var error=root.get_texture().get_image().save_png(out.path_join(path))
	if error!=OK:failures+=1
	captures+=1
