extends SceneTree
var game
var report={}
var failures=0
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.smoke_test=true;game.start_game();game.encounters.set_physics_process(false)
	game.player.smoke_mode=true;game.player.set_physics_process(false);game.tuning.freeze_ai=true
	var old_distances={};var old_points={};var old_fields={}
	var views=[Vector2(0,41),Vector2(-2,20),Vector2(-2,1),Vector2(47.5,33),Vector2(-52,34),Vector2(-10,-18),Vector2(45,-40)]
	for phase in ["before","after"]:
		game.world.free()
		game.world=load("res://tests/tidefall-town/baseline/world.gd").new() if phase=="before" else Sanctuary.new()
		game.world.generation_seed=90824;game.add_child(game.world)
		WorldExpansion.walls(game.world,Geo.mat("405d68"));game.world.set_process(false)
		await physics_frame
		game.pursuit.configure();game.pursuit.refresh_field(Vector3(0,game.world.height_at(0,41)+.2,41))
		while game.pursuit.building:game.pursuit.advance_build(10000000)
		var field=game.pursuit.distances.duplicate()
		report[phase]={"reachable_cells":field.size(),"spawn_checks":[]}
		if phase=="before":
			old_distances=field
			for cell in field:old_points[cell]=game.pursuit.ground(cell)
		else:
			var removed=[];var disconnected=[];var outside_buildings=[];var max_detour=0
			for cell in old_distances:
				if field.has(cell):max_detour=maxi(max_detour,field[cell]-old_distances[cell]);continue
				var p=old_points[cell]
				removed.append([p.x,p.y,p.z])
				if game.pursuit.ground(cell)!=null:disconnected.append([p.x,p.y,p.z])
				var near=false
				for rect in game.world.get_node("TidefallTown").footprints:
					if rect.grow(1).has_point(Vector2(p.x,p.z)):near=true
				if not near:outside_buildings.append([p.x,p.y,p.z])
			report[phase].merge({"removed_cells":removed,"disconnected_walkable_cells":disconnected,"removed_outside_building_clearance":outside_buildings,"max_added_route_steps":max_detour})
		for v in views:
			game.player.position=Vector3(v.x,game.world.height_at(v.x,v.y)+.2,v.y)
			game.pursuit.configure();game.pursuit.refresh_field(game.player.position)
			while game.pursuit.building:game.pursuit.advance_build(10000000)
			game.encounters.spawn_rng.seed=90824
			var detours=[];var essential_distances={};var max_added_steps=0
			var field_now=game.pursuit.distances.duplicate()
			if phase=="before":old_fields[v]=field_now
			else:
				for cell in old_fields[v]:
					if field_now.has(cell):max_added_steps=maxi(max_added_steps,field_now[cell]-old_fields[v][cell])
					if field_now.has(cell) and field_now[cell]-old_fields[v][cell]>2:
						var p=game.pursuit.ground(cell)
						detours.append({"xz":[p.x,p.z],"extra_steps":field_now[cell]-old_fields[v][cell]})
			for destination in views:
				var cell=game.pursuit.cell_of(Vector3(destination.x,0,destination.y))
				essential_distances[str(destination)]=field_now.get(cell,-1)
			var accepted=0;var linked=0
			for i in range(100):
				game.encounters.total_spawned=i
				var p=game.encounters.wave_spawn_point()
				if p==null:continue
				accepted+=1
				var cell=game.pursuit.cell_of(p)
				if game.pursuit.clear_segment(p,game.player.position) or (game.pursuit.distances.has(cell) and game.pursuit.clear_segment(p,game.pursuit.ground(cell))):linked+=1
			report[phase].spawn_checks.append({"hero_xz":[v.x,v.y],"requested":100,"accepted":accepted,"connected_to_hero":linked,"essential_distance_steps":essential_distances,"detours_over_10m":detours,"max_added_route_steps":max_added_steps})
	check(report.after.disconnected_walkable_cells.is_empty(),"No previously reachable walkable navigation cells become isolated")
	check(report.after.removed_outside_building_clearance.is_empty(),"All removed navigation cells lie inside new building clearance")
	var short_routes=true;var destinations_exact=true;var spawn_routes=true
	for i in range(views.size()):
		var before=report.before.spawn_checks[i];var after=report.after.spawn_checks[i]
		short_routes=short_routes and after.max_added_route_steps<=2
		destinations_exact=destinations_exact and before.essential_distance_steps==after.essential_distance_steps
		spawn_routes=spawn_routes and before.connected_to_hero==100 and after.connected_to_hero==100
	check(short_routes,"No cached enemy route increases more than 10m across seven full navigation fields")
	check(destinations_exact,"All 49 pairs of principal destinations retain exact baseline route distances")
	check(spawn_routes,"All 700 before and 700 after sampled enemy spawns connect to the hero")
	report["failures"]=failures
	FileAccess.open("res://docs/tidefall-town/reachability.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TOWN_REACHABILITY_RESULT failures=",failures)
	if failures:quit(1)
	else:game.quit_clean()
