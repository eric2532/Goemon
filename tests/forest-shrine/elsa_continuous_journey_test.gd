extends "res://tests/forest-shrine/elsa_route_test.gd"
## Normal Explore spawn → castle → every original crossing → island → castle.
## The planner chooses held-input directions only; it never moves or travels the player.
const REVIEW="res://build/Other Files/Asset Toolkit/Elsa Island/"
var movement_frames=0
var distance_walked=0.
var journey:Array=[]
var music_checks:Array=[]
var preferences_before:PackedByteArray
var preferences_existed=false
var last_walk_position=Vector2.ZERO

func _initialize():
 create_timer(1800).timeout.connect(func():printerr("ELSA_CONTINUOUS_TIMEOUT");save_journey();quit(1))
 run.call_deferred()

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-elsa-continuous-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.settings.music_enabled=true
 game.equipment_hub.enter_button.pressed.emit()
 for i in 6:await physics_frame
 root.gui_disable_input=false
 game.tuning.invincible=true # Travel verification, not an encounter-balance claim.
 game.explorer_clock.save_left=3600.
 game.model.team_progression.level=1;game.model.gold=0
 preferences_existed=FileAccess.file_exists(game.settings_path)
 if preferences_existed:preferences_before=FileAccess.get_file_as_bytes(game.settings_path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Continuous/"))
 print("ELSA_CONTINUOUS_START area=",Tour.area(game.model)," at=",map_position())
 check(Tour.area(game.model)=="city","Normal Explore starts in Falan without a fixture placement")
 if failures==0:await walk_crossing("castle",1500,Vector2(-102,0))
 if failures==0:
  await walk_to(Elsa.castle_point(Vector2i(28,88)),false)
  check(Tour.area(game.model)=="castle","Walk from the real castle entrance reaches the source activation tile")
 if failures==0:
  await arrival_view("00-castle-start","m0")
  await stone(false)
  check(Tour.area(game.model)=="castle","No cancels the outbound stone")
  await stone(true)
  check(game.model.falan_floor==59511,"Yes enters the actual time passage")
  check(game.model.team_progression.level==1 and game.model.gold==0,"Level one with zero gold travels free")
  await arrival_view("01-time-passage","")
 for leg in [[59511,59510,19,17],[59510,59500,96,138],[59500,59501,124,168],[59501,59520,264,108]]:
  if failures:break
  check(game.model.falan_floor==leg[0],"Continuous journey is on the expected original map")
  await walk_crossing("interior",leg[1],Original.source_point(leg[0],Vector2i(leg[2],leg[3])))
  if failures==0:await arrival_view("%02d-arrival-%d"%[journey.size(),leg[1]],{59510:"puk2_haikyo",59500:"puk2_field1",59501:"puk2_field1",59520:"puk2_mati"}[leg[1]])
 if failures==0:
  await walk_to(Original.source_point(59520,Vector2i(140,104)),false)
  check(game.model.falan_floor==59520 and game.army_runtime.handles.is_empty(),"Island walk to the return stone stays safe")
  var gold=game.model.gold;var progression=game.model.team_progression
  await stone(true)
  check(Tour.area(game.model)=="castle","Normal return-stone interaction completes the round trip")
  check(game.player.position.distance_to(game.model.world_point(Elsa.castle_point(Vector2i(27,82)),.15))<.5,"Return stone preserves castle landing (27,82)")
  check(game.model.gold==gold and game.model.team_progression==progression,"Return preserves gold and character progression")
  await arrival_view("07-castle-return","m0")
 check(FileAccess.file_exists(game.settings_path)==preferences_existed,"Journey does not create or remove preferences")
 if preferences_existed:check(FileAccess.get_file_as_bytes(game.settings_path)==preferences_before,"Journey does not rewrite home, login or preferences")
 print("ELSA_CONTINUOUS_RESULT checks=",checks," failures=",failures," movement_frames=",movement_frames," distance=",distance_walked," placements=0 direct_travel_calls=0")
 save_journey();await finish()

func map_position()->Vector2:
 return Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale

func source_map_id()->int:
 return 1500 if Tour.area(game.model)=="castle" else 1000 if Tour.area(game.model)=="city" else int(game.model.falan_floor)

func key(code:Key):
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
 Input.parse_input_event(event);await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame

func stone(accept:bool):
 Input.action_release("move_forward")
 var before=source_map_id();var at=map_position()
 await key(KEY_E)
 check(is_instance_valid(game.dialogue),"E opens the ordinary stone yes/no dialogue")
 if not is_instance_valid(game.dialogue):return
 await key(KEY_SPACE)
 if not accept:await key(KEY_RIGHT)
 await key(KEY_ENTER)
 for i in 6:await physics_frame
 journey.append({"kind":"stone","from_map":before,"from_position":v(at),"answer":"yes" if accept else "no","to_map":source_map_id(),"arrival":v(map_position()),"movement_frames":movement_frames})
 save_journey()

func walk_crossing(area_:String,id:int,target:Vector2):
 var from_area=Tour.area(game.model);var from_id=source_map_id()
 var links:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.to==area_ if area_=="castle" else int(link.get("floor",-1))==id)
 check(not links.is_empty(),"Original crossing exists for the next journey map")
 var model=game.model
 await walk_to(target,true)
 for i in 6:await physics_frame
 var passed=game.model!=model and Tour.area(game.model)==area_ and (area_!="interior" or game.model.falan_floor==id)
 check(passed,"Held movement uses the real crossing %s/%d → %s/%d"%[from_area,from_id,area_,id])
 var actual=map_position()
 var matching=links.filter(func(link):return actual.distance_to(link.arrival)<.8 and last_walk_position.distance_to(link.at)<3.)
 check(not matching.is_empty(),"Actual crossing keeps its own archived landing, including adjacent tiles")
 journey.append({"kind":"walk","from_area":from_area,"from_map":from_id,"to_area":Tour.area(game.model),"to_map":source_map_id(),"last_source_position":v(last_walk_position),"arrival":v(actual),"passed":passed,"matching_source_positions":matching.map(func(link):return v(link.at)),"movement_frames":movement_frames})
 save_journey()

