extends "res://tests/forest-shrine/east_village_buildings_review.gd"
## Focused source completion, existing gate/house/harbor routes and explicit shore physics.
const IlSource=preload("res://scripts/forest/forest_east_il_source_completion.gd")
const IlOwner=preload("res://scripts/forest/forest_il_laruka_art.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const Recovered=preload("res://scripts/forest/forest_original_maps.gd")
const Harbor=preload("res://scripts/forest/forest_east_harbor.gd")
const BankCaps=preload("res://scripts/forest/forest_east_bank_caps.gd")
const BankPets=preload("res://scripts/forest/pet_catalog.gd")
const IL_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/"
var shore_audit=[]
var harbor_audit=[]
var allied_probe:Object

func _initialize():
 create_timer(900,true,false,true).timeout.connect(func():printerr("IL_SOURCE_COMPLETION_TIMEOUT");quit(2))
 run.call_deferred()

func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_east_il_source_completion.gd","scripts/forest/forest_il_laruka_art.gd","scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_freyja_art.gd","scripts/forest/forest_falan_frontier.gd","scripts/forest/forest_original_map_solids.gd","scripts/forest/forest_original_map_art.gd","scripts/forest/forest_east_harbor.gd","assets/maps/falan/east_region/il_source_completion/data.json","assets/maps/falan/east_region/il_source_completion/hybrid-map.bin","assets/maps/falan/east_region/il_source_completion/mask.png","assets/maps/falan/east_region/il_source_completion/ground-index.png","assets/maps/falan/il_laruka/data.gd","assets/maps/falan/il_village_ground_atlas.png","assets/maps/falan/east_region/harbor.json","assets/maps/falan/east_region/routes.json","assets/maps/falan/east_region/population.json","assets/maps/original_crossgate/east/catalog.json"]
 paths.append_array(["scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_kai_terrain.gd","scripts/forest/forest_ramparts.gd","scripts/forest/crowd/army_runtime.gd","native/terrain_math/crowd/terrain.cpp","native/terrain_math/crowd/terrain.h","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib","assets/maps/falan/east_region/bank_caps/data.json","assets/maps/falan/east_region/bank_caps/surfaces.png"])
 paths.append_array(["scripts/forest/forest_falan_fort_parts.gd","scripts/forest/forest_rampart_art.gd"])
 var focused="--banks-only" in OS.get_cmdline_user_args()
 var final_banks="--final-banks" in OS.get_cmdline_user_args()
 var post_adapter="--post-adapter" in OS.get_cmdline_user_args()
 var before=Fresh.snapshot(paths);root.size=Vector2i(1440,900);phase="IlSourceCompletionPostAdapter" if post_adapter else "IlSourceCompletionFinalBanks" if final_banks else "IlSourceCompletionBanks" if focused else "IlSourceCompletion";review_area="il_village"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IL_OUT));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 check(IlSource.rows(2300,IlOwner.Data.MAPS[2300])==IlOwner.Data.MAPS[2300],"Laruka source owner is unchanged")
 var source_rows=IlSource.rows(2000,IlOwner.Data.MAPS[2000])
 check(source_rows.size()==IlOwner.Data.MAPS[2000].size()+6,"Il supplement appends exactly six existing bank forms")
 check(source_rows.slice(0,IlOwner.Data.MAPS[2000].size())==IlOwner.Data.MAPS[2000],"Every original Il object row/order is preserved")
 check(IlSource.rows(2000,[]).size()==6 and IlSource.rows(2000,IlOwner.Data.MAPS[2000]).size()==source_rows.size(),"A fixture's empty existing array cannot poison the live Il rows")
 check(FileAccess.get_sha256("res://assets/maps/falan/east_region/il_source_completion/hybrid-map.bin")==IlSource.data().hybrid_sha256,"Published candidate is the audited unknown-only hybrid")
 var state=Recovered.state(2000);check(state.get("source_path","")=="" or state.size==Vector2i(90,120),"Source catalog retains original Il dimensions")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-il-completion-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 game.settings.forest_pet_loadout=[]
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate");await site(2000,"il_village")
 if not focused:
  var gate=Tour.Regions.village_transform("il_village")*Tour.Regions.IL_GATE
  var across=Tour.Regions.village_transform("il_village").basis_xform(Vector2.RIGHT)
  await walk_connected_gate(gate,across,"Il completed source");await walk_connected_gate(gate,-across,"Il completed source return")
  await source_contracts(2000)
  await harbor_transfer("305024",2000,Vector2i(59,71),33219,Vector2i(22,20))
  await harbor_transfer("305141",33219,Vector2i(24,18),2000,Vector2i(57,71))
 if Tour.area(game.model)!="east_gate":await open_area("east_gate");await site(2000,"il_village")
 # The public can_reach method queries hostile road barriers. A separate test
 # runtime receives the exact friendly data; the live army itself is unchanged.
 var friendly:Dictionary=game.army_runtime.navigation_data(game.model,true)
 friendly.obstacle_min=friendly.friendly_obstacle_min;friendly.obstacle_max=friendly.friendly_obstacle_max;friendly.friendly_navigation=false
 allied_probe=ClassDB.instantiate("GoemonCrowdRuntime");allied_probe.set_navigation(friendly)
 await shore_measurements()
 known_shore_inventory()
 await shore_camera("il-completed-northern-shore-normal",Vector2i(31,7),Vector2i(31,3))
 await shore_camera("il-completed-northern-shore-second",Vector2i(33,9),Vector2i(31,3))
 await shore_camera("il-completed-right-bank-normal",Vector2i(77,70),Vector2i(77,73))
 await shore_camera("il-completed-right-bank-second",Vector2i(77,73),Vector2i(77,70))
 var changed=Fresh.changed(before);check(changed.is_empty(),"Loaded Il completion sources remain current")
 var file=FileAccess.open(IL_OUT+("banks-post-adapter-review.json" if post_adapter else "banks-final-review.json" if final_banks else "banks-focused-review.json" if focused else "actual-review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"source_hashes":before,"source_changed_during_run":changed,"captures":captures,"building_placements":placement_audit,"house_round_trips":door_audit,"harbor_transfers":harbor_audit,"shore_measurements":shore_audit,"source_hybrid":IlSource.data().hybrid_sha256,"scope":"Focused Il source completion: existing connected gate both directions, six unchanged house connections, actual F harbor transfer/return, six dry new shore cells and six wet bank-lip placements/clearance. Eight unaccelerated ship directions are not rerun; their route/clock code is unchanged. Source assertions and visual judgment remain separate."},"  "));file.close()
 print("EAST_IL_COMPLETION_RESULT checks=",checks," failures=",errors," shore_rows=",shore_audit.size());await finish()

func source_world(source:int,cell:Vector2i)->Vector2:
 return village_cell(cell) if source==2000 else Recovered.source_point(Recovered.runtime_id(source),cell)

func press_key(code:int):
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame

func harbor_transfer(actor:String,source:int,cell:Vector2i,destination:int,landing:Vector2i):
 var source_ready=Tour.area(game.model)=="east_gate" if source==2000 else game.model.falan_floor==Recovered.runtime_id(source)
 check(source_ready,"Harbor manager is tested in its original source world "+actor)
 if not source_ready:return
 var at=source_world(source,cell);var found=false;var chosen=Vector2.ZERO;var initial_gold=int(game.model.gold)
 for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
  var stand=at+direction*3.
  if not game.model.terrain.disk_clear(Vector3(stand.x,0,stand.y),.55):continue
  await position_at(stand);var facing=(at-stand).normalized();game.camera_rig.yaw=atan2(-facing.x,-facing.y)
  for i in 18:await physics_frame
  if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+actor:found=true;chosen=stand;break
 check(found,"Normal F selector reaches original harbor manager "+actor)
 if not found:harbor_audit.append({"actor":actor,"found":false});return
 await press_key(KEY_F);check(is_instance_valid(game.dialogue),"F opens source harbor dialogue "+actor)
 for i in 12:
  if not is_instance_valid(game.dialogue):break
  await press_key(KEY_SPACE)
 for i in 16:await physics_frame
 var arrived=Tour.area(game.model)=="east_gate" if destination==2000 else game.model.falan_floor==Recovered.runtime_id(destination)
 check(arrived,"Harbor F dialogue preserves original transfer destination "+actor)
 var wanted=source_world(destination,landing)
 check(arrived and map_position().distance_to(wanted)<.35,"Harbor transfer retains original landing cell "+str(landing))
 check(game.model.gold==initial_gold,"Existing zero-fare harbor transfer remains unchanged "+actor)
 harbor_audit.append({"actor":actor,"source":source,"source_cell":cell,"stand":chosen,"target":destination,"landing":landing,"arrived":arrived,"actual_position":map_position()})

func shore_measurements():
 for row:Dictionary in IlSource.data().native_walk.added_open_cells:
  if int(row.source_object)!=0:continue
  var cell=Vector2i(row.cell[0],row.cell[1]);var at=village_cell(cell);var point=game.model.world_point(at)
  check(IlSource.source_open(cell),"Exact source attributes keep the newly recovered shore cell open "+str(cell))
  var radii=[];var native_clear=true
  for radius in [.25,.35,.60]:
   var clear=game.army_runtime.native.ally_ground_clear(point,radius);native_clear=native_clear and clear;radii.append({"radius":radius,"clear":clear})
  var west=village_cell(cell+Vector2i.LEFT);var land_height=game.model.surface_height(west.x,west.y)
  var record={"source_cell":cell,"source_floor":row.source_floor,"source_object":row.source_object,"client_marker":row.client_marker,"candidate_local_height":point.y/game.model.falan_scale,"terrain_disk_clear":game.model.terrain.disk_clear(Vector3(at.x,point.y/game.model.falan_scale,at.y),.55),"native_clearance":radii,"western_source_neighbor_height":land_height,"kind":"dry_shore"}
  check(native_clear and record.terrain_disk_clear,"Recovered dry shore has actual terrain/native clearance "+str(cell))
  var toward=village_cell(Vector2i(31,7));record.reachable_from_original_land=allied_probe.can_reach(game.model.world_point(toward),point,.35)
  check(record.reachable_from_original_land,"New dry shore remains connected to the original adjacent land "+str(cell))
  shore_audit.append(record)
 for row:Dictionary in IlSource.data().new_bank_caps:await bank_measurement(row)

func il_point(at:Array)->Vector2:
 return Tour.Regions.village_transform("il_village")*Vector2(at[0],at[1])

func bank_measurement(row:Dictionary):
 var cell=Vector2i(row.source_cell[0],row.source_cell[1]);var anchor=village_cell(cell);var point=game.model.world_point(anchor)
 var scale_:float=game.model.falan_scale;var frame=Tour.Regions.village_transform("il_village");var record={"source_cell":cell,"serial":row.serial,"source_open":IlSource.source_open(cell),"visible_cap_native_alpha":true,"inferred_hidden_support":row.support_only_rects,"dry_join_rects":row.join_rects,"native_clearance":[],"approach_samples":[]}
 check(record.source_open and absf(point.y-6.*scale_)<.02,"Original-open source bank anchor keeps6m support "+str(cell))
 var count=game.model.terrain.pieces.size();IlSource.install(game.model)
 check(game.model.terrain.pieces.size()==count,"Repeated setup cannot duplicate cap support "+str(cell))
 var path=[]
 for at:Array in row.source_path_points:path.append(il_point(at))
 path.append(anchor)
 for radius in [.25,.35,.60]:
  var clear=game.army_runtime.native.ally_ground_clear(point,radius);record.native_clearance.append({"radius":radius,"anchor_clear":clear})
  check(clear,"Actual native keeps the explicit open bank anchor radius"+str(radius)+" "+str(cell))
  for index in range(1,path.size()):
   var a=game.model.world_point(path[index-1]);var b=game.model.world_point(path[index])
   check(allied_probe.can_reach(a,b,radius) and allied_probe.can_reach(b,a,radius),"Isolated current friendly native data retains original bank approach and return radius"+str(radius)+" "+str(cell))
   var samples=maxi(1,ceili(a.distance_to(b)/.1))
   for part in range(samples+1):
    var p=a.lerp(b,float(part)/samples)
    check(game.army_runtime.native.ally_ground_clear(p,radius),"Continuous native approach has no hidden terrain seam "+str(cell))
 var matches=[]
 for node:MultiMeshInstance3D in game.world.find_children("*","MultiMeshInstance3D",true,false):
  if int(node.get_meta("source_graphic",-1))!=int(row.serial) or node.multimesh==null:continue
  for index in node.multimesh.instance_count:
   var pose=node.global_transform*node.multimesh.get_instance_transform(index)
   if Vector2(pose.origin.x,pose.origin.z).distance_to(anchor*scale_)>.03:continue
   var bounds=pose*node.multimesh.mesh.get_aabb();matches.append({"position":pose.origin,"world_aabb":str(bounds),"world_top":bounds.end.y,"new_owner":node.get_meta("native_source_bank_cap",false)})
 check(matches.size()==1 and matches[0].new_owner,"One bounded native cap replaces the below-water bank at its exact anchor "+str(cell))
 check(not matches.is_empty() and absf(float(matches[0].world_top)-6.*scale_)<.03,"Visible native grass sits at the adjacent source land height "+str(cell))
 record.actual_owners=matches
 var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.,point-Vector3.UP*3.,1)
 var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty() and int(hit.collider.get_meta("native_bank_cap",-1))==int(row.serial) and absf(hit.position.y-point.y)<.02,"Static floor and model agree at the original source bank anchor "+str(cell))
 var water=anchor+frame.basis_xform(Vector2(1.65,0));var wp=Vector3(water.x*scale_,6.*scale_,water.y*scale_)
 check(not game.model.terrain.contains(water.x,water.y) and not game.army_runtime.native.ally_ground_clear(wp,.25),"Adjacent ordinary source water stays void "+str(cell))
 record.adjacent_water_rejected=not game.army_runtime.native.ally_ground_clear(wp,.25)
 await position_at(path[0]);var pet=await bank_pet()
 for i in 24:await physics_frame
 for index in range(1,path.size()):record.approach_samples.append_array(await walk_bank_point(path[index],str(cell)))
 check(map_position().distance_to(anchor)<.25 and game.player.is_on_floor() and absf(game.player.position.y-6.*scale_)<.35,"Normal player walks onto the original open source bank anchor "+str(cell))
 if not pet.is_empty():
  await command_bank_pet(pet,map_position(),str(cell))
  game.army_runtime.order_hounds(game.army_runtime.HoundOrder.RETURN)
 for index in range(path.size()-2,-1,-1):record.approach_samples.append_array(await walk_bank_point(path[index],str(cell)+" return"))
 var retreat_cell=Vector2i(76,73 if cell.y<=71 else 70);var retreat=village_cell(retreat_cell)
 await walk_bank_point(retreat,str(cell)+" source land retreat")
 if not pet.is_empty():
  # Normal movement aims the unchanged slot0 formation onto another original
  # dry cell: its(-7,+3.5)m offset becomes purely along this narrow shore.
  var facing=Vector2(2,-1).normalized() if cell.y<=71 else Vector2(-2,1).normalized()
  await walk_bank_point(retreat+frame.basis_xform(facing*.4),str(cell)+" ordinary formation-facing turn")
  for i in 24:await physics_frame
  game.army_runtime.order_hounds(game.army_runtime.HoundOrder.RETURN)
  for i in 240:await physics_frame
  var final:Dictionary=game.army_runtime.unit_state(pet.handle)
  check(not final.is_empty() and game.army_runtime.native.ally_ground_clear(final.position,float(pet.radius)),"Normally summoned native pet follows back onto original-clear ground "+str(cell))
  if not final.is_empty():
   var local=frame.inverse()*(Vector2(final.position.x,final.position.z)/scale_)
   check(local.x<94.5 and absf(final.position.y-6.*scale_)<.1,"Pet RETURN follows off the bank toward original recorded land "+str(cell))
   record.pet_final=var_to_str(final.position)
  record.pet_radius=pet.radius;record.pet_approach=pet.get("approach_samples",[]);game.army_runtime.despawn(pet.handle);game.settings.forest_pet_loadout=[]
 check(game.player.is_on_floor() and absf(game.player.position.y-6.*scale_)<.35,"Normal player return meets the existing6m source land continuously "+str(cell))
 shore_audit.append(record)

