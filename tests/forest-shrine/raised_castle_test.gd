extends SceneTree
const Document=preload("res://tests/forest-shrine/reference/map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUTPUT="res://build/Other Files/Castle Side Stairs/"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",note)
func run():
	create_timer(240,true,false,true).timeout.connect(func():printerr("RAISED_CASTLE_TIMEOUT");quit(1))
	check(is_equal_approx(Layout.CASTLE_HALF_SIZE*2,124.8) and is_equal_approx(Layout.CASTLE_HEIGHT,41.6),"Courtyard width, depth and elevation increase by exactly 30 percent")
	for size_ in ["standard","large"]:await map_check(size_)
	check(checks>=103,"Both map checks completed")
	print("RAISED_CASTLE_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
func map_check(size_:String):
	var doc=Document.new(false)
	check(doc.read_file(Document.VALLEY_LARGE_PATH if size_=="large" else Document.VALLEY_PATH).is_empty(),size_+" layout validates")
	doc.data.raised_castle=true
	check(doc.play_error().is_empty(),size_+" editor proves arrivals can reach the shrine through the stairs")
	var old=doc.data.duplicate(true);old.erase("raised_castle")
	var legacy=Model.new();legacy.reset(42,{},old,false)
	check(not legacy.raised_castle and legacy.surface_height(0,0)==0,size_+" saved maps without the flag keep their original ground")
	check(legacy.buildings.values().filter(func(b):return b.kind=="gate").all(func(b):return not b.breached),size_+" old maps retain working doors")
	var model=Model.new();model.reset(42,{},doc.data,false)
	var old_heights=legacy.terrain.heights;var heights=model.terrain.heights
	var outside_unchanged=true;var inside_raised=true
	for z in model.terrain.width:
		for x in model.terrain.width:
			var p=Vector2(x,z)*model.terrain.spacing-Vector2.ONE*240*model.terrain_scale
			var at=z*model.terrain.width+x
			if maxf(absf(p.x),absf(p.y))<Layout.CASTLE_HALF_SIZE:inside_raised=inside_raised and is_equal_approx(heights[at],Layout.CASTLE_HEIGHT)
			elif Layout.castle_height(p)==0:outside_unchanged=outside_unchanged and heights[at]==old_heights[at]
	check(inside_raised,size_+" complete enlarged interior is level at 41.6 m")
	check(outside_unchanged,size_+" valley heights outside the castle and stair footprints are preserved")
	for b in model.buildings.values():
		check(is_equal_approx(model.center(b).y,(0.0 if b.kind in ["wall","gate"] else Layout.CASTLE_HEIGHT)),size_+" structure keeps its intended foundation: "+b.kind)
	var field=Runtime.navigation_data(model)
	check(field.heights==heights and field.pieces.is_empty(),size_+" native armies share the prepared field without another terrain owner")
	for i in 4:
		var normal:Vector2=Layout.CASTLE_DIRECTIONS[i];var gate:Vector2=Layout.CASTLE_GATES[i]
		for distance in [48,60,78,96,114,132,150,168,180]:
			var p=gate+normal*(distance*Layout.CASTLE_SCALE-Layout.CASTLE_HALF_SIZE);var point=Vector3(p.x,model.surface_height(p.x,p.y),p.y)
			check(model.waves.navigation.move_clear(point,1.5),size_+" stair %d supports ordinary enemies at %d m"%[i,distance])
			check(model.terrain.disk_clear(model.point(model.cell_of(point)),8.5),size_+" stair %d supports the giant's unchanged ground footprint at %d m"%[i,distance])
		var bottom=gate+normal*132*Layout.CASTLE_SCALE;var inside=gate-normal*18*Layout.CASTLE_SCALE
		check(not model.route(model.cell_of(Vector3(bottom.x,0,bottom.y)),model.cell_of(Vector3(inside.x,Layout.CASTLE_HEIGHT,inside.y))).is_empty(),size_+" workers have a complete stair route on side %d"%i)
	check(not model.terrain.step_clear(Vector3(36,32,42)*Layout.CASTLE_SCALE,Vector3(36,0,54)*Layout.CASTLE_SCALE),size_+" the wall beside the stairs remains too steep to climb")
	for i in field.ray_owner.size():
		if model.buildings.get(field.ray_owner[i],{}).get("kind","")=="wall":check(field.ray_min[i].y==0 and field.ray_max[i].y==32,size_+" stair landings do not lift native wall obstacles above the real masonry")
	model.waves.navigation.terrain_corridors._refresh(model)
	check(model.waves.navigation.terrain_corridors.native_sampler!=null,size_+" native corridor acceleration remains enabled")
	var runtime=Runtime.new();runtime.configure(null);runtime.set_navigation(1,field)
	var handle=runtime.spawn(1000,0,0,Vector3(0,Layout.CASTLE_HEIGHT,18),100,1.3)
	for i in 240:
		runtime.step(1.0/60,{"goal_handles":PackedInt64Array([handle]),"goal_positions":PackedVector3Array([Vector3(12,Layout.CASTLE_HEIGHT,18)]),"goal_speeds":PackedFloat32Array([6])})
	var state=runtime.unit_state(handle)
	check(state.has("position") and state.position.distance_to(Vector3(12,Layout.CASTLE_HEIGHT,18))<.5,size_+" actual native soldier walks on the lifted floor")
	runtime.clear();runtime.free()
	var saved=Document.new(false);saved.capture(model)
	var restored=Document.new(false)
	check(restored.decode(saved.encode()).is_empty() and restored.data.get("raised_castle",false),size_+" editor round trip retains the lift")
	var invalid=doc.data.duplicate(true);invalid.raised_castle="yes"
	check(not Document.validate(invalid).is_empty(),size_+" map input rejects invalid elevation flags")
	set_meta("forest_custom_layout",doc.data.duplicate(true));set_meta("forest_painterly_preview",true)
	var game=load("res://scenes/forest_shrine.tscn").instantiate()
	var cfg="user://raised-castle-%d.cfg"%OS.get_process_id();game.settings_path=cfg
	root.add_child(game);current_scene=game
	for i in 8:await process_frame
	game.set_process(false);game.set_physics_process(false);game.camera_rig.set_process(false);game.explorer_helpers.set_process(false);game.music.stop()
	game.set_process_input(false);game.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
	check(absf(game.player.position.y-Layout.CASTLE_HEIGHT)<.3,size_+" actual player spawns on the courtyard")
	game.player.set_physics_process(false)
	for b in game.model.buildings.values():
		if b.kind!="gate":continue
		var door=game.world.structure_nodes[b.id].get_node("GateDoor")
		check(not door.visible and door.get_node("GateDoorCollider").collision_layer==0,size_+" door panel and collider are disabled")
		check(not game.model.close_repaired_gate(b.id) and b.breached,size_+" worker repairs cannot restore the removed door")
	await physics_frame;await physics_frame
	for p in [Vector3(0,0,18),Vector3(-18,0,-18),Vector3(18,0,18)]:
		var ray=PhysicsRayQueryParameters3D.create(p+Vector3.UP*(Layout.CASTLE_HEIGHT+8),p+Vector3.UP*(Layout.CASTLE_HEIGHT-8),1)
		var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and absf(hit.position.y-Layout.CASTLE_HEIGHT)<.01,size_+" physical floor matches model and native heights at "+str(p))
	var native=game.army_runtime
	check(native!=null and native.native!=null,size_+" real game still uses the native army runtime")
	await native_stair_assault(game,size_)
	await native_stair_assault(game,size_,true)
	await player_stairs(game,size_)
	if size_=="standard":
		check(game.resize_preparation_map(1),"Map expansion accepts the lifted castle")
		check(is_equal_approx(game.model.surface_height(0,18),Layout.CASTLE_HEIGHT) and game.model.raised_castle,"Map expansion preserves courtyard elevation")
		check(game.resize_preparation_map(-1),"Map can shrink to its original size with the lift retained")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1280,800);root.title="Goemon Raised Castle"
		game.ui.hide();game.forest_ui.hide()
		var camera=Camera3D.new();game.add_child(camera);camera.current=true
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=330
		camera.position=Vector3(180,230,260);camera.look_at(Vector3(0,12,0))
		DisplayServer.window_move_to_foreground()
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT+size_+"-castle.png")==OK,size_+" rendered castle capture")
	game.sound_library.cancel();game.queue_free();paused=false
	for i in 4:await process_frame
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))

