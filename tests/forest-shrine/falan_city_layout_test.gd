extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Fixed city views and bounded doorway checks; no street-by-street walking tour.
const REVIEW="res://build/Other Files/Asset Toolkit/Falan City Reconstruction/"
const VIEWS=[
 ["west-gate",Vector3(-78,63,346),Vector3(-138,15,315)],
 ["east-gate",Vector3(-78,63,-324),Vector3(-138,15,-350)],
 ["south-gate",Vector3(266,63,60),Vector3(291,15,0)],
 ["west-shops",Vector3(-60,54,205),Vector3(-114,12,157)],
 ["east-shops",Vector3(-69,54,-94),Vector3(-114,12,-151)],
 ["side-street",Vector3(-254,45,-67),Vector3(-298,12,-115)],
 ["cathedral",Vector3(-274,67,48),Vector3(-339,20,-3)],
 ["south-plaza",Vector3(112,76,62),Vector3(63,12,0)],
 ["castle-approach",Vector3(-51,67,65),Vector3(-139,11,0)],
 ["northwest-guild",Vector3(-174,60,282),Vector3(-231,12,241.5)],
 ["northeast-office",Vector3(-198,60,-78),Vector3(-252,12,-135)],
 ["southeast-mansion",Vector3(98,60,-32),Vector3(36,12,-93)],
 ["restored-arena-house",Vector3(93,54,216),Vector3(45,12,162)],
 ["cathedral-side",Vector3(-390,58,48),Vector3(-339,16,-3)],
 ["guild-side",Vector3(-186,58,192),Vector3(-231,12,241.5)],
 ["hospital-west",Vector3(-111,56,268),Vector3(-168,13,214.5)],
 ["hospital-west-side",Vector3(-219,52,263),Vector3(-168,13,214.5)],
 ["hospital-east",Vector3(-111,56,-149),Vector3(-168,13,-202.5)],
 ["hospital-east-side",Vector3(-219,52,-154),Vector3(-168,13,-202.5)],
 ["bank",Vector3(-6,59,-206),Vector3(-67.5,14,-265.5)],
 ["bank-side",Vector3(-121,54,-211),Vector3(-67.5,14,-265.5)],
 ["inn",Vector3(65,53,-152),Vector3(7.5,12,-207)],
 ["inn-side",Vector3(40,30,-193),Vector3(7.5,10,-207)],
 ["arena",Vector3(126,60,151),Vector3(66,15,93)],
 ["arena-side",Vector3(12,55,147),Vector3(66,15,93)],
 ["mansion-side",Vector3(-20,56,-39),Vector3(36,12,-93)],
 ["castle-approach-side",Vector3(-228,65,66),Vector3(-139,11,0)],
 ["magic-shop",Vector3(-113,55,220),Vector3(-168,14,165)],
 ["magic-shop-side",Vector3(-223,50,215),Vector3(-168,14,165)],
 ["workshop",Vector3(-174.5,56,205),Vector3(-229.5,14,150)],
 ["workshop-side",Vector3(-174.5,54,95),Vector3(-229.5,14,150)],
 ["apothecary",Vector3(-113,52,-81.5),Vector3(-168,12,-136.5)],
 ["apothecary-side",Vector3(-223,50,-86.5),Vector3(-168,12,-136.5)],
 ["training-house",Vector3(32.5,52,158.5),Vector3(-22.5,12,103.5)],
 ["training-house-side",Vector3(32.5,54,48.5),Vector3(-22.5,12,103.5)],
 ["villa-10311",Vector3(-243.5,52,196),Vector3(-298.5,12,141)],
 ["villa-10311-side",Vector3(-253.5,54,96),Vector3(-298.5,12,141)],
 ["villa-10312",Vector3(-155,52,-212),Vector3(-210,12,-267)],
 ["villa-10312-side",Vector3(-165,54,-312),Vector3(-210,12,-267)],
 ["villa-10313",Vector3(-248,55,244),Vector3(-303,16,189)],
 ["villa-10313-side",Vector3(-258,58,144),Vector3(-303,16,189)],
 ["tower-house",Vector3(164.5,68,1),Vector3(109.5,20,-54)],
 ["tower-house-side",Vector3(54.5,65,-4),Vector3(109.5,20,-54)],
]
const PLAY_VIEWS=[
 ["cathedral",Vector2(-339,-3),Vector2.RIGHT,34.0],
 ["guild",Vector2(-231,241.5),Vector2.RIGHT,26.0],
 ["office",Vector2(-242,-135),Vector2.DOWN,26.0],
 ["hospital-west",Vector2(-168,214.5),Vector2.RIGHT,28.0],
 ["hospital-east",Vector2(-168,-202.5),Vector2.RIGHT,28.0],
 ["bank",Vector2(-67.5,-265.5),Vector2.DOWN,28.0],
 ["inn",Vector2(7.5,-207),Vector2.DOWN,26.0],
 ["mansion",Vector2(36,-93),Vector2.RIGHT,28.0],
 ["arena",Vector2(66,93),Vector2.RIGHT,34.0],
 ["magic-shop",Vector2(-168,165),Vector2.DOWN,26.0],
 ["workshop",Vector2(-229.5,150),Vector2.RIGHT,26.0],
 ["apothecary",Vector2(-168,-136.5),Vector2.DOWN,25.0],
 ["training-house",Vector2(-22.5,103.5),Vector2.RIGHT,26.0],
 ["villa-10311",Vector2(-298.5,141),Vector2.RIGHT,25.0],
 ["villa-10312",Vector2(-210,-267),Vector2.DOWN,25.0],
 ["villa-10313",Vector2(-303,189),Vector2.RIGHT,25.0],
 ["tower-house",Vector2(109.5,-54),Vector2.RIGHT,30.0],
]
var checks=0
var inn_approach=Vector2.INF
var only_view=""
var evidence={"views":[],"gameplay_camera":[],"doors":[],"rooms":[],"fallback_homes":[],"visual_entries":[],"meshes":{}}