func walk_bank_point(target:Vector2,label:String)->Array:
 var samples=[]
 var budget=ceili(target.distance_to(map_position())*game.model.falan_scale/2.2*60.)+180
 Input.action_press("walk_modifier")
 for i in budget:
  var delta=target-map_position()
  if delta.length()<.055:break
  game.camera_rig.yaw=atan2(-delta.x,-delta.y);game.camera_rig.update_camera(1./60.)
  Input.action_press("move_forward");await physics_frame
  if i%3==0:samples.append({"position":var_to_str(game.player.position),"on_floor":game.player.is_on_floor(),"model_y":game.model.world_height(game.player.position.x,game.player.position.z)})
 Input.action_release("move_forward")
 Input.action_release("walk_modifier")
 for i in 16:await physics_frame
 check(map_position().distance_to(target)<.25,"Actual directional movement reaches source-bank waypoint "+label)
 check(samples.all(func(p):return p.on_floor and absf(str_to_var(p.position).y-float(p.model_y))<.4),"Actual player feet remain supported along the bank approach "+label)
 return samples

func bank_pet()->Dictionary:
 var army=game.army_runtime;var skin=BankPets.skin("puk2:1297");var body=Dimensions.companion_body(skin);var radius=Vector2(body.size.x,body.size.z).length()*.5
 game.settings.forest_pet_loadout=[BankPets.key(skin)];army.queue_hounds()
 for i in 100:
  await physics_frame
  if army.handles.has(army.HOUND_ID-skin):break
 var handle:int=army.handles.get(army.HOUND_ID-skin,0)
 check(handle!=0,"Existing Cross Gate pet is summoned normally on recorded source land")
 return {} if handle==0 else {"handle":handle,"skin":skin,"radius":radius}

