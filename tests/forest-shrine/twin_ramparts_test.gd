extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const PRESET="res://assets/maps/forest_twin_ramparts.json"
var checks=0
var failures=0
var folder="user://twin-ramparts-%d"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Raised walls timeout");quit(1))
 run.call_deferred()
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func run():
 check(FileAccess.file_exists(PRESET),"The new two-wall layout is bundled and playable")
 if not FileAccess.file_exists(PRESET):quit(1);return
 var original=FileAccess.get_file_as_string(Document.ORIGINAL_PATH)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PRESET))
 check(Document.validate(data).is_empty(),"The new preset passes map validation: "+Document.validate(data))
 var doc=Document.new();check(doc.load_ramparts().is_empty() and doc.play_error().is_empty(),"All portals have a playable giant route to the base")
 var m=Model.new();m.reset(42,{},data)
 check(m.portals.size()==2 and m.ramparts.size()==5,"Two wall routes have two real portal spawn origins")
 check(m.surface_height(-96,198)==18 and m.surface_height(96,198)==18 and m.surface_height(0,138)==18,"Both routes meet at one elevated junction")
 check(is_equal_approx(m.surface_height(0,84),9) and m.surface_height(0,18)==0,"Continuous ramp descends to the original base height")
 check(doc.save(folder).is_empty(),"Raised terrain saves with the edited map")
 var restored=Document.new();check(restored.read_file(doc.path).is_empty() and restored.encode()==doc.encode(),"Wall height, end caps, portals and roads survive disk reload")
 var before=restored.encode()
 for change in [{"width":2},{"h0":-1},{"h1":100},{"ax":"bad"},{"cap_start":3},{"az":-1,"bz":0,"h0":18,"h1":18}]:
  var broken=data.duplicate(true);broken.ramparts[0].merge(change,true)
  check(not restored.decode(JSON.stringify(broken)).is_empty() and restored.encode()==before,"Invalid/protected raised terrain is rejected without replacing the map: "+str(change))
 check(not doc.placement_error("wall",Vector2i(0,9),0).is_empty(),"Editor reserves the zero-height ramp entrance, including its whole footprint")
 check(not m.placement_error("wall",Vector2i(0,9),0).is_empty(),"Building view cannot block the ramp entrance with a new wall")
 check(not doc.place("tower",Vector2i(0,20),0).is_empty(),"Construction keeps the fixed wall route clear")
 var legacy=Document.new();check(legacy.load_original().is_empty(),"Original Map remains loadable")
 var flat=Model.new();flat.reset(42,{},legacy.data)
 check(flat.ramparts.is_empty() and flat.point(Vector2i(16,30)).y==0,"Original Map retains its flat terrain and edge arrivals")
 # Exercise actual path steering and movement on both branches, not only saved waypoints.
 for portal_index in 2:
  for variant in 4:
   m=Model.new();m.reset(42,{},data);m.start_wave()
   var point=m.waves.routes.exit_point(m.portals[portal_index],variant);point.y=m.surface_height(point.x,point.z)
   var e=m.waves.spawn_enemy(variant,point);e.road_path=m.waves.routes.guidance(point,variant)
   var supported=true;var traversed_junction=false
   for step in 3400:
    var previous: Vector3=e.pos;m.waves.tick_enemy(e,.2,Vector3(0,0,18))
    if absf(e.pos.x)<12 and e.pos.z>120:traversed_junction=true
    supported=supported and absf(e.pos.y-m.surface_height(e.pos.x,e.pos.z))<.001 and m.terrain.step_clear(previous,e.pos)
    if e.pos.z<68:break
   check(traversed_junction and e.pos.z<68 and e.pos.y<5,"Enemy role %d follows wall %d through the junction and down the ramp"%[variant,portal_index+1])
   check(supported,"Enemy role %d stays on the physical wall surface throughout route %d"%[variant,portal_index+1])
 # Real scheduled arrivals retain counts and use both visible portals.
 m=Model.new();m.reset(42,{"waves":[[8,4,2,8]]},data);m.start_wave()
 var counts=[0,0,0,0];var used={};var raised=true
 for attempt in 20:
  m.waves.spawn_batch()
  for e in m.enemies.values():counts[e.variant]+=1;used[e.portal_index]=true;raised=raised and e.pos.y==18 and not e.road_path.is_empty()
  m.enemies.clear()
  if m.waves.pending==0:break
 check(counts==[8,4,2,8] and m.waves.pending==0 and used.size()==2 and raised,"Both portals spawn the exact scheduled wave composition on their wall tops")
 m=Model.new();m.reset(42,{"waves":[[3,0,0,0]]},data);m.start_wave();m.hero_position=Vector3(-96,18,198)
 check(m.waves.spawn_one() and m.enemies.values()[0].pos.distance_to(m.hero_position)>2,"Portal spawns avoid a hero standing at the raised exit")
 var e=m.waves.spawn_enemy(0,Vector3(-108,18,180));m.waves.swept_move(e,Vector3.LEFT*40)
 check(e.pos.y==18 and e.pos.x> -111,"Lateral knockback cannot throw an enemy through the wall edge")
 e=m.waves.spawn_enemy(0,Vector3(-120,0,180));m.waves.swept_move(e,Vector3.RIGHT*30)
 check(e.pos.y==0 and e.pos.x< -111,"An enemy below the wall cannot teleport up its vertical side")
 e=m.waves.spawn_enemy(0,Vector3(-96,18,180))
 check(not m.waves.in_reach(e,"hero",0,Vector3(-96,0,180)),"Melee cannot hit a hero eighteen metres below the wall")
 check(not m.waves.navigation.line_clear(Vector3(-120,2,180),Vector3(-90,2,180)),"The stone wall blocks line of sight through its body")
 check(FileAccess.get_file_as_string(Document.ORIGINAL_PATH)==original and original.sha256_text()=="cb6ec88c3157e05fc64341511ba783df486be35f870565b8df4d8b0736b82948","Original Map remains byte-for-byte unchanged")
 for name_ in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name_)))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
 print("TWIN_RAMPARTS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
