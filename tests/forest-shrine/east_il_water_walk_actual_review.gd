extends "res://tests/forest-shrine/east_il_source_completion_review.gd"
## Process-only full shore/water trial; no production integration or app export.
const CandidateField=preload("res://scripts/forest/forest_east_il_water_terrain.gd")
const WaterFloors=preload("res://scripts/forest/forest_east_il_water_walk.gd")
const WholeShore=preload("res://scripts/forest/forest_east_il_bank_closure.gd")
const Underlay=preload("res://scripts/forest/forest_east_bank_underlay.gd")
const GradeArt=preload("res://scripts/forest/forest_east_il_water_grade_art.gd")
const WaterEdges=preload("res://scripts/forest/forest_east_il_water_boundaries.gd")
const CANDIDATE="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Water Walk Candidate/"
const SHORE_DATA="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate/banks.json"
var candidate_data:Dictionary
var candidate_rows=[]
var edge_rows=[]

func run():
 root.size=Vector2i(1440,900);phase="IlWaterWalkPrivate";review_area="il_village"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 var paths=["scripts/player.gd","scripts/forest/crowd/army_coordinator.gd","scripts/forest/forest_model.gd","scripts/forest/forest_world.gd","scripts/forest/forest_falan_frontier.gd","scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_freyja_art.gd","scripts/forest/forest_east_road.gd","scripts/forest/forest_rampart_art.gd","scripts/forest/forest_falan_fort_parts.gd","scripts/forest/forest_east_il_source_completion.gd","scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_east_bank_underlay.gd","scripts/forest/forest_east_il_bank_closure.gd","scripts/forest/forest_east_il_water_terrain.gd","scripts/forest/forest_east_il_water_walk.gd","scripts/forest/forest_east_il_water_grade_art.gd","scripts/forest/forest_east_il_water_boundaries.gd","scripts/forest/forest_original_water_camera.gd","scripts/forest/crowd/army_runtime.gd","native/terrain_math/crowd/terrain.cpp","native/terrain_math/crowd/terrain.h","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib",CANDIDATE+"data.json",CANDIDATE+"water-boundaries.json",SHORE_DATA,"assets/maps/falan/east_region/bank_caps/data.json","assets/maps/falan/east_region/bank_caps/surfaces.png","assets/maps/falan/east_region/il_source_completion/data.json","assets/maps/falan/east_region/il_source_completion/hybrid-map.bin","assets/maps/falan/east_region/il_source_completion/mask.png","assets/maps/falan/east_region/il_source_completion/ground-index.png","assets/maps/falan/east_region/routes.json","assets/maps/falan/east_region/population.json"]
 var script:Script=get_script()
 paths.append_array(["scripts/forest/forest_original_maps.gd","scripts/forest/forest_falan_tour.gd","scripts/forest/forest_il_laruka_art.gd","scripts/forest/forest_freyja_residual_art.gd"])
 while script!=null:paths.append(script.resource_path);script=script.get_base_script()
 for serial in range(12500,12536):paths.append(BankCaps.ROOT+str(serial)+"-front.png")
 var before=Fresh.snapshot(paths);candidate_data=JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE+"data.json"))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-il-water-walk-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 game.settings.forest_pet_loadout=[]
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate");await site(2000,"il_village")
 await prepare_private_world()
 await all_source_water_contracts()
 for ramp:Dictionary in candidate_data.ramps:await actual_water_entry(ramp)
 await blocked_water_player()
 var changed=Fresh.changed(before);check(changed.is_empty(),"Loaded private Il shore/water owners stayed current")
 var file=FileAccess.open(CANDIDATE+"actual-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"source_hashes":before,"source_changed_during_run":changed,"observations":observations,"captures":captures,"shore_measurements":shore_audit,"source_counts":candidate_data.counts,"player_water_boundary_runs":edge_rows.size(),"scope":"PRIVATE process-only candidate.393native shore drawings/389openbank supports/4visual-only blocked controls;242source252waterfloors2m;3inferred entry grades replace six hidden source-open underlay vertices; original3mroute grid explicit. Original source bytes/actor/doors/events stay unchanged. No live integration and no full143direct bank-contact parity claim."},"  "));file.close()
 print("EAST_IL_WATER_WALK_ACTUAL checks=",checks," failures=",errors," captures=",captures.size());await finish()

func copied_field(old,frame:Transform2D):
 var result=CandidateField.new();result.variant=old.variant;result.horizontal_scale=old.horizontal_scale;result.expansion=old.expansion;result.raised_castle=old.raised_castle;result.configure([])
 result.pieces=old.pieces.duplicate(true);result.height_buckets=old.height_buckets.duplicate(true);result.maximum_height=old.maximum_height
 for key in old.get_meta_list():result.set_meta(key,old.get_meta(key))
 var covered=old.covered.duplicate();var source_heights=old.terrain_field().get_meta("heights").duplicate()
 var changes=result.apply_grade(candidate_data,frame)
 var rows=WaterFloors.bank_rows(SHORE_DATA,candidate_data,frame);WholeShore.append_supports(result,rows);WaterFloors.append_supports(result,candidate_data,frame)
 check(result.covered==covered and old.terrain_field().get_meta("heights")==source_heights,"Private copied field preserves shared source heights/covered "+old.variant)
 observations.append({"private_field":old.variant,"height_changes":changes,"source_pieces_before":old.pieces.size(),"candidate_pieces":result.pieces.size()})
 return result

func prepare_private_world():
 var old=game.model.terrain;var frame=Tour.Regions.village_transform("il_village");var old_mesh=old.mesh();var candidate=copied_field(old,frame)
 game.model.terrain=candidate
 var joined=game.model.get_meta("joined_village");joined.terrain=copied_field(joined.terrain,Transform2D.IDENTITY)
 var ground:ShaderMaterial;var ground_count=0;var collider_count=0
 for node:MeshInstance3D in game.world.find_children("*","MeshInstance3D",true,false):
  if node.mesh==old_mesh:node.mesh=candidate.mesh();ground=node.material_override;ground_count+=1
 for body:StaticBody3D in game.world.find_children("ValleyTerrainCollision","StaticBody3D",true,false):
  for shape:CollisionShape3D in body.get_children():shape.shape=candidate.collision();collider_count+=1
 check(ground_count==1 and collider_count==1 and ground!=null,"Private copied terrain replaces exactly one visible/physical main ground")
 if ground==null:return
 var village:Node3D=game.world.find_child("Connected_il_village",true,false)
 check(village!=null,"Original joined Il owner is retained")
 if village==null:return
 var hidden=0
 for node:MultiMeshInstance3D in village.find_children("*","MultiMeshInstance3D",true,false):
  if int(node.get_meta("source_graphic",0)) in range(12500,12536):node.visible=false;hidden+=node.multimesh.instance_count
 for node:MeshInstance3D in village.find_children("NativeKnownLandBankSeams","MeshInstance3D",true,false):node.visible=false
 for body:StaticBody3D in village.find_children("*","StaticBody3D",true,false):
  if body.has_meta("native_bank_cap"):body.queue_free()
 check(hidden==393,"Exactly393old source-bank drawings are privately replaced")
 var owner=Node3D.new();owner.name="PrivateIlShoreAndWater";village.add_child(owner)
 candidate_rows=WaterFloors.bank_rows(SHORE_DATA,candidate_data);WholeShore.build(owner,candidate_rows);WaterFloors.build_floors(owner,candidate_data);GradeArt.build(owner,candidate_data,ground)
 var shore:Dictionary=WholeShore.data(SHORE_DATA);var cuts=[]
 for row:Dictionary in shore.underlay_source_water_neighbors:cuts.append({"anchor":frame*Vector2(row.anchor[0],row.anchor[1]),"source_cell":Vector2i(row.source_cell[0],row.source_cell[1]),"source_bg":int(row.source_bg)})
 check(ground.get_shader_parameter("use_native_land_visibility")!=true,"Il trial does not replace another enabled visual-visibility owner")
 var settings=Underlay.settings(Underlay.visual_bounds(candidate.mesh()),WaterFloors.bank_rows(SHORE_DATA,candidate_data,frame),cuts)
 for key in settings:ground.set_shader_parameter(key,settings[key])
 var boundary:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE+"water-boundaries.json"));var raw=FileAccess.get_file_as_bytes(IlSource.ROOT+"hybrid-map.bin");var bits=Marshalls.base64_to_raw(IlSource.data().native_walk.after_bits)
 edge_rows=WaterEdges.build(owner,game.world.map_features,boundary,raw,bits)
 var pose=Transform3D(Basis(Vector3.UP,-frame.get_rotation()),Vector3(frame.origin.x,0,frame.origin.y));var index=1000000
 for row:Dictionary in edge_rows:game.model.register_archive_obstacle(pose*row.bounds,index);index+=1
 game.camera_rig.water_camera._initialized=false
 game.army_runtime.static_collision_cache.clear()
 var nav:Dictionary=game.army_runtime.navigation_data(game.model,true);nav.route_spacing=3.*game.model.falan_scale
 # Keep the model revision: the ordinary coordinator would replace a made-up
 # revision on its next tick and silently lose this private3m route spacing.
 game.army_runtime.navigation_revision=-1
 game.army_runtime.set_navigation(game.model.navigation_revision,nav)
 var friendly=nav.duplicate();friendly.obstacle_min=friendly.friendly_obstacle_min;friendly.obstacle_max=friendly.friendly_obstacle_max;friendly.friendly_navigation=false
 allied_probe=ClassDB.instantiate("GoemonCrowdRuntime");allied_probe.set_navigation(friendly)
 for i in 4:await physics_frame
 check(game.army_runtime.navigation_revision==game.model.navigation_revision,"Private navigation keeps the existing model revision through normal ticks")
 observations.append({"source_bank_visual_replacements":hidden,"water_floor_count":242,"inferred_entry_count":3,"underlay_source_water_cuts":cuts.size(),"boundary_runs":edge_rows.size(),"private_route_spacing_world":nav.route_spacing,"canonical_runtime_changed":false})

