extends "res://tests/forest-shrine/east_village_buildings_review.gd"
## Standalone2400 actual scene; host100 is never activated by this fixture.
const Context=preload("res://scripts/forest/forest_east_source_context_review.gd")
const Town=preload("res://scripts/forest/forest_east_alyut_source_context.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const TOWN_OUT=Context.ROOT+"Town Actual/"
var private_doors=[]
var native_banks=[]
var actor_positions=[]
var camera_attempts=[]
func canopy_occlusion(eye:Vector3,target:Vector3)->Array:
 var hits=[]
 for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
  var part=String(node.get_meta("crossgate_tree_part","")).to_lower()
  if not ("canopy" in part or "leaf" in part or "leaves" in part):continue
  for index in node.multimesh.instance_count:
   var box:AABB=node.global_transform*(node.multimesh.get_instance_transform(index)*node.multimesh.mesh.get_aabb())
   if box.has_point(eye) or box.intersects_segment(eye,target)!=null:hits.append({"node":str(node.get_path()),"instance":index,"bounds":var_to_str(box)})
 return hits
func prop_views(label:String,preferred:Vector2i,other:Vector2i,target:Vector2i):
 var first=Vector2i(-1,-1)
 for angle in 2:
  var seed=walkable_anchor(preferred if angle==0 else other);var chosen=seed;var found=false
  for distance in 5:
   for dy in range(-distance,distance+1):
    for dx in range(-distance,distance+1):
     if maxi(absi(dx),absi(dy))!=distance:continue
     var cell=seed+Vector2i(dx,dy)
     if not open_cell(cell):continue
     if angle==1 and (not connected_anchors(first,cell) or (Town.point(target)-Town.point(first)).normalized().dot((Town.point(target)-Town.point(cell)).normalized())>.95):continue
     await position_at(Town.point(cell));var facing=(Town.point(target)-Town.point(cell)).normalized()
     game.camera_rig.yaw=atan2(-facing.x,-facing.y);game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
     for i in 5:await physics_frame;game.camera_rig.update_camera(1./60.)
     var clear=game.camera_rig.current_distance>game.camera_rig.unobstructed_distance*.8
     var focus=game.model.world_point(Town.point(target))+Vector3.UP*2.;var framed=game.camera_rig.camera.is_position_in_frustum(focus)
     var canopy=canopy_occlusion(game.camera_rig.camera.global_position,focus)
     camera_attempts.append({"label":label,"angle":angle,"source_cell":var_to_str(cell),"distance":game.camera_rig.current_distance,"desired":game.camera_rig.unobstructed_distance,"clear":clear,"target_framed":framed,"canopy_occluders":canopy})
     if clear and framed and canopy.is_empty():chosen=cell;found=true;break
    if found:break
   if found:break
  check(found,"A source-open/native-clear nearby stand retains the actual camera guard "+label+" angle"+str(angle))
  if angle==0:first=chosen
  await position_at(Town.point(chosen));var facing=(Town.point(target)-Town.point(chosen)).normalized()
  await gameplay_capture(label+("-normal" if angle==0 else "-second"),"Native-connected original source stand; no camera/nav/physics relaxation",atan2(-facing.x,-facing.y))
func gameplay_capture(label:String,method:String,yaw:float):
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
 for i in 18:
  await physics_frame;game.camera_rig.update_camera(1./60.)
 var desired:float=game.camera_rig.unobstructed_distance;var actual:float=game.camera_rig.current_distance
 check(actual>desired*.8,"Private Town gameplay camera retains80percent of ordinary follow distance "+label)
 observations.append({"capture":label,"camera_actual":actual,"camera_desired":desired,"pitch":.32,"source_cell":var_to_str(Vector2i(((map_position()+Vector2(150,150))/3.).round()))})
 var camera:Camera3D=game.camera_rig.camera
 await fixed_capture(label,camera.global_position,camera.global_position-camera.global_basis.z*10.,method)
func village_cell(cell:Vector2i)->Vector2:return Town.point(cell)
func open_cell(cell:Vector2i)->bool:
 if not Full.source_open(cell):return false
 var at=Town.point(cell);return clear_point(at)
func enter_town(cell:Vector2i=Vector2i(58,32)):
 Tour.travel(game,Tour.Regions.layout("alyut"),{"arrival":Town.point(cell),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 check(game.model.falan_area=="alyut" and Town.owns(game.model),"Private source2400 stays standalone with its prepared owner")
 check(map_position().distance_to(Town.point(cell))<.03,"Town direct arrival retains exact original source cell "+str(cell))
func run():
 root.size=Vector2i(1440,900);phase="SeparateAlyut2400";review_area="alyut"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TOWN_OUT));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 var paths=[get_script().resource_path.trim_prefix("res://"),"tests/forest-shrine/east_village_buildings_review.gd","tests/forest-shrine/east_village_props_review.gd","tests/forest-shrine/il_chief_review.gd","tests/forest-shrine/east_region_review.gd","tests/forest-shrine/freyja_villages_habaru_test.gd","scripts/forest/forest_east_source_context_review.gd","scripts/forest/forest_east_alyut_source_context.gd","scripts/forest/forest_east_il_low_source.gd","scripts/forest/forest_model.gd","scripts/forest/crowd/army_runtime.gd","scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_freyja_art.gd","scripts/forest/forest_east_region.gd","scripts/forest/forest_east_events.gd","scripts/forest/forest_falan_tour.gd","scripts/forest/forest_falan_frontier.gd","scripts/forest/forest_east_alyut_source_completion.gd","scripts/forest/forest_east_village_buildings.gd","scripts/forest/forest_world.gd","scripts/forest/forest_game.gd","scripts/forest/forest_original_maps.gd","assets/maps/freyja_west_gate/water.gdshader","scripts/forest/wind_meadow_ground.gdshader","scripts/forest/freyja_surface.gdshaderinc",String(Context.ROOT+"alyut2400-data.json").trim_prefix("res://"),String(Context.ROOT+"alyut2400-mask.png").trim_prefix("res://"),"assets/maps/falan/east_region/alyut_source_completion/hybrid-map.bin","assets/maps/falan/east_region/alyut_source_completion/map-data.json","assets/maps/falan/east_region/alyut_source_completion/banks.json","assets/maps/falan/east_region/routes.json","assets/maps/falan/east_region/population.json","assets/maps/falan/east_region/bank_caps/data.json"]
 paths.append_array(["scripts/forest/crowd/east_region_sprites.gd","scripts/forest/forest_east_il_source_completion.gd","scripts/forest/forest_il_laruka_art.gd","scripts/forest/forest_rampart_art.gd","scripts/forest/forest_east_harbor.gd","scripts/forest/forest_wind_meadow_art.gd","scripts/forest/forest_village_vista.gd"])
 var before=Fresh.snapshot(paths)
 check(Tour.Regions.private_source_context==null,"Private context starts disabled")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-separate-town-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 Context.reset();Tour.Regions.private_source_context=Context
 check(not Context.host_ready(),"This bounded Town run cannot activate an incomplete source100 host")
 await enter_town()
 await scene_contracts()
 await native_bank_contracts()
 if "--visual-only" not in OS.get_cmdline_user_args():
  await houses()
  await housing_return()
 await enter_town(Vector2i(47,18))
 await prop_views("separate-town-shore",Vector2i(39,13),Vector2i(47,18),Vector2i(43,7))
 await prop_views("separate-town-close-bank",Vector2i(66,18),Vector2i(61,16),Vector2i(63,14))
 await prop_views("separate-town-house",Vector2i(53,53),Vector2i(54,43),Vector2i(59,48))
 var changed=Fresh.changed(before);check(changed.is_empty(),"Actual private Town source inputs remain current")
 # Release the scene before relinquishing only this fixture's private cache ownership.
 game.queue_free();for i in 4:await process_frame
 Tour.Regions.private_source_context=null;Context.reset()
 check(Tour.Regions.private_source_context==null and Context.host_owner==null,"Private context and delegates are disabled at teardown")
 var file=FileAccess.open(TOWN_OUT+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"doors":private_doors,"bank_native_probes":native_banks,"actors":actor_positions,"camera_attempts":camera_attempts,"source_hashes":before,"source_changed_during_run":changed,"prior_unchanged_route_proof":TOWN_OUT+"Review01/review.json" if "--visual-only" in OS.get_cmdline_user_args() else "","scope":"PRIVATE standalone2400 actual scene/native bank adjacencies/material/source/frame assertions. Five house enter/returns and2800return are retained separately when this is a visual-only refresh; the14thhook changes only inherited visual dressing. Source100host, eight cross-map transfers/tide entrances remain separate unfinished proof; no canonical activation or whole-village visual acceptance."}," "));file.close()
 print("EAST_SOURCE_CONTEXT_TOWN checks=",checks," failures=",errors," captures=",captures.size());quit(1 if errors else 0)
