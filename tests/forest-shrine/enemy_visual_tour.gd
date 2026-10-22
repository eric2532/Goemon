extends SceneTree
const Renderer=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Fixtures=preload("res://tests/forest-shrine/enemy_visual_test.gd")
var game
var crowd
var camera: Camera3D
var out="res://.superpowers/sdd/2026-10-14-forest-enemy-integration/visuals"
func _initialize():call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	game=Fixtures.TestGame.new();root.add_child(game)
	var environment=WorldEnvironment.new();var settings=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.18,.24,.27)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color(.8,.85,.92);settings.ambient_light_energy=.6
	environment.environment=settings;game.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-30,0);light.light_energy=1.7;light.shadow_enabled=true;game.add_child(light)
	var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane
	var floor_material=StandardMaterial3D.new();floor_material.albedo_color=Color(.28,.34,.29);floor_material.roughness=.9;floor_mesh.material_override=floor_material;game.add_child(floor_mesh)
	camera=Camera3D.new();camera.fov=45;camera.far=300;game.add_child(camera);camera.current=true
	crowd=Renderer.new();crowd.game=game;crowd.low_fidelity=false;game.add_child(crowd);crowd.set_process(false)
	var points=[Vector3(-5,0,0),Vector3(0,0,0),Vector3(35,0,0),Vector3(5,0,0)]
	for kind in range(4):
		var actor=Fixtures.TestActor.new();actor.forest_id=kind;actor.variant=kind;actor.add_child(actor.model);actor.position=points[kind];game.add_child(actor);game.enemies.append(actor)
		game.model.enemies[kind]={"variant":kind,"pos":points[kind],"facing":0.0,"walk_phase":0.0,"attack_progress":0.0,"attack_point":points[kind]+Vector3(0,3,-10),"frozen":0.0,"action":"walk"}
	await shot("small_front",Vector3(0,3,-17),Vector3(0,2.3,0))
	await shot("small_side",Vector3(-12,3,-10),Vector3(0,2.3,0))
	await shot("small_back",Vector3(0,3,17),Vector3(0,2.3,0))
	await shot("giant_front",Vector3(35,13,-48),Vector3(35,11,0))
	await shot("giant_side",Vector3(78,13,-3),Vector3(35,11,0))
	await shot("giant_back",Vector3(35,13,48),Vector3(35,11,0))
	game.model.enemies[2].walk_phase=.6
	await shot("giant_walk_left",Vector3(53,10,-42),Vector3(35,9,0))
	game.model.enemies[2].walk_phase=3.7
	await shot("giant_walk_right",Vector3(53,10,-42),Vector3(35,9,0))
	game.model.enemies[2].action="windup";game.model.enemies[2].attack_progress=.5
	await shot("giant_windup",Vector3(53,10,-42),Vector3(35,9,0))
	game.model.enemies[2].attack_progress=1.0
	await shot("giant_contact",Vector3(53,10,-42),Vector3(35,9,0))
	game.model.enemies[1].action="windup";game.model.enemies[1].attack_progress=1.0;game.model.enemies[1].attack_point=Vector3(0,2,-24)
	await shot("archer_bow_draw",Vector3(0,3,-8),Vector3(0,2.5,0))
	game.model.enemies[1].action="walk";game.model.enemies[1].attack_progress=0
	game.model.enemies[2].action="walk";game.model.enemies[2].attack_progress=0
	for frame in range(24):
		var phase=TAU*frame/24.0
		game.model.enemies[2].walk_phase=phase+.3
		game.model.enemies[2].pos=Vector3(35,0,-3.0*frame/24.0)
		game.enemies[2].position=game.model.enemies[2].pos
		await shot("walk_%02d"%frame,Vector3(53,10,-42),Vector3(35,9,0))
	# Representative shared-mesh stress: 200 enemy instances, bounded draw surfaces.
	for id in range(4,200):
		var kind=id%4;var actor=Fixtures.TestActor.new();actor.forest_id=id;actor.variant=kind;actor.add_child(actor.model)
		actor.position=Vector3((id%20)*4-40,0,float(id/20)*5+20);game.add_child(actor);game.enemies.append(actor)
		game.model.enemies[id]={"variant":kind,"pos":actor.position,"facing":0.0,"walk_phase":.4,"attack_progress":0.0,"frozen":0.0,"action":"walk"}
	camera.position=Vector3(0,35,-90);camera.look_at(Vector3(0,8,40),Vector3.UP)
	var total_usec=0;var max_usec=0
	for frame in range(60):
		for data in game.model.enemies.values():data.walk_phase+=.02
		var start=Time.get_ticks_usec();crowd._process(1.0/60);var elapsed=Time.get_ticks_usec()-start
		total_usec+=elapsed;max_usec=maxi(max_usec,elapsed);await process_frame
	print("FOREST_ENEMY_VISUAL_NATIVE actor_count=200 shared_batches=%d cpu_update_average_ms=%.3f cpu_update_max_ms=%.3f draw_calls=%d rendered_objects=%d"%[crowd.batches.size(),total_usec/60000.0,max_usec/1000.0,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	quit()
func shot(label: String,position: Vector3,target: Vector3):
	camera.position=position;camera.look_at(target,Vector3.UP);crowd._process(0)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+label+".png")
	print("FOREST_ENEMY_VISUAL_FRAME "+label)
