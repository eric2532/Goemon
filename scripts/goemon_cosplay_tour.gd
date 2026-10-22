extends SceneTree
## Actual imported models, same studio, four angles plus class motion poses.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const Roster = preload("res://scripts/rogue_roster.gd")
var stage: Node3D
var camera: Camera3D
var failures = 0
var captures = 0
var out = "res://docs/goemon-cosplay/runtime"

func _initialize():
	call_deferred("run")

func run():
	if DisplayServer.get_name() == "headless":
		push_error("Cosplay tour requires a renderer")
		quit(1)
		return
	root.size = Vector2i(800, 900)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/characters/goemon_cosplay/portraits"))
	stage = Node3D.new()
	root.add_child(stage)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("28313f")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d5dfef")
	env.environment.ambient_light_energy = .65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	for spec in [[Vector3(-4, 6, 5), 1.0], [Vector3(4, 3, 2), .5]]:
		var light = DirectionalLight3D.new()
		stage.add_child(light)
		light.position = spec[0]
		light.look_at(Vector3(0, 1.5, 0))
		light.light_energy = spec[1]
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.6
	var heroes = ["goemon", "edo"] + Array(Roster.CLASS_IDS)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hero=") and arg.trim_prefix("--hero=") in heroes:
			heroes = [arg.trim_prefix("--hero=")]
	for hero in heroes:
		var actor: Node3D
		if hero == "edo":
			actor = load("res://assets/characters/musashi/model/musashi_model.gd").new()
			stage.add_child(actor)
			actor.rotation.y = PI
			actor.animate(1.0/60, 0, true, 0, 0, false, 0, false)
		elif hero == "goemon":
			actor = load("res://assets/models/characters/goemon_cosplay/goemon.glb").instantiate()
			stage.add_child(actor)
			actor.rotation.y = PI
			var sk: Skeleton3D = actor.find_child("Skeleton3D", true, false)
			for i in range(sk.get_bone_count()):
				var name_ = sk.get_bone_name(i)
				if name_.begins_with("Arm_") or name_.begins_with("Forearm_") or name_.begins_with("Hand_"):
					var shoulder = sk.get_bone_global_rest(sk.find_bone("Arm_" + name_.right(1))).origin
					var turn = Basis(Vector3.BACK, deg_to_rad(75 if name_.ends_with("L") else -75))
					sk.set_bone_global_pose(i, Transform3D(turn, shoulder - turn * shoulder) * sk.get_bone_global_rest(i))
		else:
			actor = Actor.new()
			stage.add_child(actor)
			actor.setup(hero)
			actor.seed = 0
			actor.animate_pose({"grounded":true}, 1.0/60, 0, 0)
		for spec in [["front", Vector3(0, 2.0, 10)], ["three-quarter", Vector3(7, 2.0, 10)], ["side", Vector3(10, 2.0, 0)], ["back", Vector3(0, 2.0, -10)]]:
			camera.position = spec[1]
			camera.look_at(Vector3(0, 1.85, 0))
			await capture(hero + "-" + spec[0])
			if spec[0] == "three-quarter":
				root.get_texture().get_image().save_png("res://assets/models/characters/goemon_cosplay/portraits/" + hero + ".png")
		if hero in Roster.CLASS_IDS:
			camera.position = Vector3(7, 2.0, 10)
			camera.look_at(Vector3(0, 1.85, 0))
			for i in range(35):
				actor.animate_pose({"grounded":true,"motionSpeed":7.0,"localMotion":Vector3(0,0,7)}, 1.0/60, i/60.0, 1.0)
			await capture(hero + "-run")
			actor.reset_motion()
			var style = {"samurai":"samurai-cut", "ninja":"ninja", "mage":"staff", "dragoon":"thrust", "ranger":"bow", "explorer":"twin", "master-thief":"pipe"}.get(hero,"cutlass")
			actor.animate_pose({"grounded":true,"attack":{"style":style,"duration":.4,"contact":.12,"time":.12,"index":0}},1.0/60,.12,0)
			await capture(hero + "-attack")
			if hero == "pirate":
				actor.animate_pose({"grounded":true,"drinkGesture":.8},1.0/60,0,0)
				await capture("pirate-drink")
		actor.free()
	print("GOEMON_COSPLAY_TOUR captures=", captures, " failures=", failures)
	quit(1 if failures else 0)

func capture(name_: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(out + "/" + name_ + ".png")
	if error != OK: failures += 1
	captures += 1
