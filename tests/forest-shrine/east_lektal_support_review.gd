extends "res://tests/forest-shrine/east_lektal_annexes_review.gd"
## The earlier78 assertions verified XZ entry/return, not physical stair climbing.
## This focused check measures the two original return treads and unchanged early entry.
const SUPPORT_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Lektal Annexes/"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
var support_before:Dictionary={}

func run():
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SUPPORT_OUT))
 support_before=Sources.snapshot(review_source_paths()+["tests/forest-shrine/east_lektal_support_review.gd","scripts/forest/forest_east_lektal_annexes.gd","scripts/forest/forest_original_maps.gd","scripts/forest/forest_model.gd","scripts/forest/forest_falan_tour.gd","scripts/forest/crowd/army_runtime.gd","assets/maps/falan/east_region/lektal_annexes/data.json"])
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-annex-support-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 game.settings.forest_pet_loadout=[]
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 var id=Maps.runtime_id(43700)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,Vector2i(80,73)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 12:await physics_frame
 check(game.model.falan_floor==id,"Original Lektal source map loaded")
 check(is_equal_approx(Tour.WALK_IN_RADIUS,2.1),"The recorded instant entrance radius remains2.1")
 Annexes.prepare_support()
 var bits:PackedByteArray=Maps.state(id).bits.duplicate()
 await source_views()
 await support_contract(id)
 for path:Dictionary in Annexes.data().support.paths:await native_return_path(id,path)
 await actual_views([1233256,Vector2i(84,65),"lektal-supported-porch",Vector2i(82,70),Vector2i(91,64)])
 await tread_detail(id)
 check(Maps.state(id).bits==bits,"Physical tread support preserves every original walk bit")
 var changed=Sources.changed(support_before)
 check(changed.is_empty(),"Loaded physical-support sources remain current through the check")
 var file=FileAccess.open(SUPPORT_OUT+"support-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"source_hashes":support_before,"source_changed_during_run":changed,"source_walk_sha256":Annexes.data().support.source_walk_sha256,"source_mesh_audit":mesh_audit,"inferred":Annexes.data().inferred,"scope":"Two original-open return treads only. Normal entry still transfers at the recorded2.1radius before the raised steps. Original blocked deck cells and the two decorative porches have no new support. Earlier78checks are XZ door round trips, not stair-climbing evidence."},"  "));file.close()
 print("EAST_LEKTAL_SUPPORT_RESULT checks=",checks," failures=",errors," captures=",captures.size())
 await finish()

func support_contract(id:int):
 var state=Maps.state(id);var count=0
 for body:StaticBody3D in game.world.map_features.find_children("NativeLektalTreadSupport_*","StaticBody3D",true,false):
  count+=1
  var cell:Vector2i=body.get_meta("source_cell")
  check(Maps.open(state.bits,state.size,cell),"Static tread support is clipped to an original-open cell "+str(cell))
  check(body.collision_layer==1 and body.collision_mask==0,"Tread support reuses the existing static floor contract")
  for point:Vector3 in body.get_child(0).shape.points:
   var center=Maps.point(id,cell)
   check(absf(point.x-center.x)<=1.5001 and absf(point.z-center.y)<=1.5001,"A tread prism stays within its recorded open cell")
 check(count>0 and count<30,"Only a bounded set of original return tread prisms is built")
 for path:Dictionary in Annexes.data().support.paths:
  var cell=Vector2i(path.porch_cell[0],path.porch_cell[1]);var anchor=Maps.point(id,cell)
  check(not Maps.open(state.bits,state.size,cell) and Annexes.surface_height(anchor.x,anchor.y)==0.,"Blocked source porch deck receives no floor "+str(cell))
 for excluded:Dictionary in Annexes.data().support.decorative_exclusions:
  var cell=Vector2i(excluded.porch_cell[0],excluded.porch_cell[1]);var anchor=Maps.point(id,cell)
  check(Annexes.surface_height(anchor.x,anchor.y+3.)==0.,"Decorative porch keeps its original lateral walk route "+str(cell))
 var nav:Dictionary=game.army_runtime.navigation_data(game.model,false);var scale_:float=game.model.falan_scale
 check(nav.width==(state.size.x+1)*2-1 and is_equal_approx(nav.spacing,1.5*scale_),"Native height sampling reuses the existing1.5m support-grid contract")
 check(is_equal_approx(nav.route_spacing,3.*scale_) and nav.covered.count(1)==nav.covered.size(),"Original route spacing and complete covered domain are retained")
 for row:Dictionary in Annexes.support_rows:
  var anchor:Vector2=row.anchor
  for z in [2.8,3.0,3.4,3.8,4.2]:
   var at=anchor+Vector2(0,z);var expected=Annexes.surface_height(at.x,at.y)
   check(expected>.05,"The original-open lower tread has a represented height")
   check(is_equal_approx(game.model.surface_height(at.x,at.y),expected),"Model height samples the same lower tread")
   var p=game.model.world_point(at);var ray=PhysicsRayQueryParameters3D.create(p+Vector3.UP*5.,p-Vector3.UP*3.,1)
   var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty() and hit.collider.get_meta("native_lektal_tread",false) and absf(hit.position.y-p.y)<.02,"Static support and model height agree on each represented lower tread")
   var nc=Vector2i(((Vector2(p.x,p.z)-Vector2(nav.origin.x,nav.origin.z))/nav.spacing).round())
   var vertex=nav.origin+Vector3(nc.x*nav.spacing,0,nc.y*nav.spacing)
   var expected_nav=Annexes.surface_height(vertex.x/scale_,vertex.z/scale_)*scale_
   check(absf(nav.heights[nc.y*nav.width+nc.x]-expected_nav)<.001,"Native navigation samples the existing model floor-height contract")
 for row:Dictionary in Annexes.support_rows:
  var anchor:Vector2=row.anchor;var returned=game.model.world_point(anchor+Vector2(0,3.));var ground=game.model.world_point(anchor+Vector2(0,6.))
  for radius in [.25,.35,.60]:
   check(game.army_runtime.native.ally_ground_clear(returned,radius),"Actual native return clears radius "+str(radius))
   check(game.army_runtime.native.can_reach(ground,returned,radius),"Actual native route reaches original return radius "+str(radius))
   check(game.army_runtime.native.can_reach(returned,ground,radius),"Actual native route descends original return radius "+str(radius))
   for z in [3.,3.2,3.4,3.6,3.8,4.,4.2,4.4,4.6,4.8,5.,5.2,5.4,5.6,5.8,6.]:
    check(game.army_runtime.native.ally_ground_clear(game.model.world_point(anchor+Vector2(0,z)),radius),"Actual native descent remains clear radius %s z%s"%[radius,z])
 observations.append({"support_prisms":count,"original_open_only":true,"decorative_support":false,"blocked_deck_support":false})

