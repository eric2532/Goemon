extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
var folder="user://forest-lanes-%d"%OS.get_process_id()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():run.call_deferred()
func blank()->Dictionary:return {"format":"forest_shrine_map","schema":1,"title":"Portal Valley","buildings":[],"trees":[],"deposits":[]}
func run():
	if not ResourceLoader.exists("res://scripts/forest/forest_routes.gd"):
		check(false,"Authored portals and roads drive enemy arrivals");finish();return
	var Routes=load("res://scripts/forest/forest_routes.gd")
	var original=FileAccess.get_file_as_string(Document.ORIGINAL_PATH)
	var doc=Document.new();check(doc.decode(JSON.stringify(blank())).is_empty(),"Legacy schema1 maps still load without new fields")
	check(doc.place("portal",Vector2i(0,20),0).is_empty(),"Editor can place an enemy portal")
	var selected=doc.object_at(Vector2i(1,21))
	check(selected.get("group")=="portals","Selecting the portal arch footprint finds its anchor")
	check(doc.rotate(selected).is_empty(),"Portal rotates clockwise")
	check(Routes.exit_point(doc.data.portals[0],0)==Vector3(6,0,120),"Rotation points the portal exit east")
	for i in range(3):doc.rotate(selected)
	check(not doc.place("tree",Vector2i(0,17),0).is_empty(),"Portal exit stays clear of trees")
	check(not doc.place("portal",Vector2i(0,0),0).is_empty(),"Portals cannot cover the base or protected starts")
	check(doc.place("tree",Vector2i(6,15),0).is_empty(),"Road clearing fixture starts with a tree")
	var stroke=[]
	for x in range(0,7):stroke.append(Vector2i(x,17))
	for z in range(16,8,-1):stroke.append(Vector2i(6,z))
	for x in range(5,-1,-1):stroke.append(Vector2i(x,9))
	check(doc.paint_road(stroke,5).is_empty(),"One drag paints a connected wide curved road")
	check(doc.data.roads.size()>100 and doc.object_at(Vector2i(6,15)).get("group")=="roads","Road painting clears trees in its footprint")
	check(doc.undo() and doc.data.roads.is_empty() and doc.object_at(Vector2i(6,15)).get("group")=="trees","One undo restores the whole stroke and its trees")
	check(doc.redo() and not doc.data.roads.is_empty(),"Redo restores the complete road stroke")
	check(doc.play_error().is_empty(),"Wide portal approach is playable by all enemy sizes")
	check(doc.save(folder).is_empty(),"Portals and roads save with the map")
	var restored=Document.new();check(restored.read_file(doc.path).is_empty() and restored.encode()==doc.encode(),"Portal facing and every road tile survive disk reload")
	var before=doc.encode();var invalid=doc.data.duplicate(true);invalid.portals[0].rotation=9
	check(not doc.decode(JSON.stringify(invalid)).is_empty() and doc.encode()==before,"Invalid portal rotation cannot mutate open map")
	invalid=doc.data.duplicate(true);invalid.roads.append({"x":999,"z":0})
	check(not doc.decode(JSON.stringify(invalid)).is_empty(),"Out-of-bounds road files are rejected")
	var m=Model.new();m.reset(42,{"waves":[[2,1,1,2]]},restored.data)
	m.start_wave();m.visible_cells.clear()
	for x in range(-40,40):
		for z in range(-40,40):m.visible_cells[Vector2i(x,z)]=true
	check(m.waves.spawn_one(),"Visible authored portals still release a scheduled enemy")
	var giant=m.enemies.values()[0]
	check(giant.variant==2 and giant.pos==Vector3(0,0,102),"Giant exits the authored portal with full clearance")
	check(giant.get("portal_index")==0 and not giant.get("road_path",[]).is_empty(),"Portal spawn receives its connected road")
	var count=[0,0,1,0];m.enemies.clear()
	for attempt in range(20):
		m.waves.spawn_batch()
		for e in m.enemies.values():count[e.variant]+=1
		m.enemies.clear()
		if m.waves.pending==0:break
	check(count==[2,1,1,2] and m.waves.pending==0,"Portals retain exact wave composition and pending accounting")
	m=Model.new();m.reset(42,{"waves":[[3,0,0,0]]},restored.data);m.start_wave();m.waves.spawn_one()
	var e=m.enemies.values()[0];var start: Vector3=e.pos
	for i in range(480):m.waves.tick_enemy(e,1.0/60,Vector3(0,0,18))
	check(e.pos.x>18 and e.pos.z>78,"A curved road guides raiders around the bend instead of cutting straight to the base")
	var road_left=e.road_path.size();var hero=e.pos+Vector3(0,0,-12);start=e.pos
	for i in range(30):m.waves.tick_enemy(e,1.0/60,hero)
	check(e.pos.z<start.z-1 and e.road_path.size()==road_left,"Nearby combat can interrupt road marching without losing its remaining route")
	for i in range(60):m.waves.tick_enemy(e,1.0/60,Vector3(0,0,18))
	check(e.velocity.length()>0,"Enemies resume forward travel when nearby combat moves away")
	var rejoin_map=restored.data.duplicate(true);rejoin_map.trees.append({"x":2,"z":13,"scale":1.0})
	var rejoin=Model.new();rejoin.reset(42,{},rejoin_map);rejoin.start_wave()
	var returning=rejoin.waves.spawn_enemy(0,Vector3(6,0,78));returning.road_path=[Vector2i(4,13),Vector2i(4,12),Vector2i(4,11)]
	for i in range(360):rejoin.waves.tick_enemy(returning,1.0/60,Vector3(0,0,18))
	check(returning.pos.x>=23 and returning.pos.z<77,"Returning from combat navigates around trees to rejoin the road")
	var second=restored.data.duplicate(true);second.portals.append({"x":14,"z":20,"rotation":0})
	m=Model.new();m.reset(42,{"waves":[[6,0,0,0]]},second);m.start_wave();m.waves.spawn_batch()
	check(m.enemies.size()==3 and m.enemies.values().any(func(actor):return actor.portal_index==1),"Multiple portals share a normal three-enemy batch")
	var occupied_model=Model.new();occupied_model.reset(42,{"waves":[[2,0,0,0]]},restored.data);occupied_model.start_wave()
	occupied_model.hero_position=Vector3(0,0,114);occupied_model.waves.spawn_one()
	check(occupied_model.enemies.values()[0].pos.distance_to(occupied_model.hero_position)>=2,"Portal arrivals never overlap a hero standing at the exit")
	var wall_map=restored.data.duplicate(true);wall_map.buildings.append({"kind":"wall","x":3,"z":13,"rotation":0,"span":6})
	var blocked=Model.new();blocked.reset(42,{},wall_map);blocked.start_wave()
	var runner=blocked.waves.spawn_enemy(3,Vector3(24,0,84));runner.road_path=[Vector2i(4,14),Vector2i(4,13),Vector2i(4,12)]
	var wall=blocked.buildings.values().filter(func(b):return b.kind=="wall")[0];var crossed=false
	for i in range(600):
		blocked.waves.tick_enemy(runner,1.0/60,Vector3(0,0,18))
		if blocked.buildings.has(wall.id) and runner.pos.z<75.7:crossed=true
	check(wall.hp<300 and not crossed,"A road wall blocks physical travel and is attacked instead of walked through")
	var occupied=m.waves.pending
	for portal in m.portals:
		for dx in range(-3,4):
			for dz in range(-3,4):m.trees[m.cell_of(Routes.exit_point(portal,0))+Vector2i(dx,dz)]=1.0
	m.rebuild_navigation();check(not m.waves.spawn_one() and m.waves.pending==occupied,"Blocked portals preserve pending arrivals")
	var narrow=Document.new();var narrow_data=blank();narrow_data.trees=[{"x":2,"z":12,"scale":1.0}];narrow.decode(JSON.stringify(narrow_data));narrow.place("portal",Vector2i(0,20),0)
	var straight=[]
	for z in range(9,20):straight.append(Vector2i(0,z))
	narrow.paint_road(straight,1)
	check(not narrow.play_error().is_empty(),"Play rejects road corridors too narrow for a scheduled giant")
	check(FileAccess.get_file_as_string(Document.ORIGINAL_PATH)==original,"Original Map snapshot stays byte-for-byte unchanged")
	finish()
func finish():
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("FOREST_PORTALS_ROADS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
