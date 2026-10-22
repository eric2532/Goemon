extends SceneTree
## Checks native artwork reuse and a bounded renderer while all distant loot survives.
const Economy=preload("res://scripts/forest/forest_ryo_economy.gd")
const Renderer=preload("res://scripts/forest/forest_ryo_drops.gd")
class RenderHost extends Node3D:
	var model:Dictionary
	var player:Node3D
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	var m=load("res://scripts/forest/forest_model.gd").new()
	m.reset(42,{},{"deposits":[],"trees":[],"buildings":[]});m.phase="wave";m.gold=0
	var r=Economy.new(m)
	var host=RenderHost.new();host.model={"ryo":r};host.player=Node3D.new()
	root.add_child(host);host.add_child(host.player)
	var camera=Camera3D.new();host.add_child(camera);camera.position=Vector3(0,3.5,9);camera.look_at(Vector3(0,1,0));camera.current=true
	var renderer=Renderer.new();renderer.game=host;host.add_child(renderer);renderer.set_process(false)
	for i in range(400):r.spawn_enemy_drop({"id":i,"hp":0,"variant":0,"pos":Vector3((i%20)*3,0,(i/20)*3)})
	renderer.sync()
	check(renderer.batch.multimesh.visible_instance_count==256 and renderer.get_child_count()==1,"Four hundred drops use one bounded 256-instance batch")
	check(r.drops.size()==400 and r.uncollected_value()==4800 and m.gold==0,"Visual overflow preserves every distant drop and all 4,800 ryo")
	var material=renderer.batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	check(material.albedo_texture.resource_path=="res://assets/characters/recovered_goemon/weapons/coin_source.png","Collectibles reuse the recovered ROM ryo texture without substituting a generic coin")
	var bounds:Vector3=renderer.batch.multimesh.mesh.get_aabb().size
	check(absf(bounds.x-.5)<.001 and absf(bounds.y-.48)<.001 and bounds.z<.001,"The native ROM coin mesh keeps its recovered half-metre geometry: %s"%bounds)
	host.player.position=Vector3(57,0,57);renderer.selection_clock=0;renderer.sync()
	check(renderer.visible_ids.has(400),"Approaching a previously distant coin makes its preserved visual visible")
	r.reset();renderer.sync()
	check(renderer.batch.multimesh.visible_instance_count==0,"Reset removes the previous run's coin visuals")
	if "--visual" in OS.get_cmdline_user_args():
		root.size=Vector2i(960,600)
		var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color("#172926");host.add_child(env)
		for i in range(3):r.spawn_enemy_drop({"id":1000+i,"hp":0,"variant":i*2,"pos":Vector3((i-1)*2.2,0,0)})
		for i in range(28):r.tick(.02,[])
		renderer.selection_clock=0;renderer.sync()
		await process_frame;await process_frame
		var folder=OS.get_environment("FOREST_RYO_CAPTURE_DIR")
		if folder.is_empty():folder=ProjectSettings.globalize_path("res://build/Other Files/ryo-repairs")
		var destination=folder.path_join("native-ryo-drops.png")
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		root.get_texture().get_image().save_png(destination)
		print("RYO_RENDER_CAPTURE "+destination)
	host.queue_free();await process_frame
	m=null;r=null;material=null;Renderer.coin_mesh=null
	print("FOREST_RYO_DROPS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
