extends "res://scripts/goemon_run_pacing_tour.gd"
## Production Forest Goemon attacks, sampled and played at 30 fps.
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
const Combat=preload("res://scripts/rogue_roster_combat.gd")

func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	out="res://docs/full-body-strike"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
		elif arg=="--roster":mode="roster"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join("frames")))
	var ignore=FileAccess.open(out.path_join(".gdignore"),FileAccess.WRITE);ignore.store_string("");ignore.close()
	root.size=Vector2i(1920,1536) if mode=="roster" else Vector2i(1440,810)
	root.content_scale_size=root.size;setup_studio()
	header.text="MELEE CONTACT  ·  CURRENT CHARACTER RIGS" if mode=="roster" else "GOEMON FULL-BODY SWING  ·  THREE VIEWS  ·  REAL TIME 1×"
	phase_label.text="Forward shoulder · planted lead foot · full-body follow-through"
	if mode!="roster":
		for i in range(cameras.size()):cameras[i].get_parent().get_parent().get_child(1).text=["FRONT THREE-QUARTER","SIDE","REAR THREE-QUARTER"][i]
	await physics_frame;await physics_frame
	actors[0].pipe_combo_active=true;actors[0].rogue_pipe_combo_active=false;actors[0].equipped=true
	if mode=="roster":
		actors[0].animate(STEP,0,true,0,1.0-PipeCombo.CONTACT[0],false,1,false);actors[0].sync_skeleton()
		for i in range(2,IDS.size()):
			var state={"grounded":true,"motionSpeed":0.0}
			if IDS[i] not in ["mage","ranger"]:
				var a: Dictionary=(Combat.COMBO[0] if IDS[i]=="pirate" else Actions.PRIMARY[IDS[i]]).duplicate()
				a.time=a.contact;a.primary=true;a.index=0;a.swingSide=1;state.attack=a
			actors[i].animate_pose(state,STEP,0,0)
		position_cameras();await capture("melee-roster-contact.png")
	else:
		var model=actors[0]
		for key in ["windup","contact","follow-through"]:
			var t={"windup":PipeCombo.CONTACT[0]*.52,"contact":PipeCombo.CONTACT[0],"follow-through":PipeCombo.CONTACT[0]+.24}[key]
			model.animate(STEP,0,true,0,1.0-t,false,1,false);model.sync_skeleton();position_cameras();await capture(key+".png")
		# Two full combos with a short idle recovery between each chain.
		for frame in range(99):
			var time=fposmod(frame*STEP,1.65);var stage_index=0
			while stage_index<3 and time>=PipeCombo.DURATIONS[stage_index]:time-=PipeCombo.DURATIONS[stage_index];stage_index+=1
			var attack=1.0-time/PipeCombo.DURATIONS[stage_index] if stage_index<3 else 0.0
			phase_label.text=("SWING %d"%(stage_index+1) if stage_index<3 else "RECOVER")+"  ·  LEFT FOOT LEADS / RIGHT SHOULDER DRIVES FORWARD"
			model.animate(STEP,0,true,0,attack,false,stage_index+1,false);model.sync_skeleton();position_cameras();await capture("frames/%03d.png"%frame)
	stage.free();await create_timer(.2).timeout
	print("GOEMON_FULL_BODY_STRIKE_TOUR captures=",captures," failures=",failures);quit(1 if failures else 0)

func position_cameras():
	for i in range(cameras.size()):
		var actor=actors[i if mode=="roster" else 0]
		cameras[i].global_position=actor.global_position+(Vector3(7,3,10) if mode=="roster" else [Vector3(7,3,10),Vector3(10,2.7,0),Vector3(-7,3,-10)][i])
		cameras[i].size=5.5 if mode=="roster" else 6.0
		cameras[i].look_at(actor.global_position+Vector3(0,1.55,.12))

func capture(path: String):
	await process_frame
	# Offscreen captures must keep rendering when another window covers this one.
	RenderingServer.force_draw(false)
	var error=root.get_texture().get_image().save_png(out.path_join(path))
	if error!=OK:failures+=1
	captures+=1
