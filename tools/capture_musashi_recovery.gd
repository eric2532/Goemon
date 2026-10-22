extends SceneTree
## Source-pose review, separate from the playable integration tests.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi ROM Gameplay Audit/preview-frames/"
var model
var title:Label
var caption:Label
var frame_index=0
var trace=[]
func _initialize():run.call_deferred()
func shot(clip:String,tick:int,save_name:String=""):
	model._sample(clip,float(tick)/30.0)
	await process_frame
	RenderingServer.force_draw(false)
	var pixels=root.get_texture().get_image()
	pixels.save_png(OUT+"frame_%04d.png"%frame_index)
	if not save_name.is_empty():pixels.save_png(OUT+save_name+".png")
	trace.append({"frame":frame_index,"clip":clip,"tick":tick,"label":title.text})
	frame_index+=1
func sequence(label_:String,clip:String,ticks:int,playable:bool=true,save_tick:int=-1,save_name:String=""):
	title.text=label_
	caption.text="Playable with your controls" if playable else "Recovered entry · gameplay conditions still being traced"
	for tick in ticks+8:
		await shot(clip,mini(tick,ticks-1),save_name if tick==save_tick else "")
func run():
	DirAccess.make_dir_recursive_absolute(OUT);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(720,720)
	var environment=WorldEnvironment.new();root.add_child(environment);environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("172a33")
	model=load("res://scripts/recovered_musashi_model.gd").new();root.add_child(model)
	var camera=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.6;camera.position=Vector3(-2.4,1.8,-4);camera.look_at(Vector3.UP*.92);camera.make_current()
	var canvas=CanvasLayer.new();root.add_child(canvas)
	title=Label.new();title.position=Vector2(24,24);title.add_theme_font_size_override("font_size",22);canvas.add_child(title)
	caption=Label.new();caption.position=Vector2(24,670);caption.add_theme_font_size_override("font_size",17);canvas.add_child(caption)
	await process_frame
	await sequence("LUMINA · standing strike · RMB",model.HEAVY,21,true,10,"lumina-standing")
	await sequence("LUMINA · airborne strike · RMB",model.AIR_HEAVY,17,true,7,"lumina-air")
	await sequence("GUARD · R",model.GUARD,20,true,8,"guard")
	await sequence("LUMINA ROTATION · hold E / release",model.ROTATION,21,true,12,"rotation")
	for entry in [["Fusion finisher windup","800d4d88",6],["Finisher launch","800d4da8",1],["Finisher airborne transition","800d4db4",6],["Finisher active pose","800d4dd4",5],["Finisher landing","800d4df4",5],["Fusion branch","800d4e6c",6],["Advanced sword entry","800d52a8",11],["Advanced sword continuation","800d52e8",12],["Advanced recovery","800d533c",6],["Additional body loop","800d5c6c",20]]:
		await sequence("RECOVERED · %s\n0x%s"%[entry[0],entry[1]],"Recovered__"+entry[1],entry[2],false)
	var report=FileAccess.open(OUT+"trace.json",FileAccess.WRITE);report.store_string(JSON.stringify(trace,"\t"));report.close()
	print("MUSASHI_RECOVERY_CAPTURE frames=",frame_index)
	model.queue_free();canvas.queue_free();camera.queue_free();environment.queue_free();await process_frame;quit()
