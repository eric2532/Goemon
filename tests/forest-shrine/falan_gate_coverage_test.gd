extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Falan Gate Coverage/"
var checks=0

func _initialize():
 var doc=Doc.new(false)
 var error=doc.read_file(Doc.MAP_FOLDER.path_join(Doc.saved_filename("Freyja and Falan - Test")))
 if not error.is_empty():printerr("FALAN_FAIL Saved map load: ",error);quit(1);return
 super._initialize()

func check(ok:bool,message:String):
 checks+=1
 super.check(ok,message)

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 if DisplayServer.get_name()=="headless":return
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for i in 10:await process_frame
 RenderingServer.force_draw()
 var phase="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 check(root.get_texture().get_image().save_png(REVIEW+phase+"/"+name_+".png")==OK,"Save exterior coverage view")
 game.set_process(true);game.ui.show()

func check_east_il_road():
 game.tuning.invincible=true
 var saved=JSON.stringify(get_meta("falan_venture"))
 var gates=["south_gate"] if "--south-only" in OS.get_cmdline_user_args() else ["freyja","east_gate","south_gate"]
 for area in gates:
  print("FALAN_GATE_COVERAGE_AREA ",area)
  var edge:float=Tour.Frontier.OUTER_EDGE[area]
  await position_at(Tour.Frontier.to_city(area,Vector2(3,edge-1)))
  await position_at(Tour.Frontier.to_city(area,Vector2(3,edge+1)))
  check(Tour.area(game.model)==area,"Walk out through "+area)
  if Tour.area(game.model)!=area:return
  if "--baseline" not in OS.get_cmdline_user_args():check_defenses(area)
  var scale_:float=game.model.falan_scale
  var label="west" if area=="freyja" else "east" if area=="east_gate" else "south"
  await shot(label+"-outside",Vector3(3,22,220)*scale_,Vector3(3,13,112)*scale_,65)
  await shot(label+"-left",Vector3(-95,50,205)*scale_,Vector3(-20,13,125)*scale_,65)
  await shot(label+"-right",Vector3(95,50,205)*scale_,Vector3(25,13,125)*scale_,65)
  await shot(label+"-walls",Vector3(3,140,285)*scale_,Vector3(3,8,-12)*scale_,70)
  await position_at(Vector2(3,edge+1))
  await position_at(Vector2(3,edge-1))
  check(Tour.area(game.model)=="city","Walk back through "+area)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Gate coverage preserves the saved adventure")
 if "--baseline" not in OS.get_cmdline_user_args():await check_connections()
 print("FALAN_GATE_COVERAGE_RESULT checks=",checks," failures=",errors)

func check_connections():
 var frontier=Tour.Frontier
 var venture:Dictionary=get_meta("falan_venture")
 Tour.travel(game,venture.falan_areas.east_gate,{"arrival":Vector2(frontier.EAST_TRAIL_EDGE+1,279),"yaw":0.0,"velocity":Vector3.ZERO})
 await position_at(Vector2(frontier.EAST_TRAIL_EDGE+1,279));await position_at(Vector2(frontier.EAST_TRAIL_EDGE-1,279))
 check(Tour.area(game.model)=="south_gate","East and South Gate exteriors connect on foot")
 if Tour.area(game.model)=="south_gate":
  await position_at(Vector2(261,frontier.SOUTH_TRAIL_EDGE+2));await position_at(Vector2(261,frontier.SOUTH_TRAIL_EDGE-1))
  check(Tour.area(game.model)=="east_gate","The connecting exterior road returns to East Gate")
 for link in Tour.Regions.Data.LINKS:
  if link[0] not in ["freyja","south_gate"]:continue
  var axis:int=link[2];var center=Vector2.ZERO;center[axis]=link[4];center[1-axis]=link[5]
  var direction=Vector2.ZERO;direction[axis]=link[3]
  var inverse=Tour.Regions.frame(link[0]).inverse()
  var layout=venture if link[0]=="freyja" else venture.falan_areas[link[0]]
  Tour.travel(game,layout,{"arrival":inverse*(center-direction*2),"yaw":0.0,"velocity":Vector3.ZERO})
  await position_at(inverse*(center-direction));await position_at(inverse*(center+direction))
  check(Tour.area(game.model)==link[1],"The complete exterior joins its onward road: "+link[1])
  if Tour.area(game.model)!=link[1]:continue
  var outside=Tour.Regions.frame(link[1]).inverse()
  var return_center=center-direction*9
  await position_at(outside*(return_center+direction));await position_at(outside*(return_center-direction))
  check(Tour.area(game.model)==link[0],"The onward road returns to its original gate exterior")