func _initialize():
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--only-view="):only_view=argument.trim_prefix("--only-view=")
 root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true)
 root.grab_focus()
 create_timer(600).timeout.connect(func():printerr("FALAN_CITY_LAYOUT_TIMEOUT");quit(1))
 run.call_deferred()

func check(ok:bool,message:String):
 checks+=1
 super.check(ok,message)

func check_east_il_road():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 var phase="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 game.explorer_clock.hour=10.0
 game.explorer_clock.update_lighting()
 for view in VIEWS:await city_shot(view,phase)
 if DisplayServer.get_name()!="headless":
  for view in PLAY_VIEWS:await gameplay_shot(view,phase)
  var bridges:Array=Tour.LINKS.city.filter(func(link):return link.to=="castle")
  bridges.sort_custom(func(a,b):return a.at.x>b.at.x)
  await gameplay_shot(["castle-approach",bridges[0].at,Vector2.RIGHT,9.0],phase)
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(npcs!=null and npcs.get_child_count()==78,"All 78 city NPCs retain their presentation")
 for npc in Tour.NPCS.AREAS.city:
  var point=game.model.world_point(npc[0])/game.model.falan_scale+Vector3.UP*.5
  check(not game.model.scenery_obstacles.values().any(func(box):return box.has_point(point)),"City NPC is clear of building collision: "+npc[2])
 var architecture=game.model.CityArchitecture
 for link in game.model.get_meta("falan_links",[]):
  if link.has("visual_entry_graphic"):
   var anchor:Vector2i=link.get("visual_entry_anchor",link.get("house_anchor",Vector2i.ZERO))
   var opening:Dictionary=architecture.entry(link.visual_entry_graphic)
   var center:Vector2=architecture.Data.BINDINGS[anchor][1]
   var delta:Vector2=link.at-center-opening.at
   var lateral=absf(delta.cross(opening.direction))
   evidence.visual_entries.append({"anchor":str(anchor),"graphic":link.visual_entry_graphic,"floor":link.floor,"lateral":lateral,"outward":delta.dot(opening.direction)})
   check(lateral<Tour.WALK_IN_RADIUS,"Visible doorway approach crosses its original trigger: "+str(anchor))
  if link.get("floor",-1)==0 and link.has("house_anchor"):
   evidence.fallback_homes.append({"anchor":str(link.house_anchor),"at":[link.at.x,link.at.y],"blocker":"No original warp/room is supplied for this preserved saved-house entrance."})
   check(link.has("visual_entry_graphic") and link.get("visual_entry_aligned",false),"Preserved house entry follows its visible opening: "+str(link.house_anchor))
 check(evidence.visual_entries.size()==architecture.Data.BINDINGS.size(),"Every original saved house retains ownership of its visible opening")
 check(evidence.fallback_homes.size()==31,"The batch audit preserves 31 unverified houses after removing one duplicate annex entrance")
 var inn=game.world.find_child("FalanCivicFacade_1101",true,false)
 check(inn!=null,"Inn retains its source-bound exterior")
 if inn!=null:
  var portals=inn.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.has_meta("falan_portal_origin"))
  check(portals.size()==1,"Inn retains one main entrance")
  if portals.size()==1:
   var p:Vector3=portals[0].global_position/game.model.falan_scale
   inn_approach=Vector2(p.x,p.z)+Vector2.DOWN*.65
   var links=game.model.get_meta("falan_links",[]).filter(func(link):return link.get("floor",-1)==1101)
   check(links.any(func(link):return link.at.distance_to(inn_approach)<Tour.WALK_IN_RADIUS),"Inn's visible opening remains inside its original entrance trigger")
 check(not evidence.fallback_homes.any(func(home):return home.anchor=="(-50, -12)"),"The real annex house reuses the original 1542 doorway")
 var houses=0
 for node in game.world.find_children("RecoveredFalanArchitecture*","MultiMeshInstance3D",true,false):houses+=node.multimesh.instance_count
 check(houses==73,"All 73 ordinary source houses render once, including 10310")
 for serial in architecture.Data.GRAPHICS:
  var row:Array=architecture.Data.GRAPHICS[serial]
  var mesh:Mesh=architecture.prepare(serial)
  evidence.meshes[str(serial)]={"triangles":mesh.get_faces().size()/3,"surfaces":mesh.get_surface_count()}
  check(architecture.Proportions.matches(architecture.prepare(serial),"house_%d"%serial,PI*.5),"Native building dimensions: "+str(serial))
  if row[8] in [2,12]:continue
  var profile=architecture.HouseParts.source_roof_profile(5.0,6.0,row[8],serial)
  var lowest=INF
  for p:Vector2 in row[4]:lowest=minf(lowest,p.y)
  for i in profile.size():check(is_equal_approx(profile[i].y-6.0,row[4][i].y-lowest),"Roof follows its own native contour: "+str(serial))
 for row in Tour.Indoor.Data.DOORS[1000]:
  var at:Vector2=row[0];var point=game.model.world_point(at)/game.model.falan_scale
  var blockers=[]
  for anchor in game.model.scenery_obstacles:
   if game.model.scenery_obstacles[anchor].grow(.55).has_point(point+Vector3.UP*.5):blockers.append(str(anchor))
  var directions=[]
  for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
   var clear=true
   for distance in [0.0,1.0,2.0,3.0]:
    var sample=point+Vector3(direction.x,0,direction.y)*distance
    if not game.model.terrain.disk_clear(sample,.55) or game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(sample+Vector3.UP*.5)):clear=false
   if clear:directions.append([direction.x,direction.y])
  evidence.doors.append({"at":[at.x,at.y],"floor":row[1],"blockers":blockers,"approaches":directions})
  check(blockers.is_empty() and not directions.is_empty(),"Source door has a clear approach: "+str(row[1])+" "+str(at))
 if "--baseline" not in OS.get_cmdline_user_args() and (DisplayServer.get_name()=="headless" or "--smoke" in OS.get_cmdline_user_args()):
  await smoke_city()
 check(JSON.stringify(get_meta("falan_venture"))==saved,"The saved adventure is unchanged")
 var result_name="smoke.json" if DisplayServer.get_name()=="headless" else "runtime.json"
 if not only_view.is_empty():result_name="focused-"+only_view+".json"
 var file=FileAccess.open(REVIEW+phase+"/"+result_name,FileAccess.WRITE)
 file.store_string(JSON.stringify(evidence,"  "))
 print("FALAN_CITY_LAYOUT_RESULT phase=",phase," checks=",checks," failures=",errors)