func walk_to(target:Vector2,crossing:bool):
 var model=game.model;var origin:Vector2;var size_:Vector2i;var bits:PackedByteArray;var mask:Image
 if Tour.area(model)=="interior":
  var row=Original.state(model.falan_floor,model.seed_value);origin=row.origin;size_=row.size;bits=row.bits
 else:
  mask=model.terrain.mask_texture().get_image();origin=model.terrain.mask_origin();size_=mask.get_size()
 var grid=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,size_);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
 var clearance=PhysicsShapeQueryParameters3D.new();clearance.shape=game.player.body_shape.shape
 clearance.collision_mask=1;clearance.exclude=[game.player.get_rid()]
 var space=game.player.get_world_3d().direct_space_state
 for y in size_.y:
  for x in size_.x:
   var cell=Vector2i(x,y)
   if mask!=null:
    # City/castle blue is paving, not cliff collision. Red/alpha describe land;
    # authored scenery boxes below provide the actual courtyard obstacles.
    var color=mask.get_pixelv(cell);grid.set_point_solid(cell,color.r>.5 or color.a<.5)
   else:grid.set_point_solid(cell,not Original.open(bits,size_,cell))
   if mask!=null and not grid.is_point_solid(cell):
    var local=origin+Vector2(cell)*3.
    if not model.terrain.disk_clear(Vector3(local.x,0,local.y),.55):grid.set_point_solid(cell,true)
   if not grid.is_point_solid(cell):
    clearance.transform=Transform3D(Basis.IDENTITY,model.world_point(origin+Vector2(cell)*3.,.15)+game.player.body_shape.position)
    var hits=space.intersect_shape(clearance,8)
    if hits.any(func(hit):return hit.collider.get_children().any(func(node):return node is CollisionShape3D and node.shape is BoxShape3D)):grid.set_point_solid(cell,true)
 for box:AABB in model.scenery_obstacles.values():
  var a=Vector2i(((Vector2(box.position.x,box.position.z)-origin)/3.).floor());var b=Vector2i(((Vector2(box.end.x,box.end.z)-origin)/3.).ceil())
  for y in range(maxi(0,a.y),mini(size_.y,b.y+1)):
   for x in range(maxi(0,a.x),mini(size_.x,b.x+1)):
    var at=origin+Vector2(x,y)*3.;var h=model.surface_height(at.x,at.y)
    if box.grow(.45).has_point(Vector3(at.x,h+.8,at.y)):grid.set_point_solid(Vector2i(x,y))
 # Do not accidentally walk into another local door while approaching the selected crossing.
 var selected=game.model.get_meta("falan_links",[]).filter(func(link):return link.at==target)
 for link in game.model.get_meta("falan_links",[]):
  if not Tour.is_walk_in(Tour.area(model),link) or link.at==target:continue
  if crossing and link.at.distance_to(target)<=9. and selected.any(func(chosen):return chosen.to==link.to and chosen.get("floor",-1)==link.get("floor",-1)):continue
  var cell=Vector2i(((link.at-origin)/3.).round())
  if grid.region.has_point(cell):grid.set_point_solid(cell)
 var start=Vector2i(((map_position()-origin)/3.).round());var end=Vector2i(((target-origin)/3.).round())
 check(grid.region.has_point(start) and grid.region.has_point(end),"Walking endpoints lie in the source mask")
 if failures:return
 # A travel marker may sit just inside its doorway's coarse obstacle cell.
 # The real controller must still reach the normal 2.1 m crossing threshold.
 grid.set_point_solid(start,false);grid.set_point_solid(end,false)
 var path=grid.get_id_path(start,end)
 check(not path.is_empty(),"Source mask connects the actual arrival to the next interaction")
 print("ELSA_INPUT_WALK area=",Tour.area(model)," map=",model.falan_floor," points=",path.size()," from=",map_position()," target=",target)
 for cell in path:
  var at=target if cell==end else origin+Vector2(cell)*3.
  var reached=false
  for frame in 180:
   if game.model!=model:Input.action_release("move_forward");return
   last_walk_position=map_position()
   if last_walk_position.distance_to(at)<.35:reached=true;break
   var toward=(at-last_walk_position).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y)
   Input.action_press("move_forward")
   var before=game.player.position
   await physics_frame;movement_frames+=1
   if game.model==model:distance_walked+=before.distance_to(game.player.position)
  Input.action_release("move_forward")
  if not reached:
   var motion=KinematicCollision3D.new()
   if game.player.test_move(game.player.global_transform,model.world_point(at,.15)-game.player.position,motion):print("ELSA_INPUT_COLLIDER ",motion.get_collider().get_path() if motion.get_collider()!=null else "unknown"," normal=",motion.get_normal())
   printerr("ELSA_INPUT_BLOCKED area=",Tour.area(model)," map=",model.falan_floor," at=",map_position()," target=",at," velocity=",game.player.velocity)
   check(false,"Actual player controller reaches every planned walking segment");save_journey();return
 if crossing:check(game.model!=model,"Walking enters the selected crossing threshold")

func arrival_view(label:String,music_key:String):
 var stream:AudioStream=Music.STREAMS.get(music_key)
 check(game.music.stream==stream,"Normal map entry selects original music "+music_key)
 check(game.music.playing if stream!=null else not game.music.playing,"Normal map entry honors playback or source silence")
 music_checks.append({"map":source_map_id(),"key":music_key,"playing":game.music.playing,"stream":game.music.stream.resource_path if game.music.stream!=null else "","passed":game.music.stream==stream and (game.music.playing if stream!=null else not game.music.playing)})
 if DisplayServer.get_name()!="headless":
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(REVIEW+"Continuous/"+label+".png")

func v(p:Vector2)->Array:return [p.x,p.y]

func save_journey():
 var file=FileAccess.open(REVIEW+"continuous-journey.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"journey":journey,"music_checks":music_checks,"checks":checks,"failures":failures,"movement_frames":movement_frames,"distance_walked":distance_walked,"player_placements":0,"direct_travel_calls":0,"manual_crossing_calls":0,"invincible":true,"rendered":DisplayServer.get_name()!="headless","area":Tour.area(game.model) if is_instance_valid(game) else "timeout"},"  "));file.close()