func native_stair_assault(game,size_:String,off_axis:bool=false):
	var model=game.model;var army=game.army_runtime;var ids=[];var climbed={};var entered={};var hits={}
	model.phase="wave";army.set_process(false);army.record_events=true
	army.set_navigation(model.navigation_revision,Runtime.navigation_data(model))
	var targets:Dictionary=army.external_targets()
	for i in targets.ids.size():targets.targetable[i]=1 if targets.kinds[i]==2 and (off_axis or targets.ids[i]==model.shrine().id) else 0
	army.native.set_targets(targets)
	if off_axis:
		for p in [Vector2(138,66),Vector2(216,-288),Vector2(210,-294),Vector2(-330,144)]:
			var e=model.waves.spawn_enemy(9 if p.x<0 else 0,Vector3(p.x,model.surface_height(p.x,p.y),p.y))
			ids.append(e.id)
	else:
		for side in 4:
			var normal:Vector2=Layout.CASTLE_DIRECTIONS[side];var lateral=Vector2(-normal.y,normal.x)
			for index in Roles.WAVE_TYPES.size():
				var p=Layout.CASTLE_GATES[side]+normal*132*Layout.CASTLE_SCALE+lateral*(index*4-10)
				var e=model.waves.spawn_enemy(Roles.WAVE_TYPES[index],Vector3(p.x,model.surface_height(p.x,p.y),p.y))
				ids.append(e.id)
	army.import_arrivals()
	var supported=true;var step_times=[]
	for tick in 5000:
		var started=Time.get_ticks_usec();army.step(.05,{});step_times.append((Time.get_ticks_usec()-started)/1000.0)
		for event in army.take_events():
			if event.kind=="external_damage" and ids.has(event.source_id):hits[event.source_id]=event.target_id
		var snapshot=army.snapshot()
		for at in snapshot.logical_ids.size():
			var id=int(snapshot.logical_ids[at])
			if not ids.has(id):continue
			var p:Vector3=snapshot.positions[at]
			supported=supported and absf(p.y-model.surface_height(p.x,p.z))<.002
			if p.y>5 and p.y<Layout.CASTLE_HEIGHT-2 and maxf(absf(p.x),absf(p.z))>Layout.CASTLE_HALF_SIZE:climbed[id]=true
			if maxf(absf(p.x),absf(p.z))<Layout.CASTLE_HALF_SIZE-1 and p.y>Layout.CASTLE_HEIGHT-.1:entered[id]=true
		if tick%100==0:
			game.crowd.army.present(army.render_snapshot(),[]);await process_frame
		if hits.size()==ids.size():break
	check(supported,size_+" all native attackers stay on the shared physical stair surface")
	for id in ids:
		check(climbed.has(id) and entered.has(id) and hits.has(id) and (off_axis or hits[id]==model.shrine().id),size_+" ordinary enemy %d climbs, enters and damages a real castle target without manual goals"%id)
		if not hits.has(id):print("STAIR_ASSAULT_FAILURE id=",id," state=",army.unit_state(army.handles[id]))
	step_times.sort()
	print("STAIR_ASSAULT_DIAGNOSTIC map=",size_," off_axis=",off_axis," enemies=",ids.size()," entered=",entered.size()," attackers=",hits.size()," step_p95_ms=",step_times[int(step_times.size()*.95)])
	for id in ids:army.despawn(army.handles[id])
	army.sync_compatibility();game.crowd.army.present(army.render_snapshot(),[])
	model.phase="preparing"

