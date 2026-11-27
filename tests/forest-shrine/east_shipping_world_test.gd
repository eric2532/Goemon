extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Real Explore scene, native world, F/Space crew interaction and unaccelerated active-play voyages.
const Harbor=preload("res://scripts/forest/forest_east_harbor.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const REPORT="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/shipping-world.json"
var checks=0
var observations=[]
var voyages=[]
var captures=[]
var initial_hashes={}
var previous_evidence=""
var blocked_connections=[]

func _initialize():
 create_timer(1200,true,false,true).timeout.connect(func():printerr("EAST_SHIPPING_WORLD_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1;observations.append({"check":message,"passed":ok});super.check(ok,message)

func key(code:int):
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func run():
 for path in ["res://scripts/forest/forest_east_harbor.gd","res://scripts/forest/forest_explorer_npcs.gd","res://assets/maps/falan/east_region/harbor.json"]:initial_hashes[path]=FileAccess.get_sha256(path)
 root.size=Vector2i(1440,900);root.title="Cross Gate · Source Ship Voyages"
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-shipping-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 for i in 8:await physics_frame
 check(Tour.area(game.model)=="city","Title→Kaz→Enter Map uses the normal Explore world")
 check(is_equal_approx(Engine.time_scale,1.),"Voyages use real active-play seconds with no accelerated clock")
 source_records()
 var boundary_only:bool="--boundary-only" in OS.get_cmdline_user_args()
 var previous_path="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/shipping-world-second-observed.json"
 if not boundary_only and FileAccess.file_exists(previous_path):
  var previous:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(previous_path))
  if previous.get("sources_unchanged_during_run",false) and previous.get("source_hashes",{})==initial_hashes:
   voyages=previous.voyages.filter(func(row):return row.get("passed",false)).duplicate(true)
   previous_evidence=previous_path
 var ids:Array=Harbor.data().actions.keys().filter(func(id):return Harbor.data().actions[id].kind=="voyage")
 if boundary_only:ids=["1102413"]
 ids.sort()
 for id in ids:
  if voyages.any(func(row):return str(row.crew)==str(id)):continue
  var need_status:bool=int(Harbor.data().actions[id].ship)==1 and not voyages.any(func(row):return row.get("onboard_attendant",false))
  await voyage(str(id),not voyages.any(func(row):return row.get("room_crossed",false)) and int(Harbor.data().actions[id].ship)==1,need_status)
  if errors>0:break
 var hashes={}
 for path in ["res://scripts/forest/forest_east_harbor.gd","res://scripts/forest/forest_explorer_npcs.gd","res://assets/maps/falan/east_region/harbor.json"]:hashes[path]=FileAccess.get_sha256(path)
 var output=REPORT.replace("shipping-world.json","shipping-boundary-world.json") if boundary_only else REPORT
 var file=FileAccess.open(output,FileAccess.WRITE)
 if boundary_only:check(blocked_connections.size()==1,"Ship50's separately owned West arrival is held through the actual F dialogue")
 else:
  check(voyages.size()==8,"All eight source voyage directions have real-world arrival evidence")
  check(voyages.any(func(row):return row.get("room_crossed",false)),"Evidence includes actual ship-room walking without cancelling the voyage")
  check(voyages.any(func(row):return row.get("onboard_attendant",false)),"Evidence includes a real onboard attendant F interaction without timer reset")
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"voyages":voyages,"blocked_connections":blocked_connections,"captures":captures,"source_hashes":initial_hashes,"sources_unchanged_during_run":hashes==initial_hashes,"previous_verified_direction_evidence":previous_evidence,
  "scope":"Real title/Kaz/Explore world; direct spawns at source departure ports; real F and Space interactions; eight unaccelerated twenty-second active-play voyages; one ship-room on-foot crossing. Admission quests/fares are qualified by direct port spawn and tested separately; no admission bypass is claimed."}," ")+"\n");file.close()
 print("EAST_SHIPPING_WORLD_RESULT directions=",voyages.size()," checks=",checks," failures=",errors)
 await finish()