func city_shot(view:Array,phase:String):
 if not only_view.is_empty() and only_view!=view[0]:return
 if DisplayServer.get_name()=="headless":return
 root.grab_focus()
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 var scale_:float=game.model.falan_scale
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.global_position=view[1]*scale_;camera.look_at(view[2]*scale_);camera.fov=60
 camera.reset_physics_interpolation()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+phase+"/"+view[0]+".png")==OK,"Capture "+view[0])
 evidence.views.append(view[0])
 game.set_process(true);game.ui.show()

func gameplay_shot(view:Array,phase:String):
 if not only_view.is_empty() and only_view!="play-"+view[0]:return
 var normal:Vector2=view[2];var across=Vector2(-normal.y,normal.x)
 var at=Vector2.INF
 for farther in [0.0,3.0,6.0]:
  for lateral in [0.0,-3.0,3.0,-6.0,6.0]:
   var candidate:Vector2=view[1]+normal*(view[3]+farther)+across*lateral
   var point=Vector3(candidate.x,game.model.surface_height(candidate.x,candidate.y)+.5,candidate.y)
   if not game.model.terrain.disk_clear(point,.7):continue
   if game.model.scenery_obstacles.values().any(func(box):return box.grow(.7).has_point(point)):continue
   if game.model.CityGardens.Data.PLANTERS.any(func(row):return row[0].distance_to(candidate)<3.2):continue
   if game.model.get_meta("falan_links",[]).any(func(link):return link.at.distance_to(candidate)<4.0):continue
   at=candidate;break
  if at.is_finite():break
 check(at.is_finite(),"Reachable normal-camera approach: "+view[0])
 if not at.is_finite():return
 root.grab_focus()
 var player=game.player;var physics=player.is_physics_processing()
 player.set_physics_process(false)
 player.position=game.model.world_point(at,.15);player.velocity=Vector3.ZERO
 player.facing=Vector3(-normal.x,0,-normal.y);player.reset_physics_interpolation()
 game.falan_crossing_position=at
 for i in 4:await process_frame
 game.set_process(false);game.ui.hide()
 var rig=game.camera_rig
 rig.yaw=atan2(normal.x,normal.y);rig.pitch=game.COMBAT_CAMERA_PITCH
 rig.distance=game.settings.forest_camera_distance;rig.reset_follow()
 for i in 90:rig.update_camera(1.0/60.0)
 rig.camera.reset_physics_interpolation()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var key="play-"+view[0]
 check(root.get_texture().get_image().save_png(REVIEW+phase+"/"+key+".png")==OK,"Normal gameplay camera: "+view[0])
 evidence.views.append(key)
 evidence.gameplay_camera.append({"view":key,"player":[at.x,at.y],"yaw":rig.yaw,"pitch":rig.pitch,"distance":rig.current_distance,"fov":rig.camera.fov})
 player.set_physics_process(physics);game.set_process(true);game.ui.show()