func native_return_path(id:int,path:Dictionary):
 var cell=Vector2i(path.door_cell[0],path.door_cell[1]);var at=Maps.source_point(id,cell);var destination=int(path.destination);var target=Maps.runtime_id(destination)
 if game.model.falan_floor!=id:
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,Vector2i(80,73)),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 8:await physics_frame
 var links=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==target and link.at.distance_to(at)<.01)
 check(links.size()==1,"Original source door and destination remain exact "+str(path.destination))
 if links.is_empty():return
 check(links[0].arrival.distance_to(Maps.source_point(target,Vector2i(10,18)))<.01,"Original annex interior arrival remains exact "+str(path.destination))
 var previous=game.model;await position_at(at+Vector2(0,3.8));game.camera_rig.yaw=0.
 var last=game.player.position
 Input.action_press("move_forward")
 for i in 100:
  last=game.player.position;await physics_frame
  if game.model!=previous:break
 Input.action_release("move_forward");await finish_boss_dialogue()
 for i in 3:await physics_frame
 check(game.model.falan_floor==target,"Normal entry still transfers before climbing "+str(path.destination))
 var porch=Maps.point(id,Vector2i(path.porch_cell[0],path.porch_cell[1]));var local_last=Vector2(last.x,last.z)/game.model.falan_scale-porch
 check(local_last.y>=float(Annexes.support_rows[0].foot_z)-.05 and absf(last.y)<.25,"Instant source transfer occurs on the ground before the ramp foot "+str(path.destination))
 if game.model.falan_floor!=target:return
 var back=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==id)
 var source_returns=Annexes.data().source_contract.original_returns.filter(func(row):return int(row[0])==destination)
 check(back.size()==source_returns.size(),"Every original annex return tile is retained "+str(destination))
 for original:Array in source_returns:
  var inside=Maps.source_point(target,Vector2i(original[1],original[2]));var outside=Maps.source_point(id,Vector2i(original[4],original[5]))
  check(back.any(func(link):return link.at.distance_to(inside)<.01 and link.arrival.distance_to(outside)<.01),"Native return tile and outside arrival remain exact "+str(original))
 if back.is_empty():return
 var direction=approach_direction(back[0].at);check(direction!=Vector2.ZERO,"Original interior has its normal walk return approach")
 if direction==Vector2.ZERO:return
 await walk_habaru_threshold(back[0].at,direction)
 check(game.model.falan_floor==id,"Normal on-foot return reaches the original outside source cell")
 if game.model.falan_floor!=id:return
 for i in 12:await physics_frame
 check(map_position().distance_to(at)<.25,"The return retains the original outside warp center")
 var return_at=map_position();var expected=Annexes.surface_height(return_at.x,return_at.y)*game.model.falan_scale
 check(expected>.5 and absf(game.player.position.y-expected)<.4,"Actual returned player stands above ground on the lower treads")
 check(game.player.is_on_floor(),"The actual returned player is supported by a floor")
 var return_y=game.player.position.y
 var pet=await stage_return_pet()
 game.camera_rig.yaw=0.;game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
 for i in 12:game.camera_rig.update_camera(1./60.);await physics_frame
 await capture("lektal-return-tread-"+str(destination),43700,cell,"Normal gameplay camera after the original on-foot return; player feet rest on the source-bounded lower tread support")
 game.camera_rig.yaw=0.;var samples=[]
 Input.action_press("move_back")
 for i in 120:
  await physics_frame
  var point=map_position();samples.append({"at":[point.x,point.y],"player_y":game.player.position.y,"model_y":game.model.world_height(game.player.position.x,game.player.position.z),"on_floor":game.player.is_on_floor()})
  if game.model.falan_floor!=id or point.y-porch.y>5.5:break
 Input.action_release("move_back")
 for i in 10:await physics_frame
 check(game.model.falan_floor==id,"Descending the original lower treads adds no transition or route")
 check(map_position().y-porch.y>5.2,"Normal movement descends the source-open lower steps")
 check(game.player.is_on_floor() and absf(game.player.position.y)<.15,"Normal descent reaches the original ground surface")
 await verify_return_pet(pet,porch)
 var slope_samples=samples.filter(func(p):return p.model_y>.2 and p.model_y<1.7 and p.on_floor)
 check(slope_samples.size()>=3,"Physical Y is sampled while walking down the represented treads")
 check(slope_samples.all(func(p):return absf(p.player_y-p.model_y)<.4),"Walking feet remain aligned with the model height on the lower steps")
 observations.append({"door_cell":[cell.x,cell.y],"destination":path.destination,"entry_last_outside_world":[last.x,last.y,last.z],"entry_before_ramp":true,"return_player_y":return_y,"return_expected_y":expected,"descended_on_foot":game.model.falan_floor==id and absf(game.player.position.y)<.15,"descent_samples":samples})