func command_bank_pet(pet:Dictionary,target:Vector2,label:String):
 var army=game.army_runtime
 for i in 24:await physics_frame
 var point:Vector3=game.player.position
 check(army.native.ally_ground_clear(point,float(pet.radius)),"Actual pet body clears each source-bank waypoint "+label)
 # A normal click on the stationary hero has zero formation direction, hence
 # no7m lateral party offset. The pet still uses its ordinary native controller.
 check(army.order_hounds(army.HoundOrder.ATTACK,0,point),"Normal click on the hero's source-bank position commands the summoned pet")
 var samples=[]
 for i in 360:
  await physics_frame
  var state:Dictionary=army.unit_state(pet.handle)
  if not state.is_empty() and i%6==0:samples.append({"position":var_to_str(state.position),"native_clear":army.native.ally_ground_clear(state.position,float(pet.radius))})
  if not state.is_empty() and Vector2(state.position.x-point.x,state.position.z-point.z).length()<1.03:break
 var final:Dictionary=army.unit_state(pet.handle)
 check(not final.is_empty() and Vector2(final.position.x-point.x,final.position.z-point.z).length()<1.05 and absf(final.position.y-point.y)<.15,"Normally commanded native pet traverses the original source-bank route "+label)
 check(samples.all(func(row):return row.native_clear),"Every observed pet approach sample stays on native-clear support "+label)
 pet.approach_samples=samples