func scene_contracts():
 check(game.world.find_child("VillageCountrysideView",true,false)==null,"Private Town excludes the distinct source100 countryside vista")
 check(game.world.find_children("terraced_mountain_*","MultiMeshInstance3D",true,false).is_empty(),"Private Town excludes inherited generic meadow mountain rows")
 check(not game.model.has_meta("joined_village"),"Standalone Town has no joined field/village view")
 check(Region.current_source(game.model,Town.point(Vector2i(20,23)))==2400,"Town logical source remains2400 even where original100 has a separate tide entrance")
 var water=game.world.find_child("FreyjaWater",true,false) as MeshInstance3D
 check(water!=null,"Actual scene contains its owned source water surface")
 if water!=null:
  var material:ShaderMaterial=water.material_override;var backing:Texture2D=material.get_shader_parameter("layout_mask")
  check(material.get_meta("source_private_water_map",-1)==2400 and material.get_shader_parameter("island")==false,"Actual water uses the private source-only material adapter")
  check(backing.get_meta("source_bank_water_cells",[]).size()==117 and backing.get_meta("source_water_neighbors",[]).size()==82,"Actual water keeps117bank backings and82original water neighbors")
  check(water.mesh.size==Vector2(300,300),"Actual water mesh stays inside the source100×100 frame")
 for cell in [Vector2i(58,28),Vector2i(59,29),Vector2i(66,61),Vector2i(67,63),Vector2i(32,3),Vector2i(33,4),Vector2i(34,4)]:
  check(not Full.source_open(cell) and not game.army_runtime.native.ally_ground_clear(game.model.world_point(Town.point(cell)),.25),"Original native-closed buffer/overlap remains closed in Town "+str(cell))
 var field_flowers=[]
 for node in game.world.map_features.find_children("*","Node3D",true,false):
  if node.has_meta("source100_overlap_graphics"):field_flowers.append(node)
 check(field_flowers.is_empty(),"Original100 overlap flower is absent from separate2400")
 for actor:Dictionary in Region.residents().actors:
  if int(actor.source)!=2400:continue
  if str(actor.type).to_lower()=="housewarp2":
   check(Region.source_actors.has(str(actor.id)) and actor.inline_args=="1|2800","Invisible HouseWarp2 retains its exact original program and explicit unknown incoming landing")
   actor_positions.append({"id":actor.id,"cell":actor.cell,"type":actor.type,"disposition":"Original invisible dynamic-house entry retained; incoming coordinate is absent from raw handler, not invented. Original2800return is checked separately."});continue
  var matches=[]
  for sprite:Sprite3D in game.world.map_features.find_children("*","Sprite3D",true,false):
   if str(sprite.get_meta("npc_record",{}).get("id",""))==str(actor.id):matches.append(sprite)
  var expected=Town.point(Vector2i(actor.cell[0],actor.cell[1]))*game.model.falan_scale
  var correct=matches.any(func(sprite):return Vector2(sprite.global_position.x,sprite.global_position.z).distance_to(expected)<.02)
  check(correct,"Source2400 actor retains exact source position "+str(actor.id));actor_positions.append({"id":actor.id,"cell":actor.cell,"matches":matches.size(),"position_correct":correct,"type":actor.type})
