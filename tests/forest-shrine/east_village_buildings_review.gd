extends "res://tests/forest-shrine/east_village_props_review.gd"
## Source-fit and two connected real gameplay-camera views for each East village house type.
const Buildings=preload("res://scripts/forest/forest_east_village_buildings.gd")
const BUILD_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Buildings/"
var door_audit=[]
var placement_audit=[]

func run():
 root.size=Vector2i(1440,900);phase="VillageBuildings"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILD_OUT))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 await building_source_views()
 if "--source-only" in OS.get_cmdline_user_args():report();quit(1 if errors else 0);return
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-village-buildings-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate");await site(2000,"il_village")
 if "--visual-only" not in OS.get_cmdline_user_args():await source_contracts(2000)
 for row in [["il-house11272",Vector2i(32,31),Vector2i(44,22),Vector2i(38,25)],
  ["il-house11273",Vector2i(37,65),Vector2i(49,64),Vector2i(42,59)],
  ["il-house11275",Vector2i(28,46),Vector2i(42,44),Vector2i(35,39)]]:
  await prop_views(row[0],row[1],row[2],row[3])
 for serial in [11272,11273,11275]:
  var owner=game.world.find_child("BlueCGVillageBuilding_"+str(serial),true,false)
  check(owner!=null and owner.has_meta("source_inferred"),"Il uses isolated building owner "+str(serial))
 review_area="alyut";anchor_cells.clear()
 await open_area("north_coast");await site(2400,"alyut")
 if "--visual-only" not in OS.get_cmdline_user_args():await source_contracts(2400)
 for row in [["alyut-roundhouse11269",Vector2i(53,53),Vector2i(63,56),Vector2i(59,48)],
  ["alyut-wings11271",Vector2i(30,45),Vector2i(46,46),Vector2i(37,40)]]:
  await prop_views(row[0],row[1],row[2],row[3])
 for serial in [11269,11271,11272,11275]:
  var owner=game.world.find_child("BlueCGVillageBuilding_"+str(serial),true,false)
  check(owner!=null and owner.has_meta("source_inferred"),"Alyut uses isolated building owner "+str(serial))
 report();print("EAST_VILLAGE_BUILDINGS_RESULT checks=",checks," failures=",errors," captures=",captures.size());await finish()

func source_contracts(map_id:int):
 var source:Dictionary=Buildings.data().maps[str(map_id)]
 var joined=game.model.get_meta("joined_village")
 var source_owners=game.world.find_children("*","Node3D",true,false).filter(func(node):return node.has_meta("source_graphic"))
 for placement:Dictionary in source.placements:
  var expected=village_cell(Vector2i.ZERO)+Tour.Regions.village_transform(review_area).basis_xform(Vector2(placement.center_cell[0],placement.center_cell[1])*3.0)
  var owners=source_owners.filter(func(node):return int(node.get_meta("source_graphic"))==int(placement.graphic))
  var matches=owners.filter(func(node):return Vector2(node.global_position.x,node.global_position.z).distance_to(expected*game.model.falan_scale)<.02)
  check(matches.size()==1,"Exact original building center in actual scene: %d cell%s"%[placement.graphic,placement.cell])
  var at=Vector2(placement.center_local[0],placement.center_local[1])
  var rows=joined.falan_frontier_plan.filter(func(row):return row[0] in ["east_village_building","il_laruka_building"] and Vector2(row[1].origin.x,row[1].origin.z).is_equal_approx(at))
  var extent=Vector3(placement.collision_size[0],placement.collision_size[1],placement.collision_size[2])
  check(rows.size()==1 and rows[0][2].size.is_equal_approx(extent),"Source footprint collider retained at exact center: %d cell%s"%[placement.graphic,placement.cell])
  placement_audit.append({"map":map_id,"graphic":placement.graphic,"source_cell":placement.cell,"source_footprint":placement.footprint,"center_local":placement.center_local,"expected_world_xz":var_to_str(expected*game.model.falan_scale),"actual_owner_positions":owners.map(func(node):return var_to_str(node.global_position)),"actual_matching_owners":matches.size(),"actual_plan_rows":rows.size()})
 for door:Dictionary in source.doors:
  var at=village_cell(Vector2i(door.source_cell[0],door.source_cell[1]))
  var links=game.model.get_meta("falan_links",[]).filter(func(link):return link.get("floor",-1)==int(door.destination) and link.get("village","")==review_area)
  check(links.size()==1 and links[0].at.distance_to(at)<.01,"Live source door retains original warp cell %d %s"%[map_id,door.source_cell])
  if links.is_empty():continue
  var clear=clear_point(at)
  check(clear,"Actual source door has terrain and collider clearance: "+str(door.destination))
  var direction=approach_direction(at)
  check(direction!=Vector2.ZERO,"Original door has a clear micro-approach: "+str(door.destination))
  var entered=false;var returned=false
  if direction!=Vector2.ZERO:
   await walk_habaru_threshold(at,direction)
   entered=game.model.falan_area=="interior" and game.model.falan_floor==int(door.destination)
   check(entered,"Normal on-foot micro-approach enters original house: "+str(door.destination))
  if entered:
   var returns=game.model.get_meta("falan_links",[]).filter(func(link):return link.get("floor",-1)==map_id or int(link.get("east_source_return",{}).get("map",-1))==map_id)
   check(not returns.is_empty(),"House keeps original return link: "+str(door.destination))
   if not returns.is_empty():
    if returns[0].has("east_source_return"):
     check(Vector2i(returns[0].east_source_return.cell)==Vector2i(door.source_cell[0],door.source_cell[1]),"Return definition retains exact original outside source cell: "+str(door.destination))
    var back:Vector2=returns[0].at
    var back_direction=approach_direction(back)
    check(back_direction!=Vector2.ZERO,"Original return has clear micro-approach: "+str(door.destination))
    if back_direction!=Vector2.ZERO:await walk_habaru_threshold(back,back_direction)
    returned=Tour.area(game.model)==Tour.Regions.canonical_area(review_area)
    check(returned,"Normal on-foot return reaches the original village: "+str(door.destination))
    if returned:check(map_position().distance_to(at)<1.5,"Return retains original outside warp cell: "+str(door.destination))
  door_audit.append({"map":map_id,"source_cell":door.source_cell,"destination":door.destination,"clearance":clear,"approach":var_to_str(direction),"entered_on_foot":entered,"returned_on_foot":returned})
  if not returned:
   await open_area("east_gate" if review_area=="il_village" else "north_coast")
   await site(map_id,review_area)

