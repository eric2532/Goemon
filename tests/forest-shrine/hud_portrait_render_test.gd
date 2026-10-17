extends SceneTree
# Catches multiplying the cropped portrait by the implicit, uncropped canvas texture.
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():run.call_deferred()
func run():
	if DisplayServer.get_name()=="headless":printerr("Portrait color test requires a real renderer");quit(1);return
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame;AudioServer.set_bus_mute(0,true)
	for id in range(1,13):
		game.player.select_character(id);game.forest_ui.sync()
		var view=SubViewport.new();view.size=Vector2i(256,128);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
		var bg=ColorRect.new();bg.color=Color("162a24");bg.size=Vector2(256,128);view.add_child(bg)
		var actual=game.forest_ui.hero_portrait.duplicate();actual.position=Vector2.ZERO;actual.size=Vector2(128,128);view.add_child(actual)
		var reference=TextureRect.new();var atlas=AtlasTexture.new();atlas.atlas=actual.texture;atlas.region=Rect2(270,100,260,260)
		reference.texture=atlas;reference.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;reference.stretch_mode=TextureRect.STRETCH_SCALE;reference.position=Vector2(128,0);reference.size=Vector2(128,128);view.add_child(reference)
		for i in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var image=view.get_texture().get_image()
		for point in [Vector2i(64,64),Vector2i(40,40),Vector2i(80,40),Vector2i(40,80),Vector2i(80,80)]:
			var a=image.get_pixelv(point);var b=image.get_pixelv(point+Vector2i(128,0))
			check(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)<.08,"Fighter %d crop preserves authored color at %s"%[id,point])
		var corner=image.get_pixel(0,0);var backdrop=image.get_pixel(127,0)
		check(corner.is_equal_approx(backdrop),"Fighter %d portrait keeps transparent circular corners"%id)
		view.queue_free();await process_frame
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	await process_frame;await create_timer(.35).timeout
	print("FOREST_HUD_PORTRAIT_RENDER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
