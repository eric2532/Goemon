extends SceneTree
## Render the actual playable Hero controller, not an animation-only substitute.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi ROM Gameplay Audit/second-pass-preview/"
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
	trace.append({"frame":index,"position":[p.position.x,p.position.y,p.position.z],"clip":p.model.current_clip,"jumps":p.jumps_used,"finisher_phase":p.active_ability.finisher_phase,"equipment":p.model.outfit_mask});index+=1
func advance():
	for i in 2:
		await physics_frame;p._physics_process(1.0/60.0)
	var camera=game.camera_rig.camera
	camera.global_position=Vector3(p.position.x-3.2,2.8,p.position.z-5.5);camera.look_at(Vector3(p.position.x,1,p.position.z))
func run():
	DirAccess.make_dir_recursive_absolute(OUT);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,720)
	fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
	game=await fixture.make_game("original");Engine.physics_ticks_per_second=60;Engine.time_scale=1
	fixture.clear_targets();p=fixture.reset_player(13);p.set_physics_process(false);game.ui.hide();game.tuning.invincible=true
	p.position=Vector3(0,.05,60)
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.smoke_mode=true
	game.camera_rig.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera_rig.camera.size=5.0
	var canvas=CanvasLayer.new();canvas.layer=90;root.add_child(canvas)
	title=Label.new();title.position=Vector2(24,22);title.add_theme_font_size_override("font_size",27);canvas.add_child(title)
	caption=Label.new();caption.position=Vector2(24,665);caption.add_theme_font_size_override("font_size",19);canvas.add_child(caption)
	title.text="MUSASHI · SOURCE MOVEMENT + L-BELT DOUBLE JUMP"
	caption.text="WASD · Hold Space for height · Press Space again for double jump"
	for frame in 90:
		p.smoke_move=Vector2(.4,0) if frame<30 else Vector2.ZERO
		if frame==15:Input.action_press("jump");p.jump_buffer=.15
		if frame==26:Input.action_release("jump")
		if frame==29:Input.action_press("jump");p.jump_buffer=.15
		if frame==43:Input.action_release("jump")
		await advance();await capture("double-jump" if frame==33 else "")
	p.smoke_move=Vector2.ZERO;p.active_ability.cancel();p.active_ability.locomotion.reset();p.position=Vector3(0,.05,60)
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
	title.text="FUSION · COMPLETE FOURTH ATTACK"
	caption.text="Four clicks · Windup → launch → apex hold → falling contact → landing"
	for frame in 90:
		if frame in [0,14,31,47]:p.active_ability.primary_attack()
		await advance();await capture("finisher" if p.active_ability.finisher_phase=="drop" else "")
	title.text="ORIGINAL EQUIPMENT · ALL FIVE PIECES"
	caption.text="L-Goggles · L-Belt · L-Brace · L-Vest · L-Shoes"
	p.active_ability.cancel();p.model.set_outfit_mask(31)
	for frame in 30:await advance();await capture("all-equipment" if frame==8 else "")
	canvas.hide();game.ui.show();game.show_rogue_roster(false)
	var roster=game.menu.find_child("MusashiOutfits",true,false);roster.pressed.emit()
	await process_frame
	game.menu.find_child("MusashiGearAll",true,false).pressed.emit()
	await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+"equipment-picker.png")
	var file=FileAccess.open(OUT+"trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace,"\t"));file.close()
	print("MUSASHI_SECOND_PASS_CAPTURE frames=",index)
	canvas.queue_free();await fixture.close();fixture.queue_free();await process_frame;quit()