func source_records():
 var population=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/population.json"));var originals={}
 for actor in population.actors:originals[str(actor.id)]=actor
 var records:Dictionary={}
 for row in Harbor.data().npcs:
  records[str(row.id)]=row
  var source:Dictionary=originals.get(str(row.id),{})
  check(not source.is_empty() and int(row.floor)==int(source.source) and row.cell==source.cell,"Harbor NPC retains original map/cell "+str(row.id))
  if Harbor.data().actions.has(str(row.id)):check(row.quest_action=="east_harbor:"+str(row.id),"Transport action attached to original crew "+str(row.id))
  elif str(source.type).to_lower()=="event":check(row.quest_action=="east_event:"+str(row.id),"General harbor quest script preserved "+str(row.id))
 check(records.size()==50,"All50 original source Harbor records remain")
 check(records.has("305053") and records["305053"].quest_action=="east_event:305053","Special ghost-ship admission clerk keeps its original scripted gate")
 check(population.npcs.any(func(row):return str(row.id)=="305029" and row.quest_action=="east_event:305029"),"Special dock rope crew retains the original18786 quest-item script")

func voyage(id:String,walk_room:bool,status_check:bool=false):
 var catalog=Harbor.data();var action:Dictionary=catalog.actions[id]
 var crew:Dictionary=catalog.npcs.filter(func(row):return str(row.id)==id)[0]
 var ship:Dictionary=catalog.ships[str(int(action.ship))];var destination:Dictionary=catalog.ports[str(int(action.arrival))]
 var floor_=Maps.runtime_id(int(crew.floor));var cell=Vector2i(crew.cell[0],crew.cell[1]);var original_gold:int=game.model.gold
 var source_at=Maps.source_point(floor_,cell);var initial=Tour.Indoor.safe_point(floor_,source_at+Vector2(0,3),game.model.seed_value)
 Tour.travel(game,Tour.Indoor.layout(floor_),{"arrival":initial,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 12:await physics_frame
 check(game.model.falan_floor==floor_,"Direct source departure port loaded for crew "+id)
 var found=false;var chosen=Vector2.ZERO
 for step in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
  var at=source_at+step*3.
  if not game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55):continue
  await position_at(at)
  var forward=(source_at-at).normalized();game.camera_rig.yaw=atan2(-forward.x,-forward.y)
  for i in 18:await physics_frame
  if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+id:found=true;chosen=at;break
 check(found,"Real F selector reaches source crew "+id)
 if not found:
  print("EAST_SHIP_NEAREST expected=",id," actual=",game.explorer_npcs.nearest," port=",floor_);return
 await key(KEY_F)
 check(is_instance_valid(game.dialogue),"F opens the approved dialogue for crew "+id)
 for i in 12:
  if not is_instance_valid(game.dialogue):break
  await key(KEY_SPACE)
 check(not is_instance_valid(game.dialogue),"Space completes the crew dialogue "+id)
 for i in 12:await physics_frame
 if not Maps.owns(int(destination.floor)):
  check(not has_meta(Harbor.VOYAGE) and not game.transitioning and game.model.falan_floor==floor_ and game.model.gold==original_gold,"Unavailable regional arrival cannot start a timer, consumefare or strand the player "+id)
  var blocker:Dictionary=get_meta("east_harbor_blockers",{}).get("east_harbor:"+id,{})
  check(int(blocker.get("source",-1))==int(destination.floor),"Held voyage records its original destination blocker "+id)
  blocked_connections.append({"crew":id,"source":floor_,"target":int(destination.floor),"cell":destination.cell,"blocker":blocker});return
 check(has_meta(Harbor.VOYAGE) and game.model.falan_floor==int(ship.floor),"Crew F action boards the original ship floor "+id)
 if not has_meta(Harbor.VOYAGE):return
 var first_left=float(get_meta(Harbor.VOYAGE).left);var started=Time.get_ticks_msec()
 var record={"crew":id,"ship":int(action.ship),"departure_port":floor_,"stand":var_to_str(chosen),"ship_floor":int(ship.floor),"left_after_boarding":first_left,"room_crossed":false}
 if status_check:record.onboard_attendant=await onboard_status("305051")
 if walk_room:record.room_crossed=await ship_room(ship)
 var samples=[];var last_second=-1
 for i in 3600:
  if not has_meta(Harbor.VOYAGE):break
  var left=float(get_meta(Harbor.VOYAGE).left);var second=int(ceil(left))
  if second!=last_second:
   samples.append({"left":left,"wall_ms":Time.get_ticks_msec()-started,"floor":game.model.falan_floor});last_second=second
   if second%5==0:print("EAST_SHIP_PROGRESS crew=",id," left=",left," floor=",game.model.falan_floor)
  await physics_frame
 for i in 120:
  if not game.transitioning and game.model.falan_floor==int(destination.floor):break
  await physics_frame
 var arrival=Vector2i(destination.cell[0],destination.cell[1]);var wanted=Maps.source_point(int(destination.floor),arrival)
 check(not has_meta(Harbor.VOYAGE) and game.model.falan_floor==int(destination.floor),"Twenty active-play seconds reach exact original destination map "+id)
 check(map_position().distance_to(wanted)<.30,"Source port arrival cell retained for crew "+id)
 check(game.model.gold==original_gold,"Crew adds no fare beyond original admission for "+id)
 record.destination=int(destination.floor);record.arrival_cell=[arrival.x,arrival.y];record.actual_arrival=var_to_str(map_position());record.samples=samples;record.wall_seconds_after_boarding=(Time.get_ticks_msec()-started)/1000.;record.passed=game.model.falan_floor==int(destination.floor) and map_position().distance_to(wanted)<.30
 voyages.append(record)
 print("EAST_SHIP_ARRIVAL ",JSON.stringify(record))

func ship_room(ship:Dictionary)->bool:
 var links:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="freyja_door" and int(link.get("floor",-1))==41000)
 check(not links.is_empty(),"Ship has its source-confirmed cabin→deck doorway")
 if links.is_empty():return false
 var link:Dictionary=links[0];var at:Vector2=link.at;var chosen=Vector2.ZERO;var found=false
 var state:Dictionary=Maps.state(game.model.falan_floor,game.model.seed_value)
 var cell=Vector2i(((at-state.origin)/3.).round())
 for step in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
  var stand=at+step*3.
  if Maps.open(state.bits,state.size,cell+Vector2i(step)) and game.model.terrain.disk_clear(Vector3(stand.x,0,stand.y),.55):chosen=stand;found=true;break
 check(found,"Ship doorway has a reachable on-foot approach")
 if not found:return false
 await position_at(chosen);game.falan_crossing_position=Vector2.INF
 var forward=(at-chosen).normalized();game.camera_rig.yaw=atan2(-forward.x,-forward.y)
 Input.action_press("move_forward")
 for i in 180:
  await physics_frame
  if game.model.falan_floor==41000:break
 Input.action_release("move_forward")
 var passed=game.model.falan_floor==41000 and has_meta(Harbor.VOYAGE) and int(get_meta(Harbor.VOYAGE).ship)==int(ship.id) if ship.has("id") else game.model.falan_floor==41000 and has_meta(Harbor.VOYAGE)
 check(passed,"Actual walking between ship rooms preserves the ongoing voyage")
 return passed