func all_source_water_contracts():
 var scale_:float=game.model.falan_scale
 for row:Dictionary in candidate_data.water_rows:
  var cell=Vector2i(row.source_cell[0],row.source_cell[1]);var point=village_cell(cell);var world=game.model.world_point(point)
  check(IlSource.source_open(cell),"Recovered water control was original-open "+str(cell))
  check(absf(world.y-2.*scale_)<.02,"Actual model water foot remains at visible water2m "+str(cell))
  for radius in [.25,.35,.4967896938,.60]:
   check(game.army_runtime.native.ally_ground_clear(world,radius),"Actual native source water clears radius%s cell%s"%[radius,cell])
   var reachable=false
   for ramp:Dictionary in candidate_data.ramps:
    var last:Array=ramp.source_run_cells[-1];var start=game.model.world_point(village_cell(Vector2i(last[0],last[1])))
    if allied_probe.can_reach(start,world,radius):reachable=true;break
   check(reachable,"Actual friendly candidate route reaches source water radius%s cell%s"%[radius,cell])
 for cell in [Vector2i(57,56),Vector2i(58,56),Vector2i(75,75),Vector2i(53,86)]:
  var world=game.model.world_point(village_cell(cell));check(not IlSource.source_open(cell) and not game.army_runtime.native.ally_ground_clear(world,.25),"Original blocked shore control remains native-closed "+str(cell))

