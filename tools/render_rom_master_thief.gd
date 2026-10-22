extends SceneTree
## Actual game Actor, four angles and action poses; also refresh selection art.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/ROM Goemon Blender Base"
var actor:Node3D
var camera:Camera3D
func _initialize():run.call_deferred()
func shot(label_:String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join("game-thief-"+label_+".png"))
func run():
	root.size=Vector2i(800,900);root.msaa_3d=Viewport.MSAA_4X
	root.transparent_bg="--portraits" in OS.get_cmdline_user_args()
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0) if root.transparent_bg else Color("28313f")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("d5dfef");env.environment.ambient_light_energy=.65
	stage.add_child(env)
	for position_ in [Vector3(-4,6,5),Vector3(4,3,2)]:
		var light=DirectionalLight3D.new();stage.add_child(light);light.position=position_;light.look_at(Vector3(0,1.5,0));light.light_energy=1.0
	camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.6
	actor=load("res://assets/rogue/scripts/actor.gd").new();stage.add_child(actor);actor.setup("master-thief");actor.seed=0
	actor.animate_pose({"grounded":true},0,0,0)
	for spec in [["front",Vector3(0,2,10)],["side",Vector3(10,2,0)],["back",Vector3(0,2,-10)],["three-quarter",Vector3(7,2,10)]]:
		camera.position=spec[1];camera.look_at(Vector3(0,1.85,0));await shot(spec[0])
	if "--portraits" in OS.get_cmdline_user_args():
		# Same framing as existing portraits: face remains in the HUD crop.
		root.get_texture().get_image().save_png("res://assets/models/characters/goemon_cosplay/portraits/master-thief.png")
		root.get_texture().get_image().save_png("res://assets/models/characters/selection_portraits/master-thief.png")
	for state in [
		{"name":"run","grounded":true,"motionSpeed":7.0},
		{"name":"jump","grounded":false,"vertical":8.0},
		{"name":"land","grounded":true},
		{"name":"attack","grounded":true,"attack":{"primary":true,"style":"pipe","index":0,"duration":.38,"contact":.105,"time":.105}},
		{"name":"guard","grounded":true,"blocking":true,"guardStyle":"thief"},
		{"name":"crouch","grounded":true,"crouched":true},
		{"name":"grand-smoke","grounded":true,"buffTime":3.0}]:
		actor.animate_pose(state,.1,.2,1 if state.name=="run" else 0);await shot(state.name)
	print("ROM_MASTER_THIEF_GAME_RENDERS_COMPLETE")
	stage.free();quit()