func check_defenses(area:String):
 var frontier=Tour.Frontier
 var rows=frontier.city_forts(area)
 var district=game.world.find_child("FalanGateDistrict",true,false)
 var fort=district.find_child("ArchivedFalanFortifications",true,false)
 check(fort!=null,"The complete city defenses render behind "+area)
 check(rows.size()>340,"Source walls cover the whole city rather than a cropped gateway")
 var pieces=0
 for node in fort.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("falan_fort_graphic"):continue
  var serial:int=node.get_meta("falan_fort_graphic")
  pieces+=node.multimesh.instance_count
  check(is_same(node.multimesh.mesh,frontier.CityForts.Parts.prepare(serial)),"All wall stations reuse their measured solid source mesh")
 check(pieces==rows.size(),"Every archived city fort station renders exactly once")
 var returns=fort.find_child("SourceMasonryReturns",true,false)
 check(returns!=null and is_same(returns.mesh,frontier.CityForts.junctions().mesh),"Source wall and tower seams reuse the cached closed masonry returns")
 var headers=0
 for building in game.model.buildings.values():
  if not building.get("freyja_arch",false):continue
  var spec=frontier.CityForts.Parts.gate_spec(building)
  check(not spec.is_empty(),"Canonical gate selects its original raised header")
  if spec.is_empty():continue
  headers+=1
  check(game.world.structure_nodes[building.id].get_meta("falan_gate_source_graphic",0)==spec[0],"Gate renders the original directional beam and ironwork")
  var pose=Transform3D(Basis(Vector3.UP,building.rotation*PI*.5),game.model.center(building))*spec[1]
  var anchor=Vector2(pose.origin.x,pose.origin.z)
  check(frontier.Streets.FORTIFICATIONS.any(func(row):return row[1]==spec[0] and frontier.from_city(area,row[0]).distance_to(anchor)<.001),"Gate header uses its exact archived station")
  check(pose.basis.is_equal_approx(Basis(Vector3.UP,frontier.FRAMES[area].get_rotation())),"Gate paint keeps its original city orientation")
  var span:AABB=pose*frontier.CityForts.Parts.prepare(spec[0]).get_aabb()
  var body=Transform3D(Basis(Vector3.UP,building.rotation*PI*.5),game.model.center(building))
  var joins=frontier.CityForts.Parts.gate_supports(building).map(func(box):return body*box)
  for joint in joins:check(joint.intersects(span),"Gate shoulder connects to its solid beam")
  check(game.model.falan_frontier_plan.filter(func(row):return (row[0] is int or row[0]=="archive_city_fort") and (row[2].intersects(span) or joins.any(func(box):return row[2].intersects(box)))).size()>=2,"Gate beam physically joins both source towers")
  var moved=building.duplicate();moved.cell+=Vector2i(1,0)
  check(frontier.CityForts.Parts.gate_spec(moved).is_empty(),"Moved user gate retains the standard complete arch")
 check(headers==2,"Both inner and outer gates use the source header")
 for row in game.model.falan_frontier_plan:
  if row[0] is not int:continue
  var serial:int={10640:10641,10641:10640}.get(row[0],row[0]) if area=="south_gate" else row[0]
  check(row[2].is_equal_approx(row[1]*frontier.CityForts.Parts.prepare(serial).get_aabb()),"Outdoor native collision matches the recovered solid fort")
 var outside={}
 for row in frontier.Gates.EXTERIORS[area].forts:outside[row[0]]=true
 for row in rows:
  var at=frontier.from_city(area,row[0])
  check(not outside.has(at),"Each existing outdoor gateway piece renders once")
 var boxes=frontier.CityForts.obstacles(rows)
 var plan=game.model.falan_frontier_plan.filter(func(row):return row[0] is String and row[0]=="archive_city_fort")
 check(plan.size()==boxes.size(),"Every restored wall shares the native collision plan")
 var local=district.transform
 for i in boxes.size():check(plan[i][2].is_equal_approx(local*boxes[i]),"Exterior collision uses the original city wall transform")
 var shapes=fort.find_children("*","CollisionShape3D",true,false).filter(func(shape):return shape.get_parent().has_meta("city_fortification_body"))
 check(shapes.size()==boxes.size(),"Physical and native wall shapes agree")
 for i in shapes.size():
  var source:Transform3D=fort.global_transform.affine_inverse()*shapes[i].global_transform
  var shape:BoxShape3D=shapes[i].shape
  var actual=source*AABB(-shape.size*.5,shape.size)
  check(actual.position.distance_to(boxes[i].position)<.001 and actual.size.distance_to(boxes[i].size)<.001,"Physical wall dimensions match their source bounds")
 for z in range(45 if area=="south_gate" else 48,181):
  var at=Vector3(3,6.5,z)
  check(not game.model.scenery_obstacles.values().any(func(box):return box.grow(.6).has_point(at)),"Both open gateway lanes remain clear")
 for cell in frontier.Gates.EXTERIORS[area].legacy:
  var row=frontier.Gates.EXTERIORS[area].legacy[cell]
  if row[0] not in ["wall_piece","round_gate_tower"]:continue
  check(frontier.replaces_saved_scenery(area,cell,row[0],row[1],row[2],0),"Original placeholder is covered by source defenses")
  check(not frontier.replaces_saved_scenery(area,cell,row[0],row[1],row[2],1),"Raised user wall remains owned by the user")
  check(not frontier.replaces_saved_scenery(area,cell,row[0],row[1]*1.1,row[2],0),"Resized user wall remains owned by the user")
 var city=district.get_meta("city_source_model",null)
 check(city!=null,"All gates use the complete saved city source")
 check(city.waves==null and city.workforce==null and city.enemies.is_empty(),"The complete city view adds no second gameplay simulation")
 check(district.find_child("CompleteFalanGround",true,false)!=null,"The complete city ground is present outside "+area)
 var house_count=0;var planters=0
 for node in district.find_children("*","MultiMeshInstance3D",true,false):
  if node.has_meta("falan_architecture_graphic"):
   house_count+=node.multimesh.instance_count
   check(is_same(node.multimesh.mesh,game.world.model.CityArchitecture.prepare(node.get_meta("falan_architecture_graphic"))),"Exterior houses reuse the current source city meshes")
  if str(node.name).begins_with("RecoveredFalanPlanters"):planters+=node.multimesh.instance_count
 check(house_count==72,"All 72 recovered house stations remain visible from "+area)
 check(planters==226,"All 226 original planters remain in the exterior city view")
 check(district.find_children("FalanCivicFacade_*","Node3D",true,false).size()==9,"All nine civic buildings remain in the complete city view")
 check(district.find_child("ArchivedFalanGardens",true,false)!=null,"The original city gardens are present")
 check(game.world.find_children("terraced_mountain_*","MultiMeshInstance3D",true,false).is_empty(),"The exterior omits the invented valley mountain ring")
 check(district.find_child("OriginalFalanNPCs",true,false).get_child_count()==78,"All original city NPCs remain in the complete exterior view")
 for row in frontier.CityForts.Data.FORTIFICATIONS:
  var outside_at=frontier.from_city(area,row[0]);var round_trip=district.transform*Vector3(row[0].x,6,row[0].y)
  check(Vector2(round_trip.x,round_trip.z).distance_to(outside_at)<.001,"Every source station uses the correct gate rotation")