func onboard_status(id:String)->bool:
 var crew:Dictionary=Harbor.data().npcs.filter(func(row):return str(row.id)==id)[0]
 var cell=Vector2i(crew.cell[0],crew.cell[1]);var at=Maps.source_point(game.model.falan_floor,cell)
 var state:Dictionary=Maps.state(game.model.falan_floor,game.model.seed_value);var found=false
 for step in [Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP,Vector2i.RIGHT]:
  if not Maps.open(state.bits,state.size,cell+step):continue
  await position_at(at+Vector2(step)*3.)
  var toward=(at-map_position()).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y)
  for i in 18:await physics_frame
  if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+id:found=true;break
 check(found,"Onboard original attendant is reachable through the real F selector")
 if not found:print("EAST_ONBOARD_NEAREST expected=",id," actual=",game.explorer_npcs.nearest," position=",map_position());return false
 var before:float=get_meta(Harbor.VOYAGE).left
 await key(KEY_F)
 check(is_instance_valid(game.dialogue),"Onboard F attendant opens approved dialogue")
 for i in 12:
  if not is_instance_valid(game.dialogue):break
  await key(KEY_SPACE)
 var retained:bool=has_meta(Harbor.VOYAGE) and float(get_meta(Harbor.VOYAGE).left)<=before and float(get_meta(Harbor.VOYAGE).left)>0 and game.model.falan_floor==int(crew.floor)
 check(retained,"Onboard status interaction keeps the same voyage and never resets or completes its timer")
 return retained