func actual_water_entry(ramp:Dictionary):
 var bank=Vector2i(ramp.source_bank_cell[0],ramp.source_bank_cell[1]);var last:Array=ramp.source_run_cells[-1];var start=Vector2i(last[0],last[1]);var water=Vector2i(ramp.source_water_cell[0],ramp.source_water_cell[1]);var direction=Vector2(ramp.direction[0],ramp.direction[1])
 await position_at(village_cell(start))
 for i in 24:await physics_frame
 var pet=await bank_pet()
 for cell in [bank,water]:
  var samples=await walk_bank_point(village_cell(cell),"Il252 entry"+str(bank)+" to"+str(cell));shore_audit.append({"entry_bank":str(bank),"waypoint":str(cell),"player_samples":samples})
  if not pet.is_empty():await command_bank_pet(pet,village_cell(cell),"Il252 entry"+str(bank)+" to"+str(cell))
 await water_camera("il252-water-entry-"+str(bank.x)+"-"+str(bank.y)+"-normal",water,start)
 await walk_bank_point(village_cell(bank),"Il252 return bank"+str(bank));await walk_bank_point(village_cell(start),"Il252 ascent return"+str(bank))
 if not pet.is_empty():
  var return_initial:Dictionary=game.army_runtime.unit_state(pet.handle)
  check(game.army_runtime.order_hounds(game.army_runtime.HoundOrder.RETURN),"Normal RETURN recalls the native pet from source water")
  for i in 360:
   await physics_frame
   var state:Dictionary=game.army_runtime.unit_state(pet.handle)
   if not state.is_empty() and absf(state.position.y-game.player.position.y)<.15 and Vector2(state.position.x-game.player.position.x,state.position.z-game.player.position.z).length()<16.:break
  var state:Dictionary=game.army_runtime.unit_state(pet.handle)
  var returned=not state.is_empty() and absf(state.position.y-game.player.position.y)<.15 and Vector2(state.position.x-game.player.position.x,state.position.z-game.player.position.z).length()<16.
  check(returned,"Native pet returns up the inferred grade to original dryland near its normal formation")
  if not state.is_empty():
   var local=Tour.Regions.village_transform("il_village").inverse()*(Vector2(state.position.x,state.position.z)/game.model.falan_scale)
   var cell=Vector2i((local/3.+Vector2(45,60)).round())
   check(IlSource.source_open(cell) and game.army_runtime.native.ally_ground_clear(state.position,float(pet.radius)),"Returned native pet occupies an original-open clear source cell")
   observations.append({"entry_bank":str(bank),"pet_radius":pet.radius,"normal_return_initial":str(return_initial.get("position",Vector3.INF)),"normal_return_final":str(state.position),"return_source_cell":str(cell),"approach_samples":pet.get("approach_samples",[])})
 await water_camera("il252-water-entry-"+str(bank.x)+"-"+str(bank.y)+"-second",start,water)
 if not pet.is_empty():
  game.army_runtime.despawn(pet.handle);game.settings.forest_pet_loadout=[]

