extends "res://tests/forest-shrine/east_landmark_review.gd"
const Annexes=preload("res://scripts/forest/forest_east_lektal_annexes.gd")
const ANNEX_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Lektal Annexes/"
var mesh_audit=[]

func review_path()->String:return ANNEX_OUT

func run():
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ANNEX_OUT))
 if "--actual-only" in OS.get_cmdline_user_args():
  var prior=JSON.parse_string(FileAccess.get_file_as_string(ANNEX_OUT+"review.json"))
  check(prior.source_hashes.helper==FileAccess.get_sha256("res://scripts/forest/forest_east_lektal_annexes.gd") and prior.source_hashes.data==FileAccess.get_sha256(Annexes.ROOT+"data.json"),"Retained native/reverse mesh evidence matches frozen annex source")
  mesh_audit=prior.mesh_audit
 else:await source_views()
 if "--source-only" in OS.get_cmdline_user_args():save_report();quit(1 if errors else 0);return
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-annex-review-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 var sites_=[[1233256,Vector2i(84,65),"lektal-open-porch",Vector2i(82,70),Vector2i(91,64)],
  [1233257,Vector2i(85,64),"lektal-blue-wing",Vector2i(82,70),Vector2i(91,64)]]
 for site in sites_:await actual_views(site)
 await source_doors()
 save_report();await finish()

func source_views():
 var viewport=SubViewport.new();viewport.size=Vector2i(640,640);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage)
 var environment=WorldEnvironment.new();var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("27313a")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.85
 environment.environment=settings;stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=.65;stage.add_child(light)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 for serial in Annexes.IDS:
  var g:Dictionary=Annexes.data().graphics[str(serial)];var mesh=Annexes.mesh(serial)
  check(Annexes.mesh(serial)==mesh,"Immutable annex section cached "+str(serial))
  check(mesh.get_surface_count()==2,"Observed native faces and independent closed stone material "+str(serial))
  var size_=mesh.get_aabb().size
  check(minf(size_.x,size_.z)>2 and size_.y>1,"Annex section has physical depth "+str(serial))
  var count=0;var normals=[]
  for slot in mesh.get_surface_count():
   var arrays:Array=mesh.get_meta("source_surface_arrays") if slot==0 else mesh.get_meta("annex_front_arrays")
   count+=arrays[Mesh.ARRAY_VERTEX].size()/3
   if slot==0:normals=Array(arrays[Mesh.ARRAY_NORMAL])
  check(normals.any(func(n):return n.y>.5) and normals.any(func(n):return n.y<-.5),"Closed broken caps and underside "+str(serial))
  check(count<6000,"Cached annex mesh remains bounded "+str(serial))
  mesh_audit.append({"graphic":serial,"triangles":count,"surfaces":mesh.get_surface_count(),"bounds":var_to_str(mesh.get_aabb()),"source_rgba_sha256":g.source_rgba_sha256,"source_footprint":g.footprint})
  var node=MeshInstance3D.new();node.mesh=mesh;node.scale.y=1./(.045*Landmarks.Fit.VERTICAL);stage.add_child(node)
  camera.size=g.size[1]/(sqrt(2.)*32./3.)*1.14
  var target=Vector3(0,(-g.origin[1]-g.size[1]*.5)/Landmarks.Fit.VERTICAL,0)
  for angle in 2:
   if angle==1:
    target=node.transform*mesh.get_aabb().get_center()
    camera.size=maxf(mesh.get_aabb().size.length(),mesh.get_aabb().size.y/(.045*Landmarks.Fit.VERTICAL))*1.2
   camera.position=target+(Vector3(-1,1.603567,1) if angle==0 else Vector3(1,1.15,-1)).normalized()*100.
   camera.look_at(target);camera.current=true
   if DisplayServer.get_name()!="headless":
    for i in 6:await process_frame
    await RenderingServer.frame_post_draw
    check(viewport.get_texture().get_image().save_png(ANNEX_OUT+str(serial)+("-source-axis.png" if angle==0 else "-reverse.png"))==OK,"Captured native annex model "+str(serial)+" "+str(angle))
  node.queue_free();await process_frame
 viewport.queue_free();await process_frame

