extends "res://tests/forest-shrine/original_maps_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/"
var captures=[]
var scenery_evidence={}
func _initialize():
 create_timer(600).timeout.connect(func():printerr("VENOA_SOUTHWEST_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()
func local_source(cell:Vector2)->Vector2:return Tour.Regions.frame("south_lakes").inverse()*(cell*3.)
func source_player()->Vector2:return Tour.Regions.frame("south_lakes")*(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)/3.
func normal_view(label:String,cell:Vector2,yaw:float):
 game.player.position=game.model.world_point(local_source(cell),.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position;game.world.sync(0)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 # Use the normal settled camera without extrapolating its frame smoothing.
 game.camera_rig.camera.fov=63.;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true);game.camera_rig.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.reset_physics_interpolation()
 check(is_equal_approx(camera.fov,63.),"Fixed normal gameplay FOV is retained for "+label)
 for i in 4:await process_frame
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw();root.get_texture().get_image().save_png(REVIEW+label+".png")
 captures.append({"name":label,"area":game.model.falan_area,"source_cell":[cell.x,cell.y],"hour":game.explorer_clock.hour,
  "eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov})
func source_overview():
 var camera:Camera3D=game.camera_rig.camera
 var center=game.model.world_point(local_source(Vector2(214,426)))+Vector3.UP*6
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=155.
 camera.global_position=center+Vector3(-1,0,1).normalized()*sqrt(1.-.75*.75)*200.+Vector3.UP*150.
 camera.look_at(center,Vector3.UP);camera.reset_physics_interpolation()
 for i in 4:await process_frame
 if DisplayServer.get_name()!="headless":RenderingServer.force_draw();root.get_texture().get_image().save_png(REVIEW+"southwest-source-aligned.png")
 var origin=local_source(Vector2.ZERO)*game.model.falan_scale
 var zero=camera.unproject_position(Vector3(origin.x,0,origin.y))
 var x=camera.unproject_position(Vector3(origin.x+3*game.model.falan_scale,0,origin.y))-zero
 var y=camera.unproject_position(Vector3(origin.x,0,origin.y+3*game.model.falan_scale))-zero
 captures.append({"name":"southwest-source-aligned","projection":"orthographic","source_zero":[zero.x,zero.y],"source_x":[x.x,x.y],"source_y":[y.x,y.y],"size":camera.size,"fov":camera.fov,"area":game.model.falan_area})
func check_scenery(provenance:Dictionary,unreachable:Array):
 var source=load("res://scripts/forest/forest_venoa_southwest_scenery.gd")
 var art=game.world.find_child("VenoaSouthwestSourceScenery",true,false)
 check(art!=null,"The recovered source strip has its existing scenery owner")
 if art==null:return
 var expected:Array=provenance.new_source_art_anchors.duplicate(true)
 var anchors:Array=art.get_meta("venoa_southwest_anchors").duplicate(true)
 var expected_keys={};var actual_keys={}
 for row in expected:expected_keys[Vector3i(row[0],row[1],row[2])]=true
 for row in anchors:actual_keys[Vector3i(row[0],row[1],row[2])]=true
 check(anchors.size()==80 and actual_keys==expected_keys,"All80original source anchors and graphic IDs are declared exactly")
 var represented={};var positions_exact=true;var position_errors=[];var shore_count=0;var exposed_shores=0
 var crown_tints={};var scoped_crowns=true;var old_ruby_preserved=true;var bark_meshes_preserved=true
 for node in art.get_children():
  if not node is MultiMeshInstance3D:continue
  var serial:int=node.get_meta("venoa_southwest_serial");var cells:Array=node.get_meta("venoa_southwest_cells")
  var graphic:Dictionary=source.catalog().graphics[str(serial)]
  if graphic.family=="tree":
   if node.get_meta("crossgate_tree_part","")=="Canopy":
    var rgb:Array=graphic.crown_linear_tint;var wanted=Vector3(rgb[0],rgb[1],rgb[2])
    var actual:Vector3=node.material_override.get_shader_parameter("foliage_tint")
    scoped_crowns=scoped_crowns and actual.is_equal_approx(wanted) and node.material_override!=source.Ruby.leaf_materials.get(serial)
    crown_tints[str(serial)]={"actual_linear_tint":str(actual),"native_crown_srgb_mean":graphic.crown_srgb_mean,"base_serial":graphic.base_serial}
    if source.Ruby.leaf_materials.has(serial):
     var old_native=10058 if serial<10074 else 10085 if serial<10088 else 10088
     var old_rgb:Array=source.Ruby.catalog().graphics[str(serial)].leaf_rgb;var old_base:Array=source.Ruby.catalog().palettes[str(old_native)]
     var old_actual:Vector3=source.Ruby.leaf_materials[serial].get_shader_parameter("foliage_tint")
     old_ruby_preserved=old_ruby_preserved and old_actual.is_equal_approx(Vector3(old_rgb[0]/old_base[0],old_rgb[1]/old_base[1],old_rgb[2]/old_base[2]))
   else:
    for part in source.Meadow.source(source.Meadow.crossgate_tree(serial)):
     if part.name==node.get_meta("crossgate_tree_part",""):bark_meshes_preserved=bark_meshes_preserved and node.multimesh.mesh==part.mesh
  for i in cells.size():
   var pose:Transform3D=node.multimesh.get_instance_transform(i)
   if source.catalog().graphics[str(serial)].family=="tree":
    for part in source.Meadow.source(source.Meadow.crossgate_tree(serial)):
     if part.name==node.get_meta("crossgate_tree_part",""):pose*=part.transform.affine_inverse();break
    pose*=source.Ruby.tree_fit(serial).affine_inverse()
   var point:Vector2=Tour.Regions.frame("south_lakes")*Vector2(pose.origin.x,pose.origin.z)/3.
   var cell=Vector2(cells[i][0],cells[i][1]);var error=point.distance_to(cell)
   if error>.0001:position_errors.append({"serial":serial,"part":node.name,"expected":str(cell),"actual":str(point),"error_cells":error})
   positions_exact=positions_exact and error<.0001
   represented[[int(cell.x),int(cell.y),serial]]=true
   if source.catalog().graphics[str(serial)].family=="shore":
    shore_count+=1
    var box:AABB=node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb()
    if box.end.y>game.model.terrain.WATER_HEIGHT+.01 and absf(box.position.y-game.model.terrain.WATER_HEIGHT)<.01:exposed_shores+=1
 check(represented.size()==80 and positions_exact,"Actual renderer instances keep all80native stations without anchor drift")
 check(shore_count==49 and exposed_shores==49,"All49native shore forms expose their painted caps/faces and meet water without new support")
 check(scoped_crowns and bark_meshes_preserved,"Owned canopy-only source/base tints preserve original bark meshes")
 check(old_ruby_preserved,"Old Ruby canopy materials keep their existing tints")
 var blocks=source.tree_blocks(game.model);var clipped=true;var blocked=0
 for row in blocks:
  var point:Vector2=local_source(Vector2(row[3][0],row[3][1]));var box:AABB=row[2]
  clipped=clipped and box.position.x>=point.x-1.5 and box.end.x<=point.x+1.5 and box.position.z>=point.y-1.5 and box.end.z<=point.y+1.5
  var at=game.model.world_point(point)
  if not game.army_runtime.native.can_reach(at,at,.1):blocked+=1
 check(blocks.size()==22 and clipped,"Only22source-blocked tree trunks own shapes, each inside its native blocked tile")
 check(blocked==22,"Native navigation respects all22source-confirmed blocked tree cells")
 var physical=0;var passable=true
 for node in game.world.find_children("*","StaticBody3D",true,false):
  if node.get_meta("venoa_southwest_tree",false):physical+=1;passable=passable and node.is_in_group("forest_player_passable_scenery")
 check(physical==22 and passable,"Physical trunks reuse existing player-passable tree behavior")
 var before=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"before-scenery-southwest-rendered-verification.json"))
 var lost=[];var gained=[]
 for cell in unreachable:
  if cell not in before.native_self_unreachable:lost.append(cell)
 for cell in before.native_self_unreachable:
  if cell not in unreachable:gained.append(cell)
 check(lost.is_empty(),"New tree trunks do not remove previously proven source-open native points")
 scenery_evidence={"declared_anchors":anchors,"counts":art.get_meta("venoa_southwest_counts"),"actual_renderer_stations":represented.size(),"actual_shore_tiles":shore_count,"exposed_shore_forms":exposed_shores,"position_errors":position_errors,"crown_tints":crown_tints,"old_ruby_materials_preserved":old_ruby_preserved,"bark_meshes_preserved":bark_meshes_preserved,"source_trunk_blocks":blocks.size(),"native_blocked_tree_cells":blocked,"newly_unreachable_source_open_cells":lost,"newly_reachable_source_open_cells":gained,"visibility_qualification":"Actual renderer instances are present; fixed normal and source-aligned images check appearance separately. Canopies may occlude other source props; shore depth follows unchanged terrain/water and is a3Dadaptation."}
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-venoa-southwest-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true
 var saved=JSON.stringify(get_meta("falan_venture"))
 Tour.travel(game,Tour.Regions.layout("south_lakes"),{"arrival":local_source(Vector2(230,420)),"yaw":PI*.5,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.army_runtime.refresh_navigation(0)
 check(game.model.map_expansion==1.5,"Current map uses the existing expanded field")
 var bounds:Rect2=game.model.terrain.mask_bounds()
 check(game.world.playable_bounds.is_equal_approx(Rect2(bounds.position*game.model.falan_scale,bounds.size*game.model.falan_scale)),"Normal player bounds exclude invisible expanded-field padding")
 var material:ShaderMaterial
 var terrain_root=game.world.find_child("WindMeadowValley",true,false)
 for node in terrain_root.get_children():
  if not node is MeshInstance3D:continue
  var actual=node.get_active_material(0)
  if actual is ShaderMaterial and actual.get_shader_parameter("detail_mask")==game.model.terrain.mask_texture():material=actual;break
 check(material!=null,"Actual terrain mesh uses the selected native mask")
 if material==null:quit(1);return
 check(material.get_shader_parameter("use_native_land_visibility")==true,"Expanded background is clipped through the existing visibility owner")
 check(material.get_shader_parameter("native_visibility_bounds")==Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y),"Visibility retains the asymmetric native mask rectangle")
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/venoa_field/provenance.json"))
 var surface:MeshInstance3D=game.world.find_child("FreyjaWater",true,false)
 check(surface!=null and surface.mesh.size==Vector2(2520,1872),"Visual ocean backdrop covers original map100 width plus the preserved south rows")
 var water_material:ShaderMaterial=surface.get_active_material(0)
 check(water_material.get_shader_parameter("layout_mask")==game.model.terrain.VenoaField.OCEAN_BACKDROP,"Water plane uses the separately classified inferred ocean backdrop")
 var water_origin:Vector2=Tour.Regions.frame("south_lakes").inverse()*Vector2(-1.5,-1.5)
 var water_bounds=Vector4(water_origin.x,water_origin.y,2520,1872)*game.model.falan_scale
 check(water_material.get_shader_parameter("bounds")==water_bounds,"Water-only source bounds retain the original source frame")
 var slab=game.world.find_child("WaterWalkingGround",true,false)
 var shape:CollisionShape3D=slab.get_child(0)
 check(shape.shape.size==Vector3(bounds.size.x,.2,bounds.size.y) and Vector2(shape.position.x,shape.position.z).is_equal_approx(bounds.get_center()),"Water-walking slab stays limited to the local native rectangle")
 var outside_water=Vector3((bounds.position.x-3)*game.model.falan_scale,0,bounds.get_center().y*game.model.falan_scale)
 check(is_nan(game.world.water_support_height(outside_water)),"Full source water adds no water-walking support outside the local native mask")
 var water_evidence={"plane_size":str(surface.mesh.size),"source_water_bounds":str(water_material.get_shader_parameter("bounds")),"local_slab_size":str(shape.shape.size),"local_slab_center":str(shape.position),"outside_support_is_nan":is_nan(game.world.water_support_height(outside_water))}
 var ocean_index:Texture2D=water_material.get_shader_parameter("freyja_ground_index")
 check(ocean_index!=null and ocean_index.resource_path==game.model.terrain.VenoaField.OCEAN_INDEX_PATH,"Only the water material uses the inferred ocean index")
 if ocean_index==null:quit(1);return
 var index_image:Image=ocean_index.get_image()
 var raw_index=Image.load_from_file(game.model.terrain.VenoaField.OCEAN_INDEX_PATH)
 index_image.convert(Image.FORMAT_RGBA8);raw_index.convert(Image.FORMAT_RGBA8)
 var encoded:Array=provenance.ocean_index_encoded_water
 var encoded_color=Color8(encoded[0],encoded[1],encoded[2],encoded[3])
 var inferred_cell=Vector2i(provenance.ocean_index_first_inferred_source0_cell[0],provenance.ocean_index_first_inferred_source0_cell[1])
 check(index_image.get_size()==Vector2i(840,624) and index_image.get_data()==raw_index.get_data() and index_image.get_pixelv(inferred_cell)==encoded_color and index_image.get_pixel(0,623)==encoded_color and index_image.get_pixel(202,410)==encoded_color,"Every imported index byte is exact, including transparent placeholders; inferred ocean uses original graphic5000")
 var ground_index:Texture2D=material.get_shader_parameter("freyja_ground_index")
 check(ground_index.resource_path=="res://assets/maps/falan/freyja_ground_index.png","Native terrain keeps the unchanged canonical source index")
 water_evidence.ocean_index={"path":ocean_index.resource_path,"size":str(index_image.get_size()),"encoded_original_graphic5000":encoded,"native_ground_index":ground_index.resource_path,"all_imported_rgba_bytes_equal_png":index_image.get_data()==raw_index.get_data()}
 var native_points=[];var unreachable=[]
 for cell in provenance.new_decoder_open_cells:
  var at=game.model.world_point(local_source(Vector2(cell[0],cell[1])))
  if game.army_runtime.native.can_reach(at,at,.1):native_points.append(cell)
  else:unreachable.append(cell)
 for segment in [[Vector2(230,420),Vector2(220,420)],[Vector2(220,420),Vector2(210,420)],[Vector2(220,420),Vector2(220,438)]]:
  var a=game.model.world_point(local_source(segment[0]));var b=game.model.world_point(local_source(segment[1]))
  check(game.army_runtime.native.can_reach(a,b,.4),"Native navigation reaches the recovered strip "+str(segment))
 game.player.position=game.model.world_point(local_source(Vector2(230,420)),.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.camera_rig.yaw=PI*.5;game.camera_rig.update_camera(1.,true)
 var movement_state={"playing":game.playing,"phase":game.model.phase,"paused":game.paused,"ordinary_pause":game.ordinary_pause,
  "smoke_mode":game.player.smoke_mode,"ai_controlled":game.player.ai_controlled,"active_ability":game.player.active_ability.active,
  "player_process_mode":game.player.process_mode,"playable_bounds":str(game.world.playable_bounds),"model_bounds":str(game.model.world_bounds()),
  "layout_expansion":Tour.Regions.layout("south_lakes").get("map_expansion",1.0)}
 var movement_samples=[]
 var input_reassertions=0
 game.set_physics_process(true);game.player.set_physics_process(true)
 Input.action_press("move_forward")
 for i in 300:
  # macOS focus events may release synthetic input while another review runs.
  if not Input.is_action_pressed("move_forward"):input_reassertions+=1;Input.action_press("move_forward")
  await physics_frame
  if i in [0,1,10,30,100,200,299]:
   var collisions=[]
   for c in game.player.get_slide_collision_count():
    var hit=game.player.get_slide_collision(c);var body=hit.get_collider()
    collisions.append({"body":str(body),"name":body.name if body is Node else "","normal":str(hit.get_normal())})
   movement_samples.append({"frame":i,"source":str(source_player()),"velocity":str(game.player.velocity),"playing":game.playing,"paused":game.paused,"collisions":collisions,"input":str(Input.get_vector("move_left","move_right","move_forward","move_back"))})
  if source_player().x<=220:break
 Input.action_release("move_forward")
 for i in 4:await physics_frame
 game.set_physics_process(false);game.player.set_physics_process(false)
 var walked=source_player()
 check(game.model.falan_area=="south_lakes" and walked.x<227,"Normal movement crosses the former boundary into the same map owner")
 check(walked.x<=221 and absf(walked.y-420)<3,"Normal movement reaches the recovered land without a teleport")
 check_scenery(provenance,unreachable)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 await normal_view("southwest-seam-normal",Vector2(224,420),PI*.5)
 await normal_view("southwest-coast-normal",Vector2(210,420),PI)
 await normal_view("southwest-tip-normal",Vector2(220,438),PI*.5)
 await normal_view("southwest-flowers-normal",Vector2(215,424),PI)
 await normal_view("southwest-daisies-normal",Vector2(205,413),0.)
 await normal_view("southwest-grey-green-normal",Vector2(216,423),PI)
 await source_overview()
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Existing saved adventure data is unchanged")
 var verification_path="southwest-scenery-headless-verification.json"if DisplayServer.get_name()=="headless"else"southwest-rendered-verification.json"
 var file=FileAccess.open(REVIEW+verification_path,FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"water":water_evidence,"scenery":scenery_evidence,"walked_source":[walked.x,walked.y],"movement_state":movement_state,"movement_samples":movement_samples,"held_input_reassertions":input_reassertions,
  "source_decoder_open":provenance.new_decoder_open_cells.size(),"native_self_reachable":native_points.size(),"native_self_unreachable":unreachable,
  "source_art_anchors_still_open":maxi(0,provenance.new_source_art_anchors.size()-int(scenery_evidence.get("actual_renderer_stations",0))),"limitations":["Normal camera captures are current-only; broader map100 source-art omissions remain required work.","Native self-query radius0.1is diagnostic, not a full combat-clearance guarantee.","Reused3Dforms, shore depth and unseen surfaces are adaptations; exact source anchors and paint are verified separately."]},"  ")+"\n");file.close()
 print("VENOA_SOUTHWEST_REVIEW_RESULT checks=",checks," failures=",failures," native_self=",native_points.size(),"/",provenance.new_decoder_open_cells.size())
 game.queue_free();await process_frame;quit(1 if failures else 0)
