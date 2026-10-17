extends "res://scripts/goemon_full_body_strike_tour.gd"
## Real-time idle preview using the same player model and breathing controller.
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	out="res://docs/swing-breathing/idle"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join("frames")))
	var ignore=FileAccess.open(out.path_join(".gdignore"),FileAccess.WRITE);ignore.store_string("");ignore.close()
	root.size=Vector2i(1440,810);root.content_scale_size=root.size;setup_studio()
	header.text="IDLE BREATHING  ·  THREE VIEWS  ·  REAL TIME 1×"
	phase_label.text="Gentle chest rise · relaxed shoulders and head · planted feet"
	for i in range(cameras.size()):cameras[i].get_parent().get_parent().get_child(1).text=["FRONT THREE-QUARTER","SIDE","REAR THREE-QUARTER"][i]
	await physics_frame;await physics_frame
	var model=actors[0];model.equipped=true
	for frame in range(60):model.animate(STEP,0,true,0,0,false,0,false);model.sync_skeleton()
	for frame in range(120):
		model.animate(STEP,0,true,0,0,false,0,false);model.sync_skeleton();position_cameras()
		for camera in cameras:camera.size=5.0
		await capture("frames/%03d.png"%frame)
	stage.free();await create_timer(.2).timeout
	print("GOEMON_IDLE_BREATH_TOUR captures=",captures," failures=",failures);quit(1 if failures else 0)
