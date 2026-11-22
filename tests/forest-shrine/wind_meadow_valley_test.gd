extends SceneTree
const Document=preload("res://tests/forest-shrine/reference/map_document.gd")
var failures=0
var checks=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var document=Document.new();var error=document.load_valley();check(error.is_empty(),"Bundled valley validates: "+error)
 if not error.is_empty():quit(1);return
 var model=preload("res://scripts/forest/forest_model.gd").new();model.reset(42,{},document.data,false)
 check(model.terrain_source=="wind_meadow" and model.has_enemy_camps() and not model.enemy_camps_prototype,"Valley uses production terrain and camp contracts")
 check(model.portals.size()==4 and model.active_enemy_camps()==4 and model.enemy_statue.is_empty(),"Four cardinal castles are the only enemy objectives")
 check(model.has_enemy_castles() and model.navigation_region.size==Vector2i(160,160),"The playable map has four times the ground area")
 var old=document.data.duplicate(true);old.terrain_scale=1.0;old.trees=[];old.roads=[];old.erase("raised_castle")
 for i in 4:
  old.portals[i].x=int(preload("res://scripts/forest/forest_wind_meadow_layout.gd").CLEARINGS[i].x/6);old.portals[i].z=int(preload("res://scripts/forest/forest_wind_meadow_layout.gd").CLEARINGS[i].z/6)
 var legacy=preload("res://scripts/forest/forest_model.gd").new();legacy.reset(42,{},old,false)
 check(not legacy.has_enemy_castles() and legacy.terrain.width==161 and legacy.portals[0].spawn_distance==24,"Earlier saved valleys retain their original terrain and barracks")
 check(Document.validate(old).is_empty(),"Earlier valley maps still validate")
 check(model.waves.active_cap()==240,"Normal native army cap stays unchanged")
 check(document.data.buildings.is_empty() and model.buildings.size()==1 and model.shrine().kind=="shrine","The bundled opening contains only the Goemon statue")
 check(model.center(model.shrine()).is_equal_approx(Vector3.ZERO),"The statue is centered on the valley floor")
 var field=preload("res://scripts/forest/crowd/army_runtime.gd").navigation_data(model)
 check(field.width==321 and field.origin==Vector3(-480,0,-480) and field.heights==model.terrain.heights,"Native armies borrow the same baked terrain")
 model.waves.navigation.terrain_corridors._refresh(model)
 check(model.waves.navigation.terrain_corridors.native_sampler!=null,"Valley retains native accelerated corridor queries")
 var layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
 for route in layout.routes(model.terrain_scale):
  for i in range(1,route.size()):
   for step in 21:
    var point:Vector2=route[i-1].lerp(route[i],step/20.0)
    check(model.terrain.disk_clear(Vector3(point.x,0,point.y),3.9),"Wide route has continuous traversable support at "+str(point))
 for i in 4:
  var camp:Dictionary=model.portals[i];var p=model.point(Vector2i(camp.x,camp.z))
  check(Vector2(p.x,p.z)==Vector2(layout.clearings(model.terrain_scale)[i].x,layout.clearings(model.terrain_scale)[i].z) and is_equal_approx(Vector2(p.x,p.z).length(),372),"Each enemy castle retains its clearing 372 metres from the shrine")
  check(is_equal_approx(p.y,layout.clearings(model.terrain_scale)[i].y),"Each castle sits on its distinct clearing height")
  for x in [-51,0,51]:
   for z in [-39,0,39]:
    check(is_equal_approx(model.surface_height(p.x+x,p.z+z),p.y),"The complete castle footprint rests on level ground")
 var runtime=preload("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null);runtime.set_navigation(1,field)
 var handles=PackedInt64Array();var goals=PackedVector3Array();var speeds=PackedFloat32Array()
 for i in 4:
  var p:Vector3=model.waves.routes.exit_point(model.portals[i],0);p.y=model.surface_height(p.x,p.z)
  var goal:Vector3=[Vector3(-3,0,-60),Vector3(60,0,-3),Vector3(3,0,60),Vector3(-60,0,3)][i];goal.y=model.surface_height(goal.x,goal.z)
  handles.append(runtime.spawn(1000+i,0,0,p,100,1.3));goals.append(goal);speeds.append(6)
 for tick in 12000:runtime.step(1.0/60,{"goal_handles":handles,"goal_positions":goals,"goal_speeds":speeds})
 var snapshot:Dictionary=runtime.snapshot()
 for i in handles.size():
  var at=snapshot.handles.find(handles[i]);var p:Vector3=snapshot.positions[at]
  check(p.distance_to(goals[i])<6,"Native soldiers can route from barracks %d to the shrine clearing: %s"%[i,p])
 runtime.clear();runtime.free()
 model.damage_enemy_objective(0,99999);check(model.portals[0].hp==6000,"Preparation cannot destroy objectives")
 model.waves.begin();check(model.waves.spawn_batch()>0 and model.waves.spawn_groups.size()==4 and model.waves.spawn_groups.values().all(func(group):return group.members.size()<=10),"Each cardinal camp begins its own group of ten native enemies")
 var alive=model.enemies.size()
 model.damage_enemy_objective(0,99999);check(model.active_enemy_camps()==3 and model.enemies.size()==alive,"Destruction stops a barracks without erasing living attackers")
 for i in range(1,4):model.damage_enemy_objective(i,99999)
 check(model.phase=="victory" and model.waves.spawn_batch()==0,"Destroying all four barracks wins and prevents more reinforcements")
 set_meta("forest_custom_layout",document.data)
 set_meta("forest_fighter",1);set_meta("forest_painterly_preview",true)
 var game=preload("res://scripts/forest/forest_game.gd").new();game.settings_path="user://valley-test-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 5:await process_frame
 check(game.model.terrain_source=="wind_meadow" and game.enemy_objectives.size()==4,"Normal Play opens the valley with four live objectives")
 check(game.world.base_ground_collision.collision_layer==0,"Old flat physics floor is disabled")
 check(game.world.map_features.find_child("ValleyTerrainCollision",true,false)!=null,"Baked terrain owns real collision")
 var tree_count=0;var tree_batches=0
 for batch:MultiMeshInstance3D in game.world.forest_root.find_children("*","MultiMeshInstance3D",true,false):
  if batch.get_meta("wind_meadow_canopy",false):tree_count+=batch.multimesh.instance_count;tree_batches+=1
 check(tree_count==game.model.trees.size() and tree_batches>1,"Spatial tree batches retain every authored tree")
 check(game.world.structure_nodes.size()==1 and game.world.structure_nodes.has(game.model.shrine().id),"Normal Play renders only the starting statue")
 check(game.world.playable_bounds.size==Vector2(936,936),"Player movement reaches the enlarged battlefield")
 check(game.preparation_map_frame().size==1070 and game.preparation_zoom_limits().y==1200,"Overview and zoom cover the larger map")
 for target in game.enemy_objectives:
  var castle=target.visual.get_node("EnemyCastle")
  check(target.sections.size()>50 and target.sections.filter(func(p):return p.data().kind=="tower").size()==2 and target.sections.filter(func(p):return p.data().kind=="gate").size()==1 and castle.has_node("WallBatch"),"Enemy castle retains its towers and gate with independently breakable, batched panels")
  var portal:Dictionary=target.data();var basis_=preload("res://scripts/forest/forest_enemy_castle.gd").basis(portal)
  var courtyard:Vector3=target.global_position+basis_*Vector3(-30,2,0)
  check(not target.targets.any(func(p):return p.combat_segment_hit(courtyard,courtyard+Vector3.UP,0)),"Empty castle courtyard does not receive phantom hits")
  var wall:Vector3=target.global_position+basis_*Vector3(-48,2,0)
  check(target.sections.any(func(p):return p.combat_segment_hit(wall-basis_*Vector3(7,0,0),wall+basis_*Vector3(2,0,0),0)),"Reused castle wall panels are real combat targets")
  var gate_point:Vector3=target.global_position+basis_*Vector3(-3,0,36)
  check(game.model.waves.navigation.move_clear(gate_point,1.3),"Each open castle gateway is traversable")
  check(not game.model.allied_grid.is_point_solid(game.model.cell_of(gate_point)),"Worker navigation leaves the castle gateway open")
  check(game.model.allied_grid.is_point_solid(game.model.cell_of(wall)),"Worker navigation respects the castle walls")
  var walk_from=Transform3D(game.player.basis,target.global_position+basis_*Vector3(-3,.1,50))
  check(not game.player.test_move(walk_from,basis_*Vector3(0,0,-28)),"The actual player collider fits through each raised gate")
 if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
  game.set_process(false);game.set_physics_process(false);game.camera_rig.set_process(false);game.forest_ui.hide();game.ui.hide()
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Wind Meadow/Castles/overview.png")
  var target=game.enemy_objectives[0];var cam=game.camera_rig.camera
  cam.size=155;cam.global_position=target.global_position+Vector3(100,115,140);cam.look_at(target.global_position)
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Wind Meadow/Castles/north-castle.png")
 if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
  var cam=game.camera_rig.camera
  cam.size=165;cam.global_position=Vector3(90,150,115);cam.look_at(Vector3(0,3,0))
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Wind Meadow/Castles/shrine-clearing.png")
 var targets=game.enemy_objectives.duplicate();game.start_wave()
 game.model.waves.spawn_clock=100000;game.set_physics_process(false);game.player.set_physics_process(false)
 game.tuning.critical_chance=0;game.character_tuning={}
 var north=targets[0];var player=game.player;var hp:float=north.hp
 player.position=north.position+Vector3(-53,.1,0);player.velocity=Vector3.ZERO;player.facing=Vector3.RIGHT
 player.set_auto_attack(false);player.start_attack(false,1)
 for tick in 200:player._physics_process(1.0/60.0)
 check(north.hp==hp and north.sections.any(func(p):return p.hp<p.max_hp),"Goemon's real pipe attack damages an outside panel without damaging the keep")
 player.cancel_charge(true);player.select_character(player.RogueRoster.MASTER_CHIEF_ID)
 var from:Vector3=north.position+Vector3(-65,2,0);var to:Vector3=north.position+Vector3(-40,2,0)
 var contact=player.master_chief_combat.trace(from,to)
 check(contact.target!=null and contact.target.castle_owner==north,"Actual bullet trace identifies a castle panel before physical masonry")
 for target in targets:
  target.take_hit(99999,Vector3.FORWARD,false,{"tower":true})
  check(target.dead and target.physical.collision_layer==0,"Destroyed castle releases physical collision")
  for body in target.visual.find_children("*","StaticBody3D",true,false):check(body.collision_layer==0,"Destroyed castle releases every wall and tower")
 check(game.model.phase=="victory","Actual combat target damage wins the valley")
 check(preload("res://scripts/forest/forest_camp_prototype.gd").obstacles(game.model).is_empty(),"Destroyed castles release native navigation obstacles")
 game.model.phase="preparing";game.open_map_editor();for i in 3:await process_frame
 check(game.map_editor.active and game.map_editor.document.data.title=="Wind Meadow Valley","Editor captures the valley with its correct name")
 var roundtrip=Document.new();check(roundtrip.decode(game.map_editor.document.encode()).is_empty() and roundtrip.data.terrain_source=="wind_meadow","Custom map round trip preserves the new terrain")
 preload("res://tests/forest-shrine/reference/map_document.gd").load_editor(game.map_editor,preload("res://tests/forest-shrine/reference/map_document.gd").BLOOD_GULCH_PATH);for i in 3:await process_frame
 check(game.model.terrain_source=="blood_gulch" and game.enemy_objectives.is_empty() and game.world.painterly_pilot.enabled,"Earlier map loads, restores its style and releases valley objectives")
 Document.load_editor(game.map_editor,Document.VALLEY_PATH);for i in 3:await process_frame
 check(game.model.terrain_source=="wind_meadow" and game.enemy_objectives.size()==4 and not game.world.painterly_pilot.enabled,"Valley preset restores all four barracks and their approved materials")
 game.map_editor.close_discard();for i in 3:await process_frame
 game.queue_free();for i in 3:await process_frame
 print("WIND_MEADOW_VALLEY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
