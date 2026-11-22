extends RefCounted
## Disposable layout; deliberately separate from saved maps and the normal campaign.
static func layout()->Dictionary:
	var roads={}
	for end in [Vector2i(-19,14),Vector2i(19,14),Vector2i(0,33)]:
		for step in range(0,101):
			var p=Vector2(Vector2i(0,8)).lerp(Vector2(end),step/100.0)
			for dx in range(-2,3):
				for dz in range(-2,3):roads[Vector2i(roundi(p.x)+dx,roundi(p.y)+dz)]=true
	var tiles=[]
	for cell in roads:tiles.append({"x":cell.x,"z":cell.y})
	return {"format":"forest_shrine_map","schema":1,"title":"Enemy Camps Prototype","enemy_camps_prototype":true,
		"buildings":[{"kind":"tower","x":-5,"z":5,"rotation":0},{"kind":"tower","x":4,"z":5,"rotation":0}],
		"trees":[],"deposits":[],"roads":tiles,"ramparts":[],
		"portals":[{"x":-19,"z":14,"rotation":1},{"x":19,"z":14,"rotation":3},{"x":0,"z":24,"rotation":0}]}

static func obstacles(model:RefCounted)->Array:
	if not model.has_enemy_camps() or not model.falan_road.is_empty():return []
	if model.camp_obstacle_revision==model.navigation_revision:return model.camp_obstacles
	model.camp_obstacle_revision=model.navigation_revision;model.camp_obstacles=[]
	var boxes:Array=model.camp_obstacles
	for camp in model.portals:
		if camp.hp<=0:continue
		var origin:Vector3=model.point(Vector2i(camp.x,camp.z))
		if camp.get("castle",false):
			for box:AABB in preload("res://scripts/forest/forest_enemy_castle.gd").statue_boxes(camp):boxes.append(AABB(box.position+origin,box.size))
			for box:AABB in preload("res://scripts/forest/forest_enemy_castle.gd").boxes(camp):boxes.append(AABB(box.position+origin,box.size))
		else:boxes.append(AABB(origin+Vector3(-8.5,0,-8.5),Vector3(17,6,17)))
	if not model.enemy_camps_prototype:return boxes
	if model.enemy_statue.hp>0:boxes.append(AABB(Vector3(-8.5,0,189.5),Vector3(17,6,17)))
	for x in [-30,30]:
		boxes.append(AABB(Vector3(x-1.5,0,171),Vector3(3,16,54)))
		boxes.append(AABB(Vector3(x-5,0,166),Vector3(10,16,10)))
	boxes.append(AABB(Vector3(-27,0,223.5),Vector3(54,16,3)))
	return boxes

static func build(world:Node3D):
	var game=world.get_parent();game.enemy_objectives.clear();game.enemy_objective_targets.clear()
	for index in range(world.model.portals.size()):
		world.add_enemy_castle(index)
	if not world.model.enemy_camps_prototype:return
	var statue=preload("res://scripts/forest/forest_enemy_objective.gd").new()
	statue.game=game;statue.objective_index=-1;statue.position=Vector3(0,0,198)
	world.map_features.add_child(statue);game.enemy_objectives.append(statue)
	# An open courtyard keeps the prototype objective reachable with every fighter.
	var stone=preload("res://scripts/forest/forest_stone_fort.gd")
	for spec in [[Vector3(-30,0,198),PI*.5],[Vector3(30,0,198),PI*.5],[Vector3(0,0,225),0.0]]:
		var wall=Node3D.new();world.map_features.add_child(wall);wall.position=spec[0];wall.rotation.y=spec[1]
		stone.wall(wall,54,0);preload("res://scripts/forest/forest_art.gd").solid(wall,Vector3(0,8,0),Vector3(54,16,3))
	for x in [-30,30]:
		var tower=Node3D.new();world.map_features.add_child(tower);tower.position=Vector3(x,0,171);stone.tower(tower)
		preload("res://scripts/forest/forest_art.gd").solid(tower,Vector3(0,8,0),Vector3(10,16,10))
