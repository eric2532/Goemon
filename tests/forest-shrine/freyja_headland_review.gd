extends "res://tests/forest-shrine/original_maps_test.gd"
## Actual current-source scene/native/input review of the bounded southwest recovery.
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source scenery/"
const TERRAIN_REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source outdoors/"
const Scenery=preload("res://scripts/forest/forest_venoa_southwest_scenery.gd")
var captures=[]
func _initialize():
 create_timer(300).timeout.connect(func():printerr("FREYJA_HEADLAND_TIMEOUT");quit(1))
 run.call_deferred()
func read(path:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func local_source(cell:Vector2)->Vector2:return Tour.Regions.frame("south_lakes").inverse()*(cell*3.)
func source_player()->Vector2:return Tour.Regions.frame("south_lakes")*(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)/3.
func fixed_view(label:String,cell:Vector2,yaw:float,fixed:Dictionary={}):
 game.player.position=game.model.world_point(local_source(cell),.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position;game.world.sync(0)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.camera.fov=63.;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 var camera:Camera3D=game.camera_rig.camera;var kind="normal_gameplay_camera"
 if not fixed.is_empty():
  var eye=Vector3(fixed.eye[0],fixed.eye[1],fixed.eye[2]);var rotation_=Vector3(fixed.rotation[0],fixed.rotation[1],fixed.rotation[2])
  check(camera.global_position.distance_to(eye)<.0001 and camera.global_rotation.distance_to(rotation_)<.0001,"Normal camera at204,420 retains its protected before eye/rotation")
  camera.global_position=eye;camera.global_rotation=rotation_;kind="same_before_gameplay_camera"
 camera.reset_physics_interpolation()
 for i in 4:await process_frame
 var record={"name":label,"source_cell":[cell.x,cell.y],"kind":kind,"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov}
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw();var image=root.get_texture().get_image();var colors={}
  for y in range(0,image.get_height(),32):
   for x in range(0,image.get_width(),32):colors[image.get_pixel(x,y).to_rgba32()]=true
  check(colors.size()>20,"Rendered gameplay image is nonblank "+label)
  var path=REVIEW+label+".png";check(image.save_png(path)==OK,"Fixed view saved "+label);record.sha256=FileAccess.get_sha256(path)
 captures.append(record)
func run():
 root.size=Vector2i(1280,800)
 var expected=Scenery.catalog();var terrain_stage=read(TERRAIN_REVIEW+"Prepared preview/provenance.json")
 check(expected.placements.size()==132 and expected.offshore_placements.size()==5,"Coherent bounded132+5 scenery is published")
 check(expected.source_map_sha256==terrain_stage.source_sha256,"Terrain and scenery bind the same bounded source variant")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-freyja-headland-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true
 var saved=JSON.stringify(get_meta("falan_venture"))
 Tour.travel(game,Tour.Regions.layout("south_lakes"),{"arrival":local_source(Vector2(204,420)),"yaw":PI*.5,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();game.army_runtime.refresh_navigation(0)
 var terrain=game.model.terrain;var bounds:Rect2=terrain.mask_bounds();var art=game.world.find_child("VenoaSouthwestSourceScenery",true,false)
 check(terrain.mask_origin()==Vector2(-582,-480) and terrain.mask_image().get_size()==Vector2i(355,321),"Existing terrain owner extends eight source columns")
 check(game.world.playable_bounds.is_equal_approx(Rect2(bounds.position*game.model.falan_scale,bounds.size*game.model.falan_scale)),"Player bounds match the native mask rectangle")
 var water=game.world.find_child("FreyjaWater",true,false)
 check(water!=null,"Existing full-source water owner is mounted")
 if water!=null:
  var material:ShaderMaterial=water.get_active_material(0);var index:Texture2D=material.get_shader_parameter("freyja_ground_index")
  check(material.get_shader_parameter("layout_mask")==terrain.VenoaField.OCEAN_BACKDROP,"Water uses the coherent bounded-source backdrop")
  check(index.resource_path==terrain.VenoaField.OCEAN_INDEX_PATH and index.resource_path.contains("freyja_residual/full/"),"Water uses the prepared source-variant index")
 var outside=Vector3((bounds.position.x-3)*game.model.falan_scale,0,bounds.get_center().y*game.model.falan_scale)
 check(is_nan(game.world.water_support_height(outside)),"Visual ocean still adds no support beyond the native rectangle")
 check(art!=null,"Existing scenery owner is mounted in the actual scene")
 if art==null:quit(1);return
 var stations={};var positions_exact=true;var position_errors=[];var maximum_position_error=0.
 for node in art.get_children():
  if not node is MultiMeshInstance3D:continue
  var serial:int=node.get_meta("venoa_southwest_serial");var cells:Array=node.get_meta("venoa_southwest_cells")
  for i in cells.size():
   var pose:Transform3D=node.multimesh.get_instance_transform(i)
   if expected.graphics[str(serial)].family=="tree":
    for part in Scenery.Meadow.source(Scenery.Meadow.crossgate_tree(serial)):
     if part.name==node.get_meta("crossgate_tree_part",""):pose*=part.transform.affine_inverse();break
    pose*=Scenery.Ruby.tree_fit(serial).affine_inverse()
   var cell=Vector2(cells[i][0],cells[i][1]);var actual:Vector2=Tour.Regions.frame("south_lakes")*Vector2(pose.origin.x,pose.origin.z)/3.
   var error=actual.distance_to(cell);maximum_position_error=maxf(maximum_position_error,error)
   if error>=.0001:position_errors.append({"serial":serial,"part":node.name,"source":str(cell),"actual":str(actual),"error_cells":error})
   positions_exact=positions_exact and error<.0001;stations[[int(cell.x),int(cell.y),serial]]=true
 check(stations.size()==132,"All132 source scenery stations are represented")
 if DisplayServer.get_name()!="headless":check(positions_exact,"Rendered MultiMesh buffers retain exact source cells and graphics")
 check(expected.placements.all(func(row):return stations.has([int(row.cell[0]),int(row.cell[1]),int(row.serial)])),"No source station is dropped by the live renderer")
 var tree_blocks=Scenery.tree_blocks(game.model);var blocked=0;var physical=0;var passable=true
 for row in tree_blocks:
  var point=game.model.world_point(local_source(Vector2(row[3][0],row[3][1])))
  blocked+=int(not game.army_runtime.native.can_reach(point,point,.1))
 for node in game.world.find_children("*","StaticBody3D",true,false):
  if node.get_meta("venoa_southwest_tree",false):physical+=1;passable=passable and node.is_in_group("forest_player_passable_scenery")
 check(tree_blocks.size()==27 and blocked==27,"All27 source-blocked tree trunks use native obstacles")
 check(physical==27 and passable,"All27 physical trunks retain existing player-passable behavior")
 var delegated=terrain_stage.areas.south_lakes.scenery_owned_blocked_cells
 check(delegated.size()==5,"Terrain delegates the five newly recovered trees")
 var generic=Tour.Frontier.Residual.collisions(game.model);var duplicate=false
 for row in delegated:
  var at=local_source(Vector2(row[0],row[1]))
  for solid in generic:duplicate=duplicate or solid[2].has_point(Vector3(at.x,6,at.y))
 check(not duplicate,"Delegated tree cells have no duplicate generic stone collider")
 var before=read("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/southwest-rendered-verification.json")
 var old=read("res://assets/maps/falan/venoa_field/provenance.json");var newly_lost=[]
 for cell in old.new_decoder_open_cells:
  var at=game.model.world_point(local_source(Vector2(cell[0],cell[1])))
  if not game.army_runtime.native.can_reach(at,at,.1) and cell not in before.native_self_unreachable:newly_lost.append(cell)
 check(newly_lost.is_empty(),"Recovered scenery removes no previously verified open native point")
 var samples=[];var navigation=game.army_runtime.navigation_data(game.model)
 for station in [[Vector2(204,420),true],[Vector2(198,420),true],[Vector2(195,420),false],[Vector2(210,407),false]]:
  var cell:Vector2=station[0]
  var at=game.model.world_point(local_source(cell));var clear=game.army_runtime.native.can_reach(at,at,.1)
  var point=local_source(cell);var pixel=Vector2i(((point-terrain.mask_origin())/3.).round());var obstacles=[]
  for i in navigation.obstacle_min.size():
   var box=AABB(navigation.obstacle_min[i],navigation.obstacle_max[i]-navigation.obstacle_min[i])
   if box.has_point(Vector3(point.x,terrain.height(point.x,point.y),point.y)):obstacles.append({"index":i,"bounds":str(box)})
  check(clear==station[1],"Interior support or inherited source-shore clearance is recorded "+str(cell));samples.append({"source_cell":[cell.x,cell.y],"local_point":str(point),"world":str(at),"native_self_reachable":clear,"clearance_qualification":"Fully dry interior"if station[1]else"Source-open shoreline center; inherited four-corner finite-radius terrain rule rejects adjacent source water. Native source-fidelity review remains required.","friendly_ground_clear":game.army_runtime.native.ally_ground_clear(at,.1),"terrain_disk_clear":terrain.disk_clear(Vector3(point.x,terrain.height(point.x,point.y),point.y),.1),"mask_rgba":str(terrain.mask_image().get_pixelv(pixel)),"overlapping_native_obstacles":obstacles})
 game.player.position=game.model.world_point(local_source(Vector2(204,420)),.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation();game.camera_rig.yaw=PI*.5
 game.set_physics_process(true);game.player.set_physics_process(true)
 var movement=[]
 Input.action_press("move_forward")
 for i in 180:
  if not Input.is_action_pressed("move_forward"):Input.action_press("move_forward")
  await physics_frame
  if i%30==0:movement.append(str(source_player()))
  if source_player().x<198.5:break
 Input.action_release("move_forward");game.set_physics_process(false);game.player.set_physics_process(false)
 var movement_end=source_player()
 check(movement_end.x<200.5,"Actual move_forward controls enter the recovered source columns")
 var baseline=JSON.parse_string(FileAccess.get_file_as_string(TERRAIN_REVIEW+"before-camera-rendered.json"))[0]
 await fixed_view("headland-same-before",Vector2(204,420),PI*.5,baseline)
 await fixed_view("headland-west-bank",Vector2(198,420),PI*.5)
 await fixed_view("headland-north-trees",Vector2(214,410),PI)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"User adventure data remains unchanged")
 var result={"checks":checks,"failures":failures,"goal_complete":false,"source_sha256":expected.source_map_sha256,"scenery_sha256":FileAccess.get_sha256("res://assets/maps/falan/venoa_field/scenery.json"),"actual_source_stations":stations.size(),"renderer_transform_readback_valid":DisplayServer.get_name()!="headless","maximum_position_error_cells":maximum_position_error,"position_errors":position_errors,"road_boundary_active":not game.model.falan_road.is_empty(),"tree_blocks":tree_blocks.size(),"physical_tree_trunks":physical,"newly_lost_old_native_points":newly_lost,"native_samples":samples,"movement_samples":movement,"movement_end_source":str(movement_end),"captures":captures,"qualification":"Bounded headland scene, native support and normal-control evidence. Original encounter boundaries and wider map100 recovery remain required; visual judgment is separate."}
 var file=FileAccess.open(REVIEW+"headland-"+("headless"if DisplayServer.get_name()=="headless"else"rendered")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
 game.queue_free();current_scene=null;await process_frame
 print("FREYJA_HEADLAND_RESULT ",checks," checks ",failures," failures ",captures.size()," cameras");quit(1 if failures else 0)