func stage_return_pet()->Dictionary:
 var army=game.army_runtime;var skin=Pets.skin("puk2:1297");var body=Dimensions.companion_body(skin);var radius=Vector2(body.size.x,body.size.z).length()*.5
 game.settings.forest_pet_loadout=[Pets.key(skin)];army.queue_hounds()
 for i in 90:
  await physics_frame
  if army.handles.has(army.HOUND_ID-skin):break
 var handle:int=army.handles.get(army.HOUND_ID-skin,0)
 check(handle!=0,"The selected existing native Cross Gate pet is summoned normally")
 if handle==0:return {}
 var point=game.model.world_point(map_position())
 check(army.native.ally_ground_clear(point,radius),"The real pet body clears the original returned tread")
 army.finish_integration();army.set_pose(handle,point,0.);army.native.set_guard(handle,point,18.)
 army.order_hounds(army.HoundOrder.RETURN)
 return {"handle":handle,"skin":skin,"radius":radius,"start":point}

func verify_return_pet(pet:Dictionary,porch:Vector2):
 if pet.is_empty():return
 var army=game.army_runtime;var samples=[]
 for i in 240:
  await physics_frame
  var row:Dictionary=army.unit_state(pet.handle)
  if row.is_empty():break
  if i%8==0:samples.append({"position":var_to_str(row.position),"native_clear":army.native.ally_ground_clear(row.position,float(pet.radius))})
  if Vector2(row.position.x,row.position.z).y/game.model.falan_scale-porch.y>5. and absf(row.position.y)<.15:break
 var final:Dictionary=army.unit_state(pet.handle)
 check(not final.is_empty(),"The native pet survives its ordinary return/follow descent")
 if not final.is_empty():
  check(Vector2(final.position.x,final.position.z).y/game.model.falan_scale-porch.y>5. and absf(final.position.y)<.15,"The actual native pet follows off the raised return onto original ground")
  check(army.native.ally_ground_clear(final.position,float(pet.radius)),"Following pet ends on native-clear source ground")
 observations.append({"pet_key":Pets.key(pet.skin),"pet_radius":pet.radius,"start":var_to_str(pet.start),"final":var_to_str(final.get("position",Vector3.INF)),"samples":samples})
 army.despawn(pet.handle);game.settings.forest_pet_loadout=[]


func tread_detail(id:int):
 var row:Dictionary=Annexes.support_rows.filter(func(item):return item.cell==Vector2i(84,65))[0]
 var depth=float(Annexes.data().graphics["1233256"].tread_depth);var front=float(row.nose_z)-depth
 var low:float=row.apron[0].x;var high:float=row.apron[1].x;var at:Vector2=row.anchor
 var center=at+Vector2((low+high)*.5,front+depth*2.)
 var scale_:float=game.model.falan_scale
 var bounds=AABB(game.model.world_point(at+Vector2(low,front)),Vector3(high-low,float(row.height),depth*4.)*scale_)
 collect_camera_canopies(1233256)
 var view=await camera_view(id,Vector2i(86,68),center,float(row.height)*scale_*.5,true,bounds)
 check(not view.is_empty(),"Four tread/risers have an original-connected gameplay detail eye")
 if view.is_empty():return
 check(camera_component.has(view.cell) and view.clear and view.framed,"Tread detail remains clear/framed on the same source walk component")
 observations.append({"view":"four-tread-detail","detail_only":true,"source_cell":[view.cell.x,view.cell.y],"source_walk_component_cells":camera_component.size(),"visual_treads":4,"visual_tread_depth":depth,"deck_height":row.height})
 await capture("lektal-four-tread-detail",43700,view.cell,"Detail of four solid risers/treads from an original-open connected gameplay eye; source dimensions unchanged")