func walk_bank_point(target:Vector2,label:String)->Array:
 var samples=[];var budget=ceili(target.distance_to(map_position())*game.model.falan_scale/2.2*60.)+180
 Input.action_press("walk_modifier")
 for i in budget:
  var delta=target-map_position()
  if delta.length()<.055:break
  game.camera_rig.yaw=atan2(-delta.x,-delta.y);game.camera_rig.update_camera(1./60.)
  Input.action_press("move_forward");await physics_frame
  if i%3==0:
   var sample={"position":var_to_str(game.player.position),"on_floor":game.player.is_on_floor(),"model_y":game.model.world_height(game.player.position.x,game.player.position.z)}
   if not sample.on_floor or absf(game.player.position.y-float(sample.model_y))>=.4:
    var contacts=[]
    for index in game.player.get_slide_collision_count():
     var hit:KinematicCollision3D=game.player.get_slide_collision(index);var collider=hit.get_collider()
     contacts.append({"collider":str(collider.get_path()) if collider is Node else str(collider),"point":str(hit.get_position()),"normal":str(hit.get_normal())})
    sample.contacts=contacts;sample.velocity=str(game.player.velocity)
   samples.append(sample)
 Input.action_release("move_forward");Input.action_release("walk_modifier")
 for i in 16:await physics_frame
 check(map_position().distance_to(target)<.25,"Actual directional movement reaches source-bank waypoint "+label)
 check(samples.all(func(p):return p.on_floor and absf(str_to_var(p.position).y-float(p.model_y))<.4),"Actual player feet remain supported along the bank approach "+label)
 return samples

func water_camera(label:String,stand:Vector2i,target:Vector2i):
 check(IlSource.source_open(stand),"Private water camera uses an original-open stand")
 await position_at(village_cell(stand));var toward=(village_cell(target)-village_cell(stand)).normalized();var yaw=atan2(-toward.x,-toward.y)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
 for i in 24:await physics_frame;game.camera_rig.update_camera(1./60.)
 check(game.camera_rig.current_distance>game.camera_rig.unobstructed_distance*.8,"Source-water view retains ordinary follow distance")
 observations.append({"source_water_view":label,"stand":str(stand),"target":str(target),"actual_foot_world":str(game.player.position),"camera_distance":game.camera_rig.current_distance,"desired_distance":game.camera_rig.unobstructed_distance})
 await gameplay_capture(label,"Private actual source-connected water2m/graded-ground view; source and inferred heights distinguished",yaw)

func blocked_water_player():
 for row:Dictionary in edge_rows:
  var source:Dictionary=row.source_edge
  if not source.camera_plain_water_eligible:continue
  var column=int((int(source.start)+int(source.end)-1)/2);var a=Vector2i(column,int(source.row)-1) if source.along_x else Vector2i(int(source.row)-1,column);var b=a+(Vector2i.DOWN if source.along_x else Vector2i.RIGHT)
  var open=a if source.blocked_positive else b;var closed=b if source.blocked_positive else a
  if not candidate_data.water_rows.any(func(w):return Vector2i(w.source_cell[0],w.source_cell[1])==open):continue
  await position_at(village_cell(open));var direction=(village_cell(closed)-village_cell(open)).normalized();game.camera_rig.yaw=atan2(-direction.x,-direction.y)
  Input.action_press("walk_modifier");Input.action_press("move_forward")
  for i in 75:await physics_frame
  Input.action_release("move_forward");Input.action_release("walk_modifier")
  check((map_position()-village_cell(open)).dot(direction)<1.5,"Actual player cannot cross an original blocked-water edge")
  observations.append({"blocked_water_player_open":str(open),"closed":str(closed),"actual_position":str(game.player.position),"native_blocked_closed":not game.army_runtime.native.ally_ground_clear(game.model.world_point(village_cell(closed)),.25)})
  return
 check(false,"Found an original252-to-plain-blocked-water player boundary test")