func player_stairs(game,size_:String):
	var driver=preload("res://tests/forest-shrine/physics_step_driver.gd").new();driver.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(driver)
	var old_rate=Engine.physics_ticks_per_second;var old_scale=Engine.time_scale
	Engine.physics_ticks_per_second=600;Engine.time_scale=10
	game.paused=false;paused=false
	var player=game.player;player.set_auto_attack(false);player.ai_controlled=true;game.tuning.invincible=true
	for side in 4:
		var normal:Vector2=Layout.CASTLE_DIRECTIONS[side];var gate:Vector2=Layout.CASTLE_GATES[side]
		var p=gate+normal*126*Layout.CASTLE_SCALE;player.position=Vector3(p.x,game.model.surface_height(p.x,p.y)+.15,p.y);player.velocity=Vector3.ZERO
		player.ai_move=Vector3(-normal.x,0,-normal.y)
		await driver.advance(1800,func(delta):
			if Vector2(player.position.x,player.position.z).dot(normal)<31:player.ai_move=Vector3.ZERO
			player._physics_process(delta))
		player.ai_move=Vector3.ZERO
		check(maxf(absf(player.position.x),absf(player.position.z))<43 and absf(player.position.y-Layout.CASTLE_HEIGHT)<.3,size_+" actual player walks up side %d without jumping"%side)
		print("STAIR_PLAYER_CHECK map=",size_," side=",side," position=",player.position)
		if player.position.y<Layout.CASTLE_HEIGHT-1:print("STAIR_PLAYER_FAILURE side=",side," position=",player.position)
	player.position=game.model.point(game.PLAYER_SPAWN_CELL)+Vector3.UP*.15;player.velocity=Vector3.ZERO
	player.ai_controlled=false
	game.paused=true;paused=true
	Engine.physics_ticks_per_second=old_rate;Engine.time_scale=old_scale;driver.queue_free()