func smoke_city():
 var city=game.model
 var pending=[1000];var seen={1000:true}
 for id in pending:
  for row in Tour.Indoor.Data.DOORS.get(id,[]):
   var target:int=row[1]
   if target>=1500 and target<1540:continue
   if not seen.has(target):seen[target]=true;pending.append(target)
 for id in pending:
  if id==1000:continue
  var info:Array=Tour.Indoor.floor_info(id)
  check(info!=Tour.Indoor.SIMPLE,"City room has its recovered source floor: "+str(id))
  var links:Array=Tour.Indoor.Data.DOORS.get(id,[])
  check(not links.is_empty() or Tour.Indoor.RoomArt.Arena.ANNEX_RETURNS.has(id),"City room has a return connection: "+str(id))
  evidence.rooms.append(id)
 var cached=game.model.CityArchitecture.meshes.duplicate()
 for area in ["freyja","east_gate","south_gate"]:
  var edge:float=Tour.Frontier.OUTER_EDGE[area]
  await position_at(Tour.Frontier.to_city(area,Vector2(3,edge-1)))
  await position_at(Tour.Frontier.to_city(area,Vector2(3,edge+1)))
  check(Tour.area(game.model)==area,"City gate crossing: "+area)
  if Tour.area(game.model)!=area:continue
  await position_at(Vector2(3,edge+1));await position_at(Vector2(3,edge-1))
  check(Tour.area(game.model)=="city","Gate returns to city: "+area)
 for id in [1011,1012,1021,1022,1031,1041,1061,1062,1071,1091,1092,1101,1111,1112,1121,1170,1187,1195,1201,1301,1400,1542]:
  if id==1101 and inn_approach.is_finite():
   game.player.position=game.model.world_point(inn_approach,.15);game.player.velocity=Vector3.ZERO
   game.falan_crossing_position=inn_approach+Vector2.DOWN*4
   check(Tour.cross_on_foot(game),"Inn opens through its actual visible arch")
   for i in 12:await physics_frame
   check(Tour.area(game.model)=="interior" and game.model.falan_floor==1101,"Visible Inn arch enters source room 1101")
  else:await room(id)
  if Tour.area(game.model)!="interior":continue
  var exits:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="city")
  check(not exits.is_empty(),"Building retains its city exit: "+str(id))
  if exits.is_empty():continue
  await position_at(exits[0].at)
  if Tour.area(game.model)=="interior":await walk_through_entry()
  check(Tour.area(game.model)=="city","Door round trip: "+str(id))
 var homes:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.get("floor",-1)==0)
 if not homes.is_empty():
  await position_at(homes[0].at)
  if Tour.area(game.model)=="city":await walk_through_entry()
  check(Tour.area(game.model)=="interior" and game.model.falan_floor==0,"Preserved reusable-house entrance")
  var exits:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="city")
  check(not exits.is_empty(),"Reusable house remembers its own return doorway")
  if not exits.is_empty():
   await position_at(exits[0].at)
   if Tour.area(game.model)=="interior":await walk_through_entry()
   check(Tour.area(game.model)=="city","Reusable house returns to its saved door")
 for link in Tour.LINKS.city:
  if link.to!="castle":continue
  await position_at(link.at)
  if Tour.area(game.model)=="city":await walk_through_entry()
  check(Tour.area(game.model)=="castle","City-side castle connection: "+str(link.at))
  if Tour.area(game.model)!="castle":continue
  var returns:Array=game.model.get_meta("falan_links",[]).filter(func(back):return back.to=="city")
  returns.sort_custom(func(a,b):return a.at.distance_squared_to(link.arrival)<b.at.distance_squared_to(link.arrival))
  await position_at(returns[0].at)
  if Tour.area(game.model)=="castle":await walk_through_entry()
  check(Tour.area(game.model)=="city","Castle approach returns to city")
 check(is_instance_valid(city),"City round trips reuse the cached model")
 for serial in cached:check(is_same(cached[serial],game.model.CityArchitecture.prepare(serial)),"City returns reuse prepared house mesh: "+str(serial))
