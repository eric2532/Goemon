extends "res://tests/forest-shrine/south_kili_continuous_test.gd"
func _initialize():
 create_timer(600).timeout.connect(func():printerr("KILI_STREET_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-kili-streets-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=341;game.tuning.invincible=true
 Tour.travel(game,Tour.Regions.layout("kili"),{"arrival":Vector2(-48,-87),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 var path=plan_walk(Vector2(3,-6))
 check(not path.is_empty(),"West arrival reaches the central street")
 var grid=last_walk_grid;var origin=last_walk_origin
 var start=Vector2i(((map_position()-origin)/3.).round())
 var reached={start:true};var queue=[start];var cursor=0
 while cursor<queue.size():
  var cell:Vector2i=queue[cursor];cursor+=1
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next=cell+d
   if not grid.region.has_point(next) or grid.is_point_solid(next) or reached.has(next):continue
   reached[next]=true;queue.append(next)
 var mask:Image=game.model.terrain.mask_texture().get_image()
 var native={start:true};queue=[start];cursor=0
 while cursor<queue.size():
  var cell:Vector2i=queue[cursor];cursor+=1
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next=cell+d
   if not grid.region.has_point(next) or native.has(next):continue
   var color=mask.get_pixelv(next)
   if color.r>.5 or color.b>.98:continue
   native[next]=true;queue.append(next)
 var sectors={}
 for cell:Vector2i in native:
  var key=Vector2i(cell.x/20,cell.y/20)
  if not sectors.has(key):sectors[key]=[]
  if reached.has(cell):sectors[key].append(cell)
 var views=[];phase="After"
 for key in sectors:
  check(not sectors[key].is_empty(),"Original reachable street sector has a physical walking approach "+str(key))
  if sectors[key].is_empty():continue
  var center=Vector2(key)*20+Vector2(10,10);var cells:Array=sectors[key]
  cells.sort_custom(func(a,b):return Vector2(a).distance_squared_to(center)<Vector2(b).distance_squared_to(center))
  var cell:Vector2i=cells[0];var at=origin+Vector2(cell)*3.
  views.append({"sector":str(key),"cell":[cell.x,cell.y],"at":v(at),"reachable_cells":cells.size()})
  if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
   game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
   await normal_view("kili-streets-%d-%d"%[key.x,key.y],at,open_camera_yaw(at),{"area":"kili","floor":3200})
 var f=FileAccess.open(REVIEW+"kili-streets.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"source":3200,"original_reachable_cells":native.size(),"physical_reachable_cells":reached.size(),"sectors":views,"captures":captures,"failures":errors},"  "));f.close()
 print("KILI_STREET_RESULT sectors=",sectors.size()," original_cells=",native.size()," physical_cells=",reached.size()," failures=",errors)
 game.queue_free();await process_frame;quit(1 if errors else 0)
func open_camera_yaw(at:Vector2)->float:
 var anchor=game.model.world_point(at,.15)+Vector3.UP*1.4
 var best=0.;var clearance=-1.
 for step in 8:
  var yaw=step*PI/4.;var offset=Vector3(sin(yaw)*cos(.35),sin(.35),cos(yaw)*cos(.35))*16.2
  var query=PhysicsRayQueryParameters3D.create(anchor,anchor+offset,1)
  var hit=game.player.get_world_3d().direct_space_state.intersect_ray(query)
  var space=16.2 if hit.is_empty() else anchor.distance_to(hit.position)
  if space>clearance:clearance=space;best=yaw
 return best
