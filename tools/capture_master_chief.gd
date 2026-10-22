extends SceneTree
## Regenerate portraits and capture the native FPS using the actual game renderer.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/master-chief"
const ASSETS="res://assets/characters/master_chief"
var game
func _initialize():run.call_deferred()
func frames(count:int):
	for i in count:await process_frame
func image(view:Viewport,path:String):
	await RenderingServer.frame_post_draw
	var result=view.get_texture().get_image().save_png(path)
	assert(result==OK,"Could not save capture: "+path)
func portrait(zoom:bool):
	var view=SubViewport.new();view.size=Vector2i(512,512);view.own_world_3d=true
	view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var model=load(ASSETS+"/master_chief.glb").instantiate();view.add_child(model)
	var camera=Camera3D.new();view.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=.87 if zoom else 2.5
	var center=Vector3(0,1.72,0) if zoom else Vector3(0,1.02,0)
	camera.position=center+Vector3(-1.25,.45,-3.5);camera.look_at(center)
	if zoom:
		var offset=camera.basis.x*(-.23)+Vector3.UP*.08
		camera.position+=offset;camera.look_at(center+offset)
	var env=WorldEnvironment.new();var environment=Environment.new()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(0,0,0,0)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("cad9ef");environment.ambient_light_energy=.65
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=environment;view.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-25,-140,0);key.light_energy=1.8;view.add_child(key)
	var rim=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-20,45,0);rim.light_color=Color("a9cfff");rim.light_energy=1.3;view.add_child(rim)
	await frames(6)
	await image(view,ProjectSettings.globalize_path(ASSETS+("/hud_portrait.png" if zoom else "/portrait.png")))
	view.queue_free();await frames(2)
func run():
	DirAccess.make_dir_recursive_absolute(OUT)
	if "--portraits" in OS.get_cmdline_user_args():
		await portrait(false);await portrait(true);quit();return
	root.size=Vector2i(1440,900)
	set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://master-chief-capture-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(12)
	game.player.select_character(18)
	game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
	game.tuning.invincible=true
	game.player.global_position=Vector3(0,.1,18)
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=0
	await frames(35)
	await image(root,OUT+"/fps-gameplay.png")
	var wall=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(4,4,.1);wall.mesh=box
	var material=StandardMaterial3D.new();material.albedo_color=Color("507078");wall.material_override=material
	game.add_child(wall);wall.global_position=game.camera_rig.camera.global_position-game.camera_rig.camera.global_basis.z*.42
	await frames(3);await image(root,OUT+"/fps-wall-depth.png");wall.queue_free();await frames(2)
	game.player.active_ability.input(_pressed("light_attack"))
	await frames(2)
	await image(root,OUT+"/fps-firing.png")
	game.player.active_ability.cancel()
	game.show_rogue_roster();await frames(8)
	var card=game.find_child("RogueFighter_master-chief",true,false)
	if card!=null:card.grab_focus()
	await frames(10)
	await image(root,OUT+"/q-character-picker.png")
	game.close_rogue_roster();game.player.select_character(1);await frames(15)
	await image(root,OUT+"/restored-third-person.png")
	game.queue_free();paused=false;await frames(3)
	quit()
func _pressed(action:String)->InputEventAction:
	var event=InputEventAction.new();event.action=action;event.pressed=true;return event
