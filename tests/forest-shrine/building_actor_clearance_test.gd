extends SceneTree
## Construction moves nearby occupants only after a successful whole purchase.
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: building actor clearance timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func clear_ground(m,point:Vector3)->bool:
 return not m.occupancy.has(m.cell_of(point)) and not m.allied_grid.is_point_solid(m.cell_of(point)) and m.terrain.disk_clear(point,.55)
func frames():
 for i in 3:await process_frame
func run():
 var m=Model.new();m.reset(42,{}, {"trees":[],"deposits":[],"buildings":[]},false)
 var worker:Dictionary=m.workers.values()[0];worker.pos=Vector3(30,0,60);worker.path=[Vector2i(5,10)]
 worker.exit_start=Vector3(30,0,54);worker.exit_point=worker.pos;worker.deck_height=4.0
 var origin:Vector3=worker.pos;var gold:int=m.gold;var count:int=m.buildings.size()
 var rejected=m.build_wall_line([Vector2i(5,10),Vector2i(-1,-1)],0)
 check(rejected.is_empty() and worker.pos==origin and m.gold==gold and m.buildings.size()==count,"A failed wall transaction leaves workers, buildings and gold untouched")
 var line=m.build_wall_line([Vector2i(5,10),Vector2i(11,10)],0)
 check(line.size()==2 and clear_ground(m,worker.pos) and worker.pos.distance_to(origin)<12,"A committed wall line moves a covered worker to nearby open ground")
 check(worker.path.is_empty(),"Moving a worker clears its stale route through the new wall")
 check(not worker.has("exit_point") and not worker.has("exit_start") and is_zero_approx(worker.get("deck_height",0.0)),"A moved worker cannot resume a stale tower descent into the new building")
 var descent=Model.new();descent.reset(42,{}, {"trees":[],"deposits":[],"buildings":[]},false)
 var old_tower:Dictionary=descent._make_building("tower",Vector2i(3,8),0);descent.rebuild_navigation()
 var descending:Dictionary=descent.workers.values()[0];descending.pos=descent.center(old_tower);descending.job=old_tower.id;descending.state="garrison"
 descent.workforce.release_job(descending)
 check(not descent.build("tower",Vector2i(3,10),0).is_empty(),"Construction can cover an outgoing tower worker's former entrance")
 descent.workforce.assignment_clock=1000;descent.workforce.prepare_tick(4)
 check(clear_ground(descent,descending.pos) and not descending.has("exit_point") and is_zero_approx(descending.get("deck_height",0.0)),"A queued tower exit covered by construction cannot carry the worker into the new tower")
 var corner=Model.new();corner.reset(42,{}, {"trees":[],"deposits":[],"buildings":[]},false)
 corner._make_building("wall",Vector2i(9,9),0,1);corner.rebuild_navigation()
 var corner_worker:Dictionary=corner.workers.values()[0];corner_worker.pos=Vector3(57.1,0,57.1)
 check(not corner.build("tower",Vector2i(10,10),0).is_empty(),"The corner-clearance fixture builds beside an existing short wall")
 var flat=Vector2(corner_worker.pos.x,corner_worker.pos.z)
 check(flat.distance_to(flat.clamp(Vector2(51,51),Vector2(57,57)))>=.65,"A relocated worker's full body clears a diagonally adjacent existing wall")
 for backend in ["legacy","native"]:
  set_meta("forest_army_backend",backend)
  var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original()
  doc.data.buildings.append({"kind":"tower","x":0,"z":3,"rotation":0})
  set_meta("forest_custom_layout",doc.data)
  var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://building-actors-%d.cfg"%OS.get_process_id();root.add_child(game)
  await frames();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
  m=game.model;m.gold=10000
  check(clear_ground(m,game.player.position) and m.hero_position==game.player.position,backend+" a fresh saved-map scene spawns outside a building covering the original hero start")
  var cell=Vector2i(-999,-999)
  for z in range(6,17):
   for x in range(5,17):
    if m.placement_error("tower",Vector2i(x,z),0).is_empty():cell=Vector2i(x,z);break
   if cell.x!=-999:break
  check(cell.x!=-999,backend+" has an open construction fixture")
  if cell.x==-999:game.queue_free();paused=false;await frames();continue
  var point:Vector3=m.point(cell)
  game.player.position=point+Vector3.UP*.15;m.hero_position=game.player.position
  worker=m.workers.values()[0];worker.pos=point+Vector3(1,0,1);worker.state="idle";worker.job=-1
  var gate=game.gate_defenders.units.values()[0];gate.position=point+Vector3(-1,.15,1);gate.post=gate.position-Vector3.UP*.15
  var unit=game.explorer_helpers.pool[0];unit.summon(null,point+Vector3(2,.12,2),0)
  game.gate_defenders.sync_model();game.explorer_helpers.sync_targets()
  var before=[game.player.position,worker.pos,gate.position,gate.post,unit.position,unit.guard_post]
  game.select_build("tower");var target=game.build_placement_target(cell)
  check(target.error.is_empty() and target.cell==cell,backend+" occupants do not shift a clear-ground building preview")
  check(before==[game.player.position,worker.pos,gate.position,gate.post,unit.position,unit.guard_post],backend+" preview never moves occupants or posts")
  gold=m.gold;count=m.buildings.size()
  check(game.place_cell(cell),backend+" construction succeeds over standing allied occupants")
  check(m.gold==gold-120 and m.buildings.size()==count+1,backend+" construction charges once")
  for row in [["hero",game.player.position],["worker",worker.pos],["gate defender",gate.position],["gate post",gate.post],["helper",unit.position],["helper post",unit.guard_post]]:
   check(clear_ground(m,row[1]) and row[1].distance_to(point)<20,backend+" "+row[0]+" clears the new structure without a distant teleport")
  check(m.hero_position==game.player.position,backend+" the hero model mirror follows its actual position")
  check(m.fighter_posts[unit.gate_id]==unit.guard_post and m.defenders[unit.gate_id].pos==unit.position,backend+" helper target and guard-post mirrors agree after relocation")
  if backend=="native":
   var data:Dictionary=game.army_runtime.unit_state(unit.handle)
   check(data.position==unit.position, "Native authoritative state retains the relocated helper position")
   game.army_runtime.preparation_tick(.1)
   check(clear_ground(m,unit.position),"The next native preparation tick keeps the helper clear")
  var settled=[game.player.position,worker.pos,gate.position,gate.post,unit.position,unit.guard_post]
  game.select_build("tower");m.gold=0
  check(not game.place_cell(cell+Vector2i(3,0)) and m.gold==0 and settled==[game.player.position,worker.pos,gate.position,gate.post,unit.position,unit.guard_post],backend+" a rejected purchase never moves actors or guard posts")
  game.player.position=Vector3(0,.15,18)
  game.preview_forest_map(doc.data,false);m=game.model;m.gold=10000
  check(clear_ground(m,game.player.position) and m.hero_position==game.player.position,backend+" playing an edited map moves a blocked original hero start onto clear ground")
  game.player.position=m.point(cell)+Vector3.UP*.15;m.hero_position=game.player.position
  var direct=m.build("tower",cell,0)
  check(not direct.is_empty() and clear_ground(m,game.player.position) and m.hero_position==game.player.position,backend+" direct model construction still moves the actual hero after loading a different map")
  var cfg:String=game.settings_path
  for voice in game.placement_audio.voices:voice.stop()
  game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
  if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 await create_timer(.25).timeout
 print("BUILDING_ACTOR_CLEARANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