func clear_point(at:Vector2)->bool:
 var p=Vector3(at.x,game.model.surface_height(at.x,at.y)+.5,at.y)
 return game.model.terrain.disk_clear(p,.55) and not game.model.scenery_obstacles.values().any(func(bounds):return bounds.grow(.55).has_point(p))

func approach_direction(at:Vector2)->Vector2:
 for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
  var clear=true
  for i in 9:
   if not clear_point(at-direction*(i*3.8/8.0)):clear=false;break
  if clear:return direction
 return Vector2.ZERO

func building_source_views():
 var viewport=SubViewport.new();viewport.size=Vector2i(800,900);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("273039")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.9;stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=.65;stage.add_child(light)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 for serial in Buildings.IDS:
  var g:Dictionary=Buildings.data().graphics[str(serial)]
  var building=Buildings.build(stage,Vector3.ZERO,serial,true)
  var aabb=building.mesh.get_aabb();var triangles=0
  for surface in building.mesh.get_surface_count():triangles+=building.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()/3
  check(building.mesh.get_surface_count()==2 and aabb.size.y>15,"Every building has complete part-painted solid and separate observed paint: "+str(serial))
  mesh_audit.append({"graphic":serial,"source_rgba_sha256":g.source_rgba_sha256,"footprint":g.footprint,"bounds":var_to_str(aabb),"triangles":triangles,"surfaces":building.mesh.get_surface_count()})
  camera.size=g.size[1]/(sqrt(2.0)*32.0/3.0)*1.12
  var target=Vector3(0,(g.center[1]-g.size[1]*.5)/Buildings.Fit.VERTICAL,0)
  for angle in 2:
   camera.position=target+(Buildings.VIEW if angle==0 else Vector3(1,1.1,-1)).normalized()*100
   camera.look_at(target);camera.current=true
   if DisplayServer.get_name()!="headless":
    for i in 6:await process_frame
    await RenderingServer.frame_post_draw
    check(viewport.get_texture().get_image().save_png(BUILD_OUT+str(serial)+("-source-axis.png" if angle==0 else "-reverse.png"))==OK,"Saved source/reverse model capture "+str(serial))
  building.queue_free();await process_frame
 viewport.queue_free();await process_frame

func report():
 var file=FileAccess.open(BUILD_OUT+("visual-review.json" if "--visual-only" in OS.get_cmdline_user_args() else "review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"captures":captures,"observations":observations,"mesh_audit":mesh_audit,
  "source_inventory":"assets/maps/falan/east_region/village_buildings/data.json",
  "placement_audit":placement_audit,"door_audit":door_audit,
  "source_axis_limit":"Isolated source camera uses the Euclidean city projection before the existing village .045world/pixel Y adaptation. Actual village normal-camera images establish playable scale.",
  "inferred_visuals":Buildings.data().inferred,
  "preserved_owners":["Original source cells/footprints and existing colliders/navigation","Existing doors/interiors/NPCs/quests/routes","Approved Chief11268 and shared civic10607","Laruka and West region art"]},"  "));file.close()
