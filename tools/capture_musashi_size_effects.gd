extends SceneTree
## Render the actual playable Hero controller, not an animation-only substitute.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi ROM Gameplay Audit/Size and Effects/preview/"
var fixture
var game
var p
var title:Label
var caption:Label
var index=0
var trace=[]
func _initialize():run.call_deferred()
func capture(save_name:String=""):
	await process_frame;RenderingServer.force_draw(false)
	var pixels=root.get_texture().get_image();pixels.save_png(OUT+"frame_%04d.png"%index)
	if not save_name.is_empty():pixels.save_png(OUT+save_name+".png")
	trace.append({"frame":index,"position":[p.position.x,p.position.y,p.position.z],"clip":p.model.current_clip,"jumps":p.jumps_used,"finisher_phase":p.active_ability.finisher_phase,"equipment":p.model.outfit_mask,"trail_pairs":p.model.sword_trail.samples.size(),"vortices":p.model.rotation_effect.vortices.size(),"spin_yaw":p.active_ability.rotation_angle});index+=1
func advance():
	for i in 2:
		await physics_frame;p._physics_process(1.0/60.0)
	var camera=game.camera_rig.camera
	camera.global_position=Vector3(p.position.x-10,9.0,p.position.z-18);camera.look_at(Vector3(p.position.x,3,p.position.z))
func run():
	DirAccess.make_dir_recursive_absolute(OUT);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,720)
	fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
	game=await fixture.make_game("original");Engine.physics_ticks_per_second=60;Engine.time_scale=1
	fixture.clear_targets();p=fixture.reset_player(13);p.set_physics_process(false);game.ui.hide();game.tuning.invincible=true
	p.position=Vector3(0,.05,90)
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.smoke_mode=true
	game.camera_rig.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera_rig.camera.size=17.0
	var canvas=CanvasLayer.new();canvas.layer=90;root.add_child(canvas)
	title=Label.new();title.position=Vector2(24,22);title.add_theme_font_size_override("font_size",27);canvas.add_child(title)
	caption=Label.new();caption.position=Vector2(24,665);caption.add_theme_font_size_override("font_size",19);canvas.add_child(caption)
	title.text="MUSASHI · FULL GEAR · THREEFOLD SIZE"
	caption.text="All five original equipment pieces · original proportions"
	p.model.set_outfit_mask(31)
	for frame in 25:await advance();await capture("full-gear" if frame==12 else "")
	title.text="FUSION · ORIGINAL BLUE SWORD RIBBONS"
	caption.text="Recovered pose endpoints · original colors, timing and additive quads"
	for frame in 90:
		if frame in [0,14,31,47]:p.active_ability.primary_attack()
		await advance();await capture("fusion" if frame==6 else "")
	p.active_ability.cancel()
	title.text="LUMINA · ORIGINAL RED SWORD RIBBONS"
	for frame in 28:
		if frame==0:p.active_ability.start_attack(true)
		await advance();await capture("lumina" if frame==8 else "")
	p.active_ability.cancel()
	title.text="1 · LUMINA ROTATION · ORIGINAL CHARGED SPIN"
	caption.text="One key · original accelerating turn · original red Lumina ribbon"
	for frame in 35:
		if frame==0:p.active_ability.select_number(1)
		await advance();await capture("spin" if frame==15 else "")
	p.active_ability.cancel()
	title.text="2 · MIGHTY STRIKE · ORIGINAL COUNTER"
	caption.text="One key · counter motion · recovered golden vortex and shock ring"
	for frame in 65:
		if frame==0:p.active_ability.select_number(2)
		await advance();await capture("counter" if frame==20 else "")
	var file=FileAccess.open(OUT+"trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace,"\t"));file.close()
	print("MUSASHI_SIZE_EFFECTS_CAPTURE frames=",index)
	canvas.queue_free();await fixture.close();fixture.queue_free();await process_frame;quit()