func native_bank_contracts():
 var bits=Marshalls.base64_to_raw(Town.data().walk_bits)
 for row:Dictionary in Town.data().banks:
  var cell=Vector2i(row.source_cell[0],row.source_cell[1]);var at=Town.point(cell);var center=game.model.world_point(at)
  check(game.army_runtime.native.ally_ground_clear(center,.60),"Actual native Town bank anchor clears original source cell "+str(cell))
  for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
   var other=cell+step
   if not Rect2i(0,0,100,100).has_point(other):continue
   var index=other.y*100+other.x
   if not bool(bits[index>>3]&(1<<(index&7))):continue
   var end=game.model.world_point(Town.point(other));var clear=true
   for sample in 13:
    var p=center.lerp(end,sample/12.)
    for radius in [.25,.49679,.60]:clear=clear and game.army_runtime.native.ally_ground_clear(p,radius)
   check(clear,"Actual native Town bank adjacency "+str(cell)+"→"+str(other));native_banks.append({"a":var_to_str(cell),"b":var_to_str(other),"clear":clear})
 check(native_banks.size()==351,"All351original native-open bank adjacencies are checked in the actual scene")
func houses():
 for row in [[48,37,2420],[37,44,2401],[31,54,2421],[52,63,2410],[56,48,2412]]:
  if game.model.falan_area!="alyut":await enter_town()
  var cell=Vector2i(row[0],row[1]);var at=Town.point(cell);var target=int(row[2]);var direction=approach_direction(at);var entered=false;var returned=false
  check(clear_point(at) and direction!=Vector2.ZERO,"Original house door has an actual clear micro-approach "+str(target))
  if direction!=Vector2.ZERO:await walk_habaru_threshold(at,direction)
  entered=game.model.falan_area=="interior" and game.model.falan_floor==Tour.Winter.Recovered.runtime_id(target)
  check(entered,"Normal player movement enters original house "+str(target))
  if entered:
   var returns=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("east_source_return",{}).get("map",-1))==2400)
   check(not returns.is_empty(),"House retains original source2400return "+str(target))
   if not returns.is_empty():
    check(Vector2i(returns[0].east_source_return.cell)==cell,"House return definition uses exact original source cell "+str(target))
    var back:Vector2=returns[0].at;var reverse=approach_direction(back)
    if reverse!=Vector2.ZERO:await walk_habaru_threshold(back,reverse)
    returned=game.model.falan_area=="alyut" and map_position().distance_to(at)<.04
   check(returned,"Normal player return preserves exact standalone Town cell "+str(target))
  private_doors.append({"source_cell":var_to_str(cell),"destination":target,"entered_on_foot":entered,"returned_on_foot":returned})
func housing_return():
 var maps=Tour.Winter.Recovered;var id=maps.runtime_id(2800)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Region.source_point(2800,Vector2i(10,16)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 var returns=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("east_source_return",{}).get("map",-1))==2400)
 check(returns.any(func(link):return Vector2i(link.east_source_return.cell)==Vector2i(37,71)),"Original2800return keeps2400(37,71)")
 if returns.is_empty():return
 var direction=approach_direction(returns[0].at)
 if direction!=Vector2.ZERO:await walk_habaru_threshold(returns[0].at,direction)
 check(game.model.falan_area=="alyut" and map_position().distance_to(Town.point(Vector2i(37,71)))<.04,"Original2800return reaches exact standalone2400cell without invented incoming landing")
