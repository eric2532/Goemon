extends "res://tests/forest-shrine/falken_route_test.gd"
const ENVIRONMENT_REVIEW="res://build/Other Files/Asset Toolkit/Falken Environment/"
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true;game.ui.hide();game.set_process(false)
 var labels=game.world.find_children("*","Label3D",true,false).filter(func(node):return node.visible)
 for label in labels:label.hide()
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 var folder=ENVIRONMENT_REVIEW+("before/" if "--environment-before" in OS.get_cmdline_user_args() else "after/")
 if label_.begins_with("chamber-"):folder="res://build/Other Files/Asset Toolkit/Falken Chamber/"
 if label_.begins_with("stonework-"):folder="res://build/Other Files/Asset Toolkit/Falken Stonework/"
 if label_.begins_with("dais-"):folder="res://build/Other Files/Asset Toolkit/Falken Dais/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 check(root.get_texture().get_image().save_png(folder+label_+".png")==OK,"Captured "+label_)
 for label in labels:label.show()
 game.set_process(true);game.ui.show();paused=before
func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false;game.run_seed=90824
 check_maze_contract()
 var signatures={};var populations={};var geometry={}
 var Art=Tour.Indoor.RoomArt.FalkenArt
 var before="--environment-before" in OS.get_cmdline_user_args()
 var stairs_cache={}
 if not before:
  var parts=Tour.Indoor.RoomArt.Furniture
  var surface=parts.tool();parts.rounded_block(surface,Vector3.ZERO,Vector3(2,1,1),.1)
  var faces=surface.commit().get_faces()
  for i in range(0,faces.size(),3):
   var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
   check((c-a).cross(b-a).dot((a+b+c)/3)>0,"Shared rounded stone has outward-facing top, base and sides")
  var palette={}
  for i in Art.Data.WALL_CAPS.size():
   var color:Color=Art.Data.WALL_CAPS[i];var cap=Art.wall_cap(i+1)
   if palette.has(color):check(palette[color]==cap,"Identical native cap colors reuse one material and texture")
   palette[color]=cap
 for id in Falken.Route.FLOORS+[Falken.ROOM]:
  var cell:Vector2i=Falken.Route.maze(id,90824).stairs[0]+Vector2i.RIGHT if id in Falken.Route.FLOORS else Vector2i(23,23)
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Falken.Route.point(id,cell),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  if id==Falken.ROOM:
   await talk_to_falken()
   await position_at(Falken.Route.point(id,cell))
  game.model.waves.tick(.5,game.player.position);game.army_runtime.import_arrivals()
  signatures[id]=collision_signature(game.world.map_features.get_node_or_null("ChamberRaisedDais"))
  populations[id]=game.model.enemies.size()
  if id in Falken.Route.FLOORS:check(populations[id]==84,"All sixteen random floors retain their 84 native monsters")
  var walls=game.world.find_child("ArchivedRoomWalls",true,false)
  check(walls!=null and walls.mesh.get_surface_count()==1,"Native wall relief stays in the shared room mesh")
  geometry[id]={"triangles":walls.mesh.get_faces().size()/3,"surfaces":walls.mesh.get_surface_count()}
  if not before:
   check(game.world.get_world_3d().environment.background_color.is_equal_approx(Color("141414")),"Tower cutaway uses its dark interior backdrop")
   check(geometry[id].triangles<350000,"Source relief remains bounded in one static wall surface")
   if id in Falken.Route.FLOORS:
    var stairs=game.world.find_children("HabaruStair_*","Node3D",true,false)
    check(stairs.size()==2,"Both stair landmarks keep their source anchors")
    for stair in stairs:
     var serial:int=stair.get_meta("blue_cg_serial")
     var visual=stair.get_children().filter(func(node):return node is MeshInstance3D)
     check(visual.size()==1,"Individual tread stones share one prepared stair mesh")
     check(visual[0].mesh.get_aabb().size.x<=3.001 and visual[0].mesh.get_aabb().size.z<=(3.091 if serial==12000 else 3.001),"Rounded tread stones retain the original stair builder's visual extents")
     if stairs_cache.has(serial):check(stairs_cache[serial]==visual[0].mesh,"Every floor reuses the same immutable native stair mesh")
     stairs_cache[serial]=visual[0].mesh
  if id in [30201,30208,30216,Falken.ROOM]:
   var point=game.player.position
   await shot("room-"+str(id),point+Vector3(28,38,34)*game.model.falan_scale,point,62)
  if id==30201:
   var point=game.model.world_point(Falken.Route.point(id,Falken.Route.maze(id,90824).stairs[0]))
   await shot("stair-pit",point+Vector3(3.8,3.8,4.6)*game.model.falan_scale,point-Vector3.UP*.3,52)
   point=game.model.world_point(Falken.Route.point(id,Falken.Route.maze(id,90824).stairs[1]))
   await shot("stone-steps",point+Vector3(3.8,3.5,4.6)*game.model.falan_scale,point+Vector3.UP*.65,52)
  if id==Falken.ROOM and not before:
   await check_raised_dais()
   await check_chamber_scenery()
   await check_chamber_stonework()
   check_native_columns(id)
   var presentation=game.crowd.army.presentation
   var count_:int=presentation.get_child_count()
   var batch=presentation.batches["ruby-native-110065"]
   var reduced=game.settings.get("reduced_flashes",false);game.settings.reduced_flashes=false
   for repeat in 12:
    presentation.effects.clear()
    for copy in 5:
     var effect=presentation.ruby_sheet("110065",game.player.position+Vector3(copy-2,0,0))
     check(is_equal_approx(effect.opacity,128.0/255),"Life drain uses original level-five target opacity")
     effect.age=.22
    presentation.draw_effects()
    check(batch.multimesh.visible_instance_count==5 and is_equal_approx(batch.multimesh.get_instance_custom_data(0).g,128.0/255),"Simultaneous drain contacts use the existing pooled original-art batch")
    if repeat==0:await shot("drain-native-opacity",game.player.position+Vector3(8,7,10)*game.model.falan_scale,game.player.position+Vector3.UP*2,55)
    presentation.tick(1.1)
    check(not presentation.effects.any(func(e):return e.kind=="ruby-native-110065"),"Repeated drain effects expire normally")
   check(presentation.get_child_count()==count_ and presentation.batches["ruby-native-110065"]==batch,"Repeated drain contacts retain their existing batch and node count")
   game.settings.reduced_flashes=reduced
  check(reachable_door(game.model.world_point(Falken.Route.point(id,Falken.Route.maze(id,90824).stairs[1]))) if id in Falken.Route.FLOORS else true,"Scenery keeps the native path between stair landings")
 var stage="before" if "--environment-before" in OS.get_cmdline_user_args() else "after"
 var out=FileAccess.open(ENVIRONMENT_REVIEW+stage+"-metrics.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"physics_plans_links":signatures,"populations":populations,"walls":geometry},"  "));out.close()
 if stage=="after" and FileAccess.file_exists(ENVIRONMENT_REVIEW+"before-metrics.json"):
  var old=JSON.parse_string(FileAccess.get_file_as_string(ENVIRONMENT_REVIEW+"before-metrics.json"))
  check(JSON.parse_string(JSON.stringify(signatures))==old.physics_plans_links,"The new dais preserves existing room colliders, obstacle plans and travel links")
  check(JSON.parse_string(JSON.stringify(populations))==old.populations,"Enemy populations remain exactly unchanged on every floor")
 if not before:
  var total_columns=0
  for id in Art.Data.ROOMS:
   var columns=Art.Data.PROPS[id].filter(func(row):return row[1] in Art.PILLARS)
   if columns.is_empty():continue
   var target=Falken.Route.point(id,columns[0][0])
   Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,target+Vector2(3,3)),"yaw":0.0,"velocity":Vector3.ZERO})
   for i in 4:await physics_frame
   total_columns+=check_native_columns(id)
   var point=game.model.world_point(target)
   await shot("gold-columns-"+str(id),point+Vector3(12,10,16)*game.model.falan_scale,point+Vector3.UP*2,55)
  check(total_columns>0,"Original capital/reward-room gold columns are exercised in their source maps")
  Tour.travel(game,Tour.Indoor.layout(1091),{"arrival":Vector2.ZERO,"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  check(not game.world.get_world_3d().environment.background_color.is_equal_approx(Color("141414")),"Leaving the tower restores the next room's backdrop")
  check(game.world.map_features.get_node_or_null("ChamberDaisLights")==null and game.world.chamber_lighting.is_empty(),"Leaving the chamber removes its lamps and restores the room lighting")
  var furniture=Node3D.new();game.world.add_child(furniture);furniture.position=game.player.position+Vector3(0,0,6)
  furniture.scale=Vector3.ONE*game.model.falan_scale
  Geo.mesh(furniture,Tour.Indoor.RoomArt.Furniture.desk(3,3,true),Vector3(-1.8,0,0),null)
  Geo.mesh(furniture,Tour.Indoor.RoomArt.Furniture.chair(),Vector3(1.5,0,0),null)
  await shot("shared-rounded-furniture",furniture.to_global(Vector3(5,6,8)),furniture.to_global(Vector3(0,1.1,0)),55)
  furniture.queue_free()
  await open_area("sokia_desert")
  check(not game.world.get_world_3d().environment.background_color.is_equal_approx(Color("141414")),"The original desert backdrop also returns outside the tower")
 print("FALKEN_ENVIRONMENT_RESULT checks=",checks," failures=",errors)

func check_raised_dais():
 var dais=game.world.map_features.get_node_or_null("ChamberRaisedDais")
 var lamps=game.world.map_features.get_node_or_null("ChamberDaisLights")
 check(dais is MeshInstance3D and lamps is Node3D,"The boss room builds a solid raised platform and its localized lights")
 if dais==null or lamps==null:return
 var art=Tour.Indoor.RoomArt.FalkenArt.Dais
 var scale_=game.model.falan_scale
 var center=art.BOUNDS.get_center()
 var runtime=game.army_runtime
 var field=runtime.navigation_data(game.model,false)
 var space=game.world.get_world_3d().direct_space_state
 for at:Vector2 in [center,Vector2(center.x,-6),Vector2(center.x,-21),Vector2(-15.2,-21.2),Vector2(3.2,-6)]:
  var expected:Vector3=game.model.world_point(at)
  var query=PhysicsRayQueryParameters3D.create(expected+Vector3.UP*5.0,expected-Vector3.UP*2.0,1,[game.player.get_rid()])
  var hit=space.intersect_ray(query)
  check(not hit.is_empty() and hit.position.distance_to(expected)<.01,"The player collider matches the modeled height on plateau, ramps and corners")
 var sample=Vector2i(((center*scale_-Vector2(field.origin.x,field.origin.z))/field.spacing).floor())
 check(is_equal_approx(field.heights[sample.y*field.width+sample.x],art.RISE*scale_),"Native terrain receives the raised center at the correct scale")
 # Walk through the open cell beside Yeka's return portal, clear of the plinth wall.
 var approach:Vector2=center+Vector2(-3.0,11)
 check(runtime.native.can_reach(game.model.world_point(approach),game.model.world_point(approach+Vector2(0,-11)),.9),"Native monsters can walk up the approach to the dais")
 check(lamps.get_child_count()==6 and lamps.get_children().all(func(light):return light is OmniLight3D and not light.shadow_enabled),"Four amber pools and two cool accents use bounded local lights")
 var saved:Vector3=game.player.position
 var yaw:float=game.camera_rig.yaw
 var invuln:float=game.player.invuln
 game.camera_rig.yaw=0.0
 game.player.invuln=8.0
 game.falan_crossing_position=Vector2.INF
 await position_at(approach)
 Input.action_press("move_forward")
 for tick in 360:
  await physics_frame
  if map_position().y<=-8.4:break
 Input.action_release("move_forward")
 for tick in 16:await physics_frame
 print("FALKEN_DAIS_WALK position=",map_position()," height=",game.player.position.y," grounded=",game.player.is_on_floor())
 check(map_position().y<=-8.4 and game.player.is_on_floor() and absf(game.player.position.y-art.RISE*scale_)<.14,"The player walks from the room floor onto the dais without jumping")
 game.player.position=saved
 game.player.velocity=Vector3.ZERO
 game.player.invuln=invuln
 game.camera_rig.yaw=yaw
 game.falan_crossing_position=Vector2.INF
 var focus=game.model.world_point(center)
 await shot("dais-inlay",focus+Vector3(13,20,21)*scale_,focus,56)
 await shot("dais-approach",focus+Vector3(5,2.9,19)*scale_,focus+Vector3.UP*.8*scale_,55)

func check_chamber_scenery():
 var chamber=Tour.Indoor.RoomArt.FalkenArt.Chamber
 var water=game.world.find_child("ChamberWaterChannels",true,false)
 var banks=game.world.find_child("ChamberStoneBanks",true,false)
 var gates=game.world.find_children("ChamberForgedGate*","MeshInstance3D",true,false)
 var plinths=game.world.find_children("ChamberStonePlinth*","MeshInstance3D",true,false)
 var covers=game.world.find_child("ChamberSluiceCovers",true,false)
 check(water!=null and banks!=null and gates.size()==2 and plinths.size()==4,"The boss room has fitted channels, two gates and four carved plinths")
 if water==null or banks==null or gates.size()!=2 or plinths.size()!=4:return
 check(water.mesh.get_faces().size()==134*6 and water.material_override.shader==chamber.Water,"All 134 channel tiles share a single animated water surface")
 check(banks.get_child_count()>0 and banks.get_child_count()<40,"Channel coping shares static spatial batches")
 check(covers!=null and covers.multimesh.instance_count==41,"All forty-one inspection covers share one 3D batch")
 check(gates[0].mesh==gates[1].mesh and gates[0].mesh.get_aabb().size.x<6.0,"The gates reuse one solid lattice within their existing footprints")
 check(plinths.all(func(node):return node.mesh==plinths[0].mesh),"Carved stone plinths reuse the same solid mesh")
 check(game.world.find_child("FalkenNativeProp_17090",true,false)==null,"The gate cards are replaced by the solid lattice")
 var center=game.player.position
 await shot("chamber-overview",center+Vector3(24,35,30)*game.model.falan_scale,center,62)
 center=game.model.world_point(Falken.Route.point(Falken.ROOM,Vector2i(24,14)))
 await shot("chamber-gates",center+Vector3(9,8,14)*game.model.falan_scale,center,54)
 center=game.model.world_point(Falken.Route.point(Falken.ROOM,Vector2i(25,28)))
 await shot("chamber-water",center+Vector3(11,9,13)*game.model.falan_scale,center,54)

func check_chamber_stonework():
 var art=Tour.Indoor.RoomArt.FalkenArt
 var counts={}
 for row in art.Data.PROPS[Falken.ROOM]:
  if not art.ChamberProps.FAMILIES.has(row[1]):continue
  var family=art.ChamberProps.FAMILIES[row[1]]
  counts[family]=counts.get(family,0)+1
  check(game.world.find_child("FalkenNativeProp_"+str(row[1]),true,false)==null,"The chamber replaces flat prop "+str(row[1]))
 for family in counts:
  var batch=game.world.find_child("Chamber"+family,true,false)
  check(batch is MultiMeshInstance3D and batch.multimesh.instance_count==counts[family],"All "+family+" placements share their solid mesh")
 var arches=game.world.find_child("ChamberPassageArch",true,false)
 if arches!=null:
  var mesh=arches.multimesh.mesh
  var faces=mesh.get_faces()
  var obstructs=false
  for vertex in faces:
   if absf(vertex.x)<4.44 and vertex.y<3.50:obstructs=true
  check(not obstructs,"Both arch jambs and overhead stones clear the three walkable tiles")
  var crest=false
  for surface in [0,1]:
   var arrays:Array=mesh.surface_get_arrays(surface)
   for index in arrays[Mesh.ARRAY_INDEX]:
    var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][index]
    if vertex.y>5.95:crest=true
  check(crest,"The rendered stone faces include the arch crown")
  for i in arches.multimesh.instance_count:
   var center=arches.multimesh.get_instance_transform(i).origin
   var at=Vector2(center.x,center.z)
   var north=game.model.world_point(at+Vector2(0,-3.0))
   var south=game.model.world_point(at+Vector2(0,3.0))
   check(game.army_runtime.native.can_reach(south,north,.5),"The native route connects both sides of each arch")
 var relief=game.world.find_child("ChamberCarvedWall",true,false)
 if relief!=null:
  var arrays:Array=relief.multimesh.mesh.surface_get_arrays(1)
  var peaks=0
  for index in arrays[Mesh.ARRAY_INDEX]:
   var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][index]
   if is_equal_approx(vertex.y,3.62) and absf(vertex.x)>1.4:peaks+=1
  check(peaks>1,"The rendered relief faces include both pointed backplates")
 var scale_=game.model.falan_scale
 var center=game.model.world_point(Falken.Route.point(Falken.ROOM,Vector2i(23,36)))
 await shot("stonework-arch",center+Vector3(0.7,3.6,10.0)*scale_,center+Vector3.UP*2.8*scale_,62)
 center=game.model.world_point(Falken.Route.point(Falken.ROOM,Vector2i(14,20))+Vector2(0,-1.5))
 await shot("stonework-relief",center+Vector3(9.0,5.3,6.0)*scale_,center+Vector3.UP*2.1*scale_,52)
 center=game.model.world_point(Falken.Route.point(Falken.ROOM,Vector2i(31,8)))
 await shot("stonework-study",center+Vector3(-3.0,6.8,10.0)*scale_,center+Vector3.UP*1.2*scale_,56)

func check_native_columns(id:int)->int:
 var Art=Tour.Indoor.RoomArt.FalkenArt
 var source=Art.Data.PROPS[id].filter(func(row):return row[1] in Art.PILLARS)
 var count_=0
 for serial in Art.PILLARS:
  var batch=game.world.find_child("FalkenNativeProp_"+str(serial),true,false)
  var expected=source.filter(func(row):return row[1]==serial).size()
  check(batch!=null if expected>0 else batch==null,"Original carved column family retains its archived placements")
  if batch==null:continue
  count_+=batch.multimesh.instance_count
  var bounds:AABB=batch.multimesh.mesh.get_aabb()
  check(bounds.size.x<=3.001 and bounds.size.z<=3.001 and bounds.size.y>4.0,"Carved column/rail pieces fit the unchanged original blocked tile")
  check(batch.material_override==null and batch.multimesh.mesh.get_surface_count()==1,"Carved columns reuse one source-projected solid mesh per family")
 check(count_==source.size(),"All source gold columns replace the generic full wall cubes")
 return count_
