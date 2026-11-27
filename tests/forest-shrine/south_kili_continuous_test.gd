extends "res://tests/forest-shrine/south_kili_route_review.gd"
var route_log=[]
var moved_frames=0
var last_walk_grid:AStarGrid2D
var last_walk_origin:Vector2
func _initialize():
 create_timer(2400).timeout.connect(func():printerr("SOUTH_KILI_CONTINUOUS_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-south-kili-continuous-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible="--invincible" in OS.get_cmdline_user_args();game.run_seed=341
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Continuous/"))
 # Initial scene placement only. All subsequent movement and travel use real input/crossings.
 game.player.position=game.model.world_point(STAGES[0][4],.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.falan_crossing_position=STAGES[0][4]
 for i in STAGES.size()-1:
  var s:Array=STAGES[i];var next:Array=STAGES[i+1]
  check(Tour.area(game.model)==s[0] and (s[0]!="interior" or game.model.falan_floor==s[1]),"Continuous route entered expected map "+str(i))
  if errors:break
  var end:Vector2=s[5]
  if s[0] in ["south_lakes","sokia_coast"]:end=Tour.Regions.frame(s[0]).inverse()*end
  if i==0:end+=Vector2(4,0)
  if s[0]=="sokia_coast":end+=Vector2(0,3)
  var before=game.model
  for gate_attempt in 3:
   var path=PackedVector2Array([end]) if i==0 else plan_walk(end)
   if path.is_empty() and s[1]==15004:path=plan_walk(Vector2(-24,42))
   check(not path.is_empty(),"Physics route has a walking path on "+str(s[1])+" "+s[0])
   if path.is_empty():break
   print("SOUTH_KILI_WALK ",i," ",s[0]," ",s[1]," points=",path.size())
   var previous=game.model
   await follow_input(path,previous)
   Input.action_release("move_forward")
   for tick in 5:await physics_frame
   if Tour.area(game.model)==next[0] and (next[0]!="interior" or game.model.falan_floor==next[1]):break
   if game.model==previous:
    errors+=1;printerr("SOUTH_KILI_CROSS_FAIL ",i," at=",map_position()," target=",end);break
   if s[1]!=15004:break
   route_log.append({"index":i,"gate":"original warrior crossing","floor":15004,"at":v(map_position())})
  var passed=Tour.area(game.model)==next[0] and (next[0]!="interior" or game.model.falan_floor==next[1]) and game.model!=before
  check(passed,"Real crossing reaches "+str(next[0])+" "+str(next[1]))
  route_log.append({"index":i,"from":[s[0],s[1]],"to":[Tour.area(game.model),game.model.falan_floor],"at":v(map_position()),"passed":passed,"input_frames":moved_frames})
  if passed and DisplayServer.get_name()!="headless":await crossing_view(i)
  save_log()
  if not passed:break
 if errors==0:
  check(Tour.area(game.model)=="kili","Continuous run arrived through Kili west gate")
  var path=plan_walk(Vector2(3,-6))
  check(not path.is_empty(),"West gate connects to the reachable village street")
  if not path.is_empty():await follow_input(path,game.model)
  check(map_position().distance_to(Vector2(3,-6))<1.,"Walked into Kili street without a direct village load")
  check(game.player.hp>0,"Normal character survived the continuous route")
  if DisplayServer.get_name()!="headless":await crossing_view(10)
 print("SOUTH_KILI_CONTINUOUS_RESULT failures=",errors," crossings=",route_log.size()," movement_frames=",moved_frames)
 save_log();game.queue_free();await process_frame;quit(1 if errors else 0)
func plan_walk(target:Vector2)->PackedVector2Array:
 var mask:Image;var origin:Vector2
 if Tour.area(game.model)=="interior":
  var f=Tour.Indoor.floor_info(game.model.falan_floor);origin=f[1];var bits:PackedByteArray=f[2].hex_decode();mask=Image.create(f[0].x,f[0].y,false,Image.FORMAT_RGB8)
  for y in f[0].y:
   for x in f[0].x:
    var n=y*f[0].x+x;mask.set_pixel(x,y,Color(0,1,0) if bits[n>>3]&(1<<(n&7)) else Color(1,0,0))
 else:mask=game.model.terrain.mask_texture().get_image();origin=game.model.terrain.mask_origin()
 var grid=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,mask.get_size());grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
 var clearance=PhysicsShapeQueryParameters3D.new();clearance.shape=game.player.body_shape.shape;clearance.collision_mask=1;clearance.exclude=[game.player.get_rid()]
 var space=game.player.get_world_3d().direct_space_state
 for y in mask.get_height():
  for x in mask.get_width():
   var c=mask.get_pixel(x,y);grid.set_point_solid(Vector2i(x,y),c.r>.5 or c.b>.98)
   if c.g<.56:grid.set_point_weight_scale(Vector2i(x,y),2.)
   if not grid.is_point_solid(Vector2i(x,y)):
    var at=game.model.world_point(origin+Vector2(x,y)*3.,.15)+game.player.body_shape.position
    clearance.transform=Transform3D(Basis.IDENTITY,at)
    var hits=space.intersect_shape(clearance,8)
    if hits.any(func(hit):return hit.collider.get_children().any(func(n):return n is CollisionShape3D and n.shape is BoxShape3D)):grid.set_point_solid(Vector2i(x,y),true)
 # Prepared source collision remains authoritative; exclude fixtures from the candidate grid.
 for box:AABB in game.model.scenery_obstacles.values():
  var a=Vector2i(((Vector2(box.position.x,box.position.z)-origin)/3.).floor());var b=Vector2i(((Vector2(box.end.x,box.end.z)-origin)/3.).ceil())
  for y in range(maxi(0,a.y),mini(mask.get_height(),b.y+1)):
   for x in range(maxi(0,a.x),mini(mask.get_width(),b.x+1)):
    var p=origin+Vector2(x,y)*3.;var h=game.model.surface_height(p.x,p.y)
    if box.grow(.45).has_point(Vector3(p.x,h+.8,p.y)):grid.set_point_solid(Vector2i(x,y))
 var start=Vector2i(((map_position()-origin)/3.).round());var end=Vector2i(((target-origin)/3.).round())
 last_walk_grid=grid;last_walk_origin=origin
 if not grid.region.has_point(start) or not grid.region.has_point(end):return PackedVector2Array()
 grid.set_point_solid(start,false);grid.set_point_solid(end,false)
 var points=grid.get_id_path(start,end);var result=PackedVector2Array()
 for c in points:result.append(origin+Vector2(c)*3.)
 if not result.is_empty():result[-1]=target
 return result
func follow_input(path:PackedVector2Array,model):
 for p in path:
  var reached=false
  for frame in 150:
   if game.model!=model:return
   if map_position().distance_to(p)<.35:reached=true;break
   var toward=(p-map_position()).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y)
   Input.action_press("move_forward")
   if frame%18==0:
    var attack=InputEventAction.new();attack.action="light_attack";attack.pressed=true;Input.parse_input_event(attack)
    attack=attack.duplicate();attack.pressed=false;Input.parse_input_event(attack)
   await physics_frame;moved_frames+=1
  Input.action_release("move_forward")
  if not reached:
   var motion=KinematicCollision3D.new()
   var target=game.model.world_point(p,.15)
   if game.player.test_move(game.player.global_transform,target-game.player.position,motion):print("SOUTH_KILI_BLOCKER ",motion.get_collider().get_path() if motion.get_collider()!=null else "unknown"," normal=",motion.get_normal())
   errors+=1;printerr("SOUTH_KILI_STUCK floor=",game.model.falan_floor," area=",Tour.area(game.model)," at=",map_position()," target=",p)
   return
func save_log():
 var f=FileAccess.open(REVIEW+"continuous.json",FileAccess.WRITE);f.store_string(JSON.stringify({"route":route_log,"failures":errors,"movement_frames":moved_frames,"debug_teleports_after_start":0,"invincible":game.tuning.invincible,"player_hp":game.player.hp,"rendered":DisplayServer.get_name()!="headless"},"  "));f.close()
func crossing_view(index:int):
 for i in 3:await process_frame
 RenderingServer.force_draw()
 var path="Continuous/%02d-%s-%d.png"%[index,Tour.area(game.model),game.model.falan_floor]
 root.get_texture().get_image().save_png(REVIEW+path)
 print("SOUTH_KILI_RENDERED_CROSSING ",index," ",Tour.area(game.model)," ",game.model.falan_floor," hp=",game.player.hp)
