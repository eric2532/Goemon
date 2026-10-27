extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const OUTPUT="res://build/Other Files/Castle Defense Update/"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
func bounds(node:Node3D,relative:Transform3D=Transform3D.IDENTITY)->AABB:
	var result=AABB()
	if node is MeshInstance3D:result=relative*node.mesh.get_aabb()
	elif node is MultiMeshInstance3D:
		for i in node.multimesh.instance_count:
			result=result.merge(relative*node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D:result=result.merge(bounds(child,relative*child.transform))
	return result
func run():
	create_timer(180).timeout.connect(func():printerr("CASTLE_HEIGHT_TIMEOUT");quit(1))
	for meadow in [false,true]:
		for enemy in [false,true]:
			for rotation_ in [0,1]:
				var b={"id":1,"kind":"wall","span":2,"rotation":rotation_,"wind_meadow":meadow,"enemy_castle":enemy,"foundation_depth":3.0}
				var wall=Art.building(b);root.add_child(wall)
				var height=16.0 if enemy else 32.0
				check(absf(bounds(wall).end.y-height)<.02,"Wall art reaches %d m (meadow=%s, enemy=%s)"%[height,meadow,enemy])
				check(absf(bounds(wall.get_node("TerrainFoundation")).position.y+3.0)<.001,"Foundation stays fitted to its original terrain depth")
				check(is_equal_approx(wall.get_node("WallDamage").scale.y,height/16.0),"Fractures follow the visible wall height")
				await physics_frame;await physics_frame
				for y in [24.0,33.0]:
					var ray=PhysicsRayQueryParameters3D.create(wall.to_global(Vector3(0,y,-8)),wall.to_global(Vector3(0,y,8)),1)
					var hit=not wall.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
					check(hit==(y<height),"Physical collision matches the wall at %d m"%y)
				wall.free();await physics_frame
	check(Profile.height("wall")==32.0,"Gameplay height queries use the taller friendly wall")
	for size_ in ["standard","large"]:await map_check(size_)
	print("CASTLE_DEFENSE_HEIGHT_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
func map_check(size_:String):
	var path="res://assets/maps/forest_wind_meadow%s.json"%("_large" if size_=="large" else "")
	set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(path)))
	set_meta("forest_painterly_preview",true)
	var game=load("res://scenes/forest_shrine.tscn").instantiate()
	var cfg="user://castle-height-%d.cfg"%OS.get_process_id();game.settings_path=cfg
	root.add_child(game);current_scene=game
	for i in 8:await process_frame
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.explorer_helpers.set_process(false);game.music.stop()
	var gates=game.model.buildings.values().filter(func(b):return b.kind=="gate")
	check(gates.size()==4 and gates.all(func(b):return b.hp==2500 and b.max_hp==2500),size_+" meadow keeps all four stronger doors")
	var walls=game.model.buildings.values().filter(func(b):return b.kind=="wall")
	check(walls.all(func(b):return absf(bounds(game.world.structure_nodes[b.id]).end.y-32)<.02),size_+" meadow uses the doubled wall art")
	var gate:Dictionary=gates[0];game.model.hero_position=game.model.center(gate);game.world.sync(1)
	var door=game.world.structure_nodes[gate.id].get_node("GateDoor")
	check(door.position.y-door.mesh.size.y*.5>=Profile.GATE_OPENING_HEIGHT-.01,size_+" door still opens to its original clearance")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1280,800);root.title="Goemon Castle Defense Verification"
		var camera=Camera3D.new();game.add_child(camera);camera.current=true
		var center=game.model.center(game.model.shrine())
		camera.position=center+Vector3(100,95,125);camera.look_at(center+Vector3(0,14,0))
		game.ui.hide();DisplayServer.window_move_to_foreground()
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT+size_+"-castle.png")==OK,"Capture "+size_+" castle")
	game.sound_library.cancel();game.queue_free();paused=false
	for i in 4:await process_frame
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