func shore_camera(label:String,stand:Vector2i,target:Vector2i):
 var at=village_cell(stand);var target_at=village_cell(target)
 check(IlSource.source_open(stand),"Shore camera uses an explicit original-open source stand "+str(stand))
 check(absf(game.model.surface_height(at.x,at.y)-6.)<.025,"Shore camera stands on source-proven6m support rather than submerged bank art "+str(stand))
 check(game.model.terrain.disk_clear(Vector3(at.x,6.,at.y),.55),"Ordinary shore camera stand remains physically clear")
 await position_at(at)
 for i in 16:await physics_frame
 var toward=(target_at-at).normalized();var yaw=atan2(-toward.x,-toward.y)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
 for i in 24:await physics_frame;game.camera_rig.update_camera(1./60.)
 var camera:Camera3D=game.camera_rig.camera;var point=game.model.world_point(target_at,.05)
 check(camera.global_position.y>6.*game.model.falan_scale+.5,"Ordinary shore camera remains above the represented source land")
 check(camera.is_position_in_frustum(point),"Ordinary shore camera frames the source recovery")
 check(game.camera_rig.current_distance>game.camera_rig.unobstructed_distance*.8,"Ordinary shore camera retains its normal follow distance")
 observations.append({"shore_camera":label,"source_stand":stand,"target_source_cell":target,"ordinary_pitch":.32,"physical_stand_world":var_to_str(game.player.position),"camera_distance":game.camera_rig.current_distance,"desired_camera_distance":game.camera_rig.unobstructed_distance,"source_open":true})
 await gameplay_capture(label,"Ordinary gameplay camera from authoritative original-open represented6m source support "+str(stand)+"; source-blocked/wet-bed stands are excluded",yaw)