func actual_views(row:Array):
 var id=Maps.runtime_id(43700);var serial=int(row[0]);var label:String=row[2]
 camera_component_map=-1;camera_component.clear();var initial=walk_cell(id,Vector2i(80,73));use_camera_component(id,initial)
 if game.model.falan_floor!=id:Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,initial),"yaw":0.,"velocity":Vector3.ZERO})
 else:await position_at(Maps.point(id,initial))
 for i in 30:await process_frame
 check(game.model.falan_floor==id,"Actual Lektal map retained "+label)
 collect_camera_canopies(serial)
 var mesh=Annexes.mesh(serial);var bounds=mesh.get_aabb();var anchor=Maps.point(id,row[1]);var center=anchor+Vector2(bounds.get_center().x,bounds.get_center().z)
 var world_bounds=AABB(game.model.world_point(anchor)+bounds.position*game.model.falan_scale,bounds.size*game.model.falan_scale)
 for angle in 2:
  var view=await camera_view(id,row[3+angle],center,bounds.get_center().y*game.model.falan_scale,angle==1,world_bounds)
  check(not view.is_empty(),"Found native annex camera "+label+str(angle))
  if view.is_empty():continue
  check(camera_component.has(view.cell) and game.model.terrain.disk_clear(Vector3(view.at.x,0,view.at.y),.55),"Annex camera retains actual original walk component "+label+str(angle))
  check(view.clear and view.framed,"Annex view is clear and framed "+label+str(angle))
  observations.append({"viewpoint":label,"angle":angle,"source_cell":[view.cell.x,view.cell.y],"source_walk_component_cells":camera_component.size(),"physics_sightline_clear":view.clear,"target_midpoint_in_frustum":view.framed,"ray_hit":view.ray_hit,"target_bounds":view.target_bounds,"camera":var_to_str(game.camera_rig.camera.global_transform)})
  await capture(label+("-normal" if angle==0 else "-second"),43700,view.cell,"Actual source annex section from connected native walk cells; normal gameplay eye, second eye aimed at the broken cap")
 var expected={};var actual={};var state=Maps.state(id);var cells:int=state.size.x*state.size.y
 var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{})
 for i in cells:
  var native_serial:int=state.raw.decode_u16(20+(cells+i)*2);native_serial=int(aliases.get(str(native_serial),native_serial))
  if Annexes.owns(native_serial):expected[native_serial]=expected.get(native_serial,0)+1
 for batch in game.world.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",true,false):
  var native_serial=int(batch.get_meta("source_graphic",0))
  if not Annexes.owns(native_serial):continue
  actual[native_serial]=actual.get(native_serial,0)+batch.multimesh.instance_count
  check(batch.multimesh.mesh==Annexes.mesh(native_serial),"Actual original-map batch uses native annex owner "+str(native_serial))
 check(expected==actual,"Every native annex placement is retained in actual scene")
 observations.append({"expected_source_counts":expected,"actual_source_counts":actual})

func save_report():
 var file=FileAccess.open(ANNEX_OUT+("source-review.json" if "--source-only" in OS.get_cmdline_user_args() else "review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"mesh_audit":mesh_audit,"inferred":Annexes.data().inferred,
  "source_hashes":{"helper":FileAccess.get_sha256("res://scripts/forest/forest_east_lektal_annexes.gd"),"data":FileAccess.get_sha256(Annexes.ROOT+"data.json"),"maps":FileAccess.get_sha256("res://scripts/forest/forest_original_maps.gd")},
  "scope":"Two exact native Lektal porch/wing appearances, no source placement, collider, route or quest changes. Render-only source window openings do not add routes. Native source/reverse images require separate visual judgment."},"  "));file.close()
 print("EAST_LEKTAL_ANNEXES_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size()," captures=",captures.size())

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

func source_doors():
 var id=Maps.runtime_id(43700)
 for row in [[Vector2i(84,66),43742],[Vector2i(73,36),43743]]:
  var at=Maps.source_point(id,row[0]);var target=Maps.runtime_id(row[1])
  if game.model.falan_floor!=id:
   Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,walk_cell(id,Vector2i(80,73))),"yaw":0.,"velocity":Vector3.ZERO})
   for i in 12:await process_frame
  var links=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==target and link.at.distance_to(at)<.01)
  check(links.size()==1,"Actual original annex SourceDoor retains exact warp "+str(row[1]))
  check(clear_point(at),"Original annex door retains terrain/collider clearance "+str(row[1]))
  var direction=approach_direction(at);check(direction!=Vector2.ZERO,"Annex door has original walk approach "+str(row[1]))
  var entered=false;var returned=false
  if direction!=Vector2.ZERO:
   await walk_habaru_threshold(at,direction);entered=game.model.falan_floor==target
   check(entered,"Normal on-foot annex door entry "+str(row[1]))
  if entered:
   var back=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==id)
   check(not back.is_empty(),"Original annex interior return retained "+str(row[1]))
   if not back.is_empty():
    var d=approach_direction(back[0].at);check(d!=Vector2.ZERO,"Original annex return approach clear "+str(row[1]))
    if d!=Vector2.ZERO:await walk_habaru_threshold(back[0].at,d)
    returned=game.model.falan_floor==id;check(returned,"Normal on-foot annex return "+str(row[1]))
    if returned:check(map_position().distance_to(at)<1.5,"Annex return preserves exact original outside cell "+str(row[1]))
  observations.append({"source_door_cell":var_to_str(row[0]),"destination":row[1],"entered_on_foot":entered,"returned_on_foot":returned})
