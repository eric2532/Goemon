extends "res://scripts/goemon_run_pacing_tour.gd"
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
func setup_studio():
	super.setup_studio();actors[0].free()
	var actor=Actor.new();stage.add_child(actor);actor.setup("samurai");actor.seed=0;actors[0]=actor
	header.text="SAMURAI  ·  HAND-HELD RED SCABBARD  ·  DRAW / SLASH / SHEATHE"
	for i in cameras.size():
		cameras[i].size=5.2
		for child in cameras[i].get_parent().get_parent().get_children():
			if child is Label:child.text=["FRONT THREE-QUARTER","LEFT SIDE","REAR THREE-QUARTER"][i]
func position_cameras():
	for i in cameras.size():
		cameras[i].global_position=actors[0].global_position+[Vector3(7,2.8,10),Vector3(10,2.8,0),Vector3(7,2.8,-10)][i]
		cameras[i].look_at(actors[0].global_position+Vector3(0,1.5,0))
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	out="res://docs/samurai-sheath";mode="closeup"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join("frames")))
	var ignore=FileAccess.open(out.path_join(".gdignore"),FileAccess.WRITE);ignore.store_string("");ignore.close()
	root.size=Vector2i(1440,810);root.content_scale_size=root.size;setup_studio()
	await physics_frame;await physics_frame
	for pose_ in ["idle","run","jump"]:
		var state={"grounded":pose_!="jump","vertical":8.0 if pose_=="jump" else 0.0,"motionSpeed":10.2 if pose_=="run" else 0.0}
		for frame in 45:actors[0].animate_pose(state,STEP,frame*STEP,1)
		phase_label.text=pose_.to_upper()+"  ·  RIGHT HAND ON HILT / LEFT HAND ON SHEATH"
		position_cameras();await capture(pose_+".png")
	var cuts=[]
	for stage in 5:
		var a: Dictionary=Actions.PRIMARY.samurai.duplicate();a.merge(Actions.SAMURAI_CUTS[stage],true);a.index=stage;a.primary=true;a.style="samurai-cut";cuts.append(a)
	for stage in 5:
		var a: Dictionary=cuts[stage];a.time=a.contact
		actors[0].animate_pose({"grounded":true,"attack":a},0,0,0);position_cameras()
		phase_label.text="CUT %d / 5  ·  DRAWN AT CONTACT"%(stage+1);await capture("cut-%d.png"%(stage+1))
	var span=0.0
	for a in cuts:span+=a.duration
	for frame in 120:
		var time=frame*STEP
		var state={"grounded":true}
		if time<.6:phase_label.text="READY  ·  SHEATHED"
		elif time<.6+span:
			var local=time-.6;var stage=0
			while stage<4 and local>=cuts[stage].duration:local-=cuts[stage].duration;stage+=1
			var a: Dictionary=cuts[stage].duplicate();a.time=local;state.attack=a
			phase_label.text="CUT %d / 5  ·  QUICK DRAW / SLASH / RETURN"%(stage+1)
		elif time<3.2:
			state.motionSpeed=10.2;phase_label.text="RUN  ·  BOTH HANDS KEEP THE READY GRIP"
		else:
			state.grounded=false;state.vertical=8.0;phase_label.text="JUMP  ·  KATANA STAYS SHEATHED"
		actors[0].animate_pose(state,STEP,time,1);position_cameras();await capture("frames/%03d.png"%frame)
	stage.free();await create_timer(.2).timeout
	print("SAMURAI_SHEATH_TOUR captures=%d failures=%d"%[captures,failures]);quit(1 if failures else 0)
func capture(path: String):
	await process_frame;RenderingServer.force_draw(false)
	var error=root.get_texture().get_image().save_png(out.path_join(path))
	if error!=OK:failures+=1
	captures+=1
