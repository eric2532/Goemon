extends SceneTree
## Real rendered budget and preview regression for the complete starter fort.
var game
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func run():
	if DisplayServer.get_name()=="headless":printerr("Starter fort render test requires a real renderer");quit(1);return
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	AudioServer.set_bus_mute(0,true)
	for i in range(30):await process_frame
	var calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("STARTER_FORT_DRAW_CALLS ",calls)
	check(calls>0 and calls<1500,"Complete fort keeps enough draw budget for combat crowds")
	game.world.show_preview("wall",Vector2i(3,-2),0,true)
	for kind in ["MeshInstance3D","MultiMeshInstance3D"]:
		for part in game.world.ghost_art.find_children("*",kind,true,false):
			check(part.material_override!=null and part.material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and part.material_override.albedo_color.a<.5,"Every visible wall preview part stays translucent")
	print("FOREST_STARTER_FORT_RENDER_RESULT checks=%d failures=%d"%[checks,failures])
	await game.quit_clean();quit(1 if failures else 0)