func known_shore_inventory():
 # Read-only closure ledger: these known visual owners are not accepted by the
 # six-placement support result, and the four blocked controls gain no floor.
 var owners={};var scale_:float=game.model.falan_scale
 for node:MultiMeshInstance3D in game.world.find_children("*","MultiMeshInstance3D",true,false):
  var serial=int(node.get_meta("source_graphic",-1))
  if serial<12500 or serial>12535 or node.multimesh==null:continue
  for index in node.multimesh.instance_count:
   var pose=node.global_transform*node.multimesh.get_instance_transform(index)
   var key=Vector2i((Vector2(pose.origin.x,pose.origin.z)*100.).round());var list=owners.get(key,[])
   list.append({"serial":serial,"position":pose.origin,"world_bounds":str(pose*node.multimesh.mesh.get_aabb()),"world_top":(pose*node.multimesh.mesh.get_aabb()).end.y,"new_owner":node.get_meta("native_source_bank_cap",false)})
   owners[key]=list
 var rows=[];var underwater=0;var known_count=0;var blocked=[]
 for row:Array in IlSource.rows(2000,IlOwner.Data.MAPS[2000]):
  if int(row[2])<12500 or int(row[2])>12535:continue
  var cell=Vector2i(row[0],row[1]);var at=village_cell(cell);var matches:Array=owners.get(Vector2i((at*scale_*100.).round()),[])
  var fresh=IlSource.owns_bank(2000,row);var source_open=IlSource.source_open(cell);var low=not matches.is_empty() and float(matches[0].world_top)<2.*scale_+.05
  if not fresh:known_count+=1;underwater+=int(low)
  var entry={"source_cell":cell,"serial":int(row[2]),"original_cache_known":not fresh,"derived_attribute_open":source_open,"actual_owners":matches,"model_local_height":game.model.surface_height(at.x,at.y),"below_water":low,"source_complete_scope":"new_six_candidate" if fresh else "known_visual_owner_unfinished_actual_inventory"}
  rows.append(entry)
  if not source_open:
   blocked.append(entry);check(not fresh and matches.all(func(owner):return not owner.new_owner),"An original blocked bank control receives no new source support "+str(cell))
 check(rows.size()==393 and known_count==387 and blocked.size()==4,"Full Il bank census remains393visual/387known/6new and4source-blocked")
 var file=FileAccess.open(IL_OUT+"known-shore-actual-inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source":2000,"source_hybrid":IlSource.data().hybrid_sha256,"visual_bank_placements":rows.size(),"known_visual_placements":known_count,"known_visibly_underwater":underwater,"source_attribute_open":389,"source_blocked_controls":blocked,"rows":rows,"status":"Read-only actual closure inventory. Six new cap acceptance does not establish whole Il shoreline acceptance; inaccurate known owners remain actionable."},"  "));file.close()
