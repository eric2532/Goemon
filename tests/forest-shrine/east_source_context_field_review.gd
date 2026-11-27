extends "res://tests/forest-shrine/east_source_context_town_review.gd"
## Actual original100 overlay recovery. Do not run until the concrete Host proof is ready.
const Host=preload("res://scripts/forest/forest_east_host_source_context.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
const AUDIT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/"
const FIELD_OUT=Context.ROOT+"Field Actual/"
var field_edges=[]
var perimeter_edges=[]
var field_centers=[]
var manual_actors=[]
var fixed_transfers=[]
var tide_routes=[]
func field_point(cell:Vector2i)->Vector2:return Region.source_point(100,cell,game.model.falan_area)
func original_open(cell:Vector2i)->bool:
 if not Rect2i(0,0,840,610).has_point(cell):return false
 var bits=Marshalls.base64_to_raw(Context.field_restore_data().native_walk_bits);var index=cell.y*840+cell.x
 return bool(bits[index>>3]&(1<<(index&7)))
func enter_field(cell:Vector2i,area_:String="north_coast"):
 Tour.travel(game,Tour.Regions.layout(area_),{"arrival":Region.source_point(100,cell,area_),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 10:await physics_frame
 check(Host.owns(game.model) and game.model.falan_area==area_,"Concrete private original100 owner installed in "+area_)
 check(map_position().distance_to(field_point(cell))<.03,"Original100 direct arrival keeps exact source cell "+str(cell))
func native_edge(edge:Array,kind:String)->Dictionary:
 var a=Vector2i(edge[0][0],edge[0][1]);var b=Vector2i(edge[1][0],edge[1][1]);var start=game.model.world_point(field_point(a));var end=game.model.world_point(field_point(b));var clear=[true,true,true];var max_step=0.;var previous=start.y
 for sample in 21:
  var local=field_point(a).lerp(field_point(b),sample/20.);var at=game.model.world_point(local)
  for index in 3:clear[index]=clear[index] and game.army_runtime.native.ally_ground_clear(at,[.25,.49679,.60][index])
  max_step=maxf(max_step,absf(at.y-previous));previous=at.y
 check(clear.all(func(value):return value),"Actual original100 "+kind+" Native edge "+str(a)+"→"+str(b))
 return {"a":[a.x,a.y],"b":[b.x,b.y],"clear_by_radius":clear,"radii_world":[.25,.49679,.60],"samples":21,"max_height_step_world":max_step}
func native_field_contracts():
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(AUDIT+"native-shore-context.json"))
 var probes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(AUDIT+"probe-input.json"))
 var terrain=game.model.terrain;var grid=Rect2(Vector2(terrain.proposal.origin[0],terrain.proposal.origin[1]),Vector2.ONE*(terrain.width-1)*terrain.spacing)
 check(Host.domains[game.model.falan_area]==grid.intersection(game.model.navigation_bounds()),"Actual model navigation bounds and sampled grid exactly match the handoff domain")
 check(FileAccess.get_sha256(AUDIT+"native-shore-context.json")==probes.source_audit_sha256,"Original field edge inventory retains its audited source artifact")
 for row:Dictionary in audit.protected_rows:
  var cell=Vector2i(row.field_cell[0],row.field_cell[1]);var at=field_point(cell);var p=game.model.world_point(at)
  var clear=game.army_runtime.native.ally_ground_clear(p,.60)
  check(original_open(cell) and clear,"Recovered original100 shore anchor has actual Native support "+str(cell))
  check(Region.current_source(game.model,at)==100,"Original100 shore anchor retains its own map identity "+str(cell))
  field_centers.append({"cell":[cell.x,cell.y],"clear":clear,"world_height":p.y,"town_was_closed":not row.town_native_open})
 for edge:Array in probes.incident_edges:field_edges.append(native_edge(edge,"incident"))
 for edge:Array in probes.perimeter_edges:
  if original_open(Vector2i(edge[0][0],edge[0][1])) and original_open(Vector2i(edge[1][0],edge[1][1])):perimeter_edges.append(native_edge(edge,"perimeter"))
 check(field_centers.size()==430 and field_edges.size()==915 and perimeter_edges.size()==174,"All430 recovered shore anchors,915 incident edges and174 native-open perimeter edges are tested")
func press_field_key(code:int):
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func actual_field_actors():
 var tree=game.get_tree();var original_items=tree.get_meta(Events.ITEMS,{}).duplicate(true)
 tree.set_meta(Events.ITEMS,{})
 for row in [["305082",532,33,15695],["305092",533,33,15734]]:
  var id:String=row[0];var cell=Vector2i(row[1],row[2]);var matches=[];var at=field_point(cell)
  for sprite:Sprite3D in game.world.map_features.find_children("*","Sprite3D",true,false):
   if str(sprite.get_meta("npc_record",{}).get("id",""))==id:matches.append(sprite)
  var expected=at*game.model.falan_scale
  check(matches.size()==1 and matches.any(func(sprite):return Vector2(sprite.global_position.x,sprite.global_position.z).distance_to(expected)<.02),"One actual field actor keeps exact original source position "+id)
  var approach=cell+Vector2i.DOWN;var source_position=field_point(approach)
  check(original_open(approach) and game.army_runtime.native.ally_ground_clear(game.model.world_point(source_position),.60),"Actual original-open field actor approach is Native clear "+id)
  await position_at(source_position);var toward=(at-source_position).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y)
  for i in 18:await process_frame
  check(str(game.explorer_npcs.nearest.get("record",{}).get("id",""))=="source:"+id,"Normal F selection finds intended original field actor "+id)
  await press_field_key(KEY_F);check(is_instance_valid(game.dialogue),"Actual F opens original field actor dialogue "+id)
  # Complete the existing generic greeting through normal Space input, retaining
  # the source Window so this can inspect its original branch before acknowledgement.
  for i in 8:
   var current:Dictionary=game.get_meta(Events.SESSION,{})
   if str(current.get("actor",{}).get("id",""))==id:break
   await press_field_key(KEY_SPACE)
   for wait_ in 3:await process_frame
  var session:Dictionary=game.get_meta(Events.SESSION,{})
  var correct=str(session.get("actor",{}).get("id",""))==id and session.get("status","")=="window" and int(session.get("pending",{}).get("message",-1))==int(row[3])
  check(correct,"Manual field actor uses its exact source no-item branch "+id)
  manual_actors.append({"id":id,"cell":[cell.x,cell.y],"approach":[approach.x,approach.y],"sprite_matches":matches.size(),"source_branch_confirmed":correct,"source_message":row[3]})
  await finish_boss_dialogue();check(tree.get_meta(Events.ITEMS,{})=={},"Manual no-item field conversation invents no quest item "+id)
 tree.set_meta(Events.ITEMS,original_items)
func actual_fixed_transfers():
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(AUDIT+"native-shore-context.json"))
 for row:Array in audit.fixed_and_compiled_gate_pairs.fixed:
  var source=int(row[0]);var cell=Vector2i(row[1],row[2]);var target=int(row[3]);var landing=Vector2i(row[4],row[5])
  if source==100:await enter_field(cell)
  else:await enter_town(cell)
  var at=field_point(cell) if source==100 else Town.point(cell)
  var definitions=game.model.get_meta("falan_links",[]).filter(func(link):return link.at.distance_squared_to(at)<.01 and int(link.get("east_source_return",{}).get("map",-1))==target and Vector2i(link.get("east_source_return",{}).get("cell",Vector2i(-1,-1)))==landing)
  check(definitions.size()==1,"Exactly one original fixed source gate exists "+str(row))
  var direction=approach_direction(at);check(direction!=Vector2.ZERO,"Original fixed gate has an actual clear approach "+str(row))
  if direction!=Vector2.ZERO:await walk_habaru_threshold(at,direction)
  var expected=Region.source_point(target,landing,Region.source_area(target,landing) if target==100 else "")
  var arrived=Region.current_source(game.model,map_position())==target and map_position().distance_to(expected)<.04
  check(arrived,"Normal on-foot source gate preserves exact original target/landing "+str(row));fixed_transfers.append({"raw_gate":row,"definition_count":definitions.size(),"on_foot_exact_arrival":arrived,"approach":var_to_str(direction)})
 check(fixed_transfers.size()==8,"All eight directed original100/2400fixed transfers are tested")
func move_tide_on_foot(target:Vector2i,expect_change:bool)->bool:
 var previous=game.model;var destination=field_point(target);var toward=(destination-map_position()).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y)
 Input.action_press("move_forward");var reached=false
 for i in 90:
  await physics_frame
  if game.model!=previous:reached=expect_change;break
  if map_position().distance_to(destination)<.28:reached=not expect_change;break
 Input.action_release("move_forward")
 for i in 6:await physics_frame
 return reached
func actual_tide_routes():
 await enter_field(Vector2i(548,43))
 for phase in [[7.,0,16502,"10"],[9.,1,16501,"9"],[16.5,2,16501,"9"],[21.,3,16501,"9"]]:
  game.explorer_clock.load_hour(phase[0]);game.set_meta("east_auto_cooldown",{})
  var context=Events.game_context(game,{"source":100});check(int(context.nowtime)==int(phase[1]),"Actual explorer clock selects original tide phase "+str(phase[1]))
  # The test isolates cooldown history between cases, not the movement-entry predicate.
  # Both548,43and549,43are original-open;550,43is original-closed and is not used.
  for i in 18:await physics_frame
  var entered=await move_tide_on_foot(Vector2i(549,43),true);var expected=int(phase[2]);var actual=Tour.Winter.Recovered.source_id(game.model.falan_floor) if game.model.falan_area=="interior" else -1
  check(entered and actual==expected,"On-foot automatic actor "+str(phase[3])+" enters original tide map for phase"+str(phase[1]))
  if not entered or actual!=expected:return
  var inside=Events.game_context(game,{"source":expected});check(inside.cell==Vector2i(39,34),"Tide entrance keeps exact original39,34landing "+str(expected))
  var returns=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("east_source_return",{}).get("map",-1))==100 and Vector2i(link.get("east_source_return",{}).get("cell",Vector2i(-1,-1)))==Vector2i(549,43))
  check(returns.size()==1,"Tide room has exactly one original100(549,43)return "+str(expected))
  if returns.is_empty():return
  var reverse=approach_direction(returns[0].at);check(reverse!=Vector2.ZERO,"Tide return has a real clear on-foot approach "+str(expected))
  if reverse!=Vector2.ZERO:await walk_habaru_threshold(returns[0].at,reverse)
  var returned=game.model.falan_area=="north_coast" and map_position().distance_to(field_point(Vector2i(549,43)))<.04
  check(returned,"Tide return preserves exact original549,43without nudge "+str(expected))
  if not returned:return
  # Expire only this fixture's automatic cooldown to prove arrival lock behavior
  # independently of the original60second throttle.
  game.set_meta("east_auto_cooldown",{});var arrival_model=game.model
  for i in 24:await physics_frame
  var held=game.model==arrival_model and map_position().distance_to(field_point(Vector2i(549,43)))<.05
  check(held,"Exact stationary tide arrival does not bounce with cooldown expired "+str(phase[1]))
  var left=await move_tide_on_foot(Vector2i(548,43),false)
  check(left and game.model==arrival_model,"Player leaves the source-open tide cell on foot before reentry "+str(phase[1]))
  tide_routes.append({"phase":phase[1],"hour":phase[0],"actor":phase[3],"source_floor":expected,"entered_on_foot":entered,"exact_interior_landing":inside.cell==Vector2i(39,34),"returned_on_foot_exact":returned,"stationary_no_bounce_with_expired_cooldown":held,"left_on_foot":left})
 check(tide_routes.size()==4,"All four original clock masks and both tide map returns are exercised")
func run():
 root.size=Vector2i(1440,900);phase="SeparateOriginal100";review_area="north_coast"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIELD_OUT));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 Context.reset();Context.host_owner=Host
 check(Context.host_ready(),"Concrete original100 terrain/native/handoff proof must be ready before actual scene activation")
 if not Context.host_ready():printerr("FIELD_ACTUAL_NOT_RUN: finish concrete Host proof; no source blocker is inferred");quit(1);return
 var town_proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Context.ROOT+"Town Actual/Review03/review.json"));var paths:Array=town_proof.source_hashes.keys()
 paths.append_array([get_script().resource_path,"scripts/forest/forest_east_host_source_context.gd","scripts/forest/forest_east_host_source_field.gd",Host.ROOT+"manifest.json",Host.ROOT+"contract-proof.json",Context.ROOT+"100.dat",Context.ROOT+"field100-restore.json",Context.ROOT+"freyja_ground_atlas.png",Context.ROOT+"freyja_ground_index.png",AUDIT+"native-shore-context.json",AUDIT+"probe-input.json","scripts/player.gd","scripts/forest/forest_explorer_npcs.gd","scripts/forest/forest_explorer_clock.gd"])
 for area_:String in ["east_gate","north_coast"]:
  var spec:Dictionary=Host.manifest().areas[area_];paths.append(spec.path)
  var data:Dictionary=Host.data(area_);paths.append(data.mask_path)
 var passing_proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Host.ROOT+"contract-proof.json"));paths.append_array(passing_proof.source_hashes.keys())
 var boundaries:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Host.ROOT+"player-boundaries.json"));paths.append(Host.ROOT+"player-boundaries.json");paths.append(boundaries.boundary_metadata_raw_path)
 var before=Fresh.snapshot(paths)
 check(Tour.Regions.private_source_context==null,"Original100 fixture starts with the canonical context disabled")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-separate-field-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false);Tour.Regions.private_source_context=Context
 await enter_field(Vector2i(532,33))
 await native_field_contracts()
 await actual_field_actors()
 if "--routes" in OS.get_cmdline_user_args():
  await actual_fixed_transfers()
  await actual_tide_routes()
 var changed=Fresh.changed(before);check(changed.is_empty(),"Actual original100 scene proof remains source-current")
 game.queue_free();for i in 4:await process_frame
 Tour.Regions.private_source_context=null;Context.reset()
 check(Tour.Regions.private_source_context==null and Context.host_owner==null,"Actual original100 fixture relinquishes all private ownership")
 var report={"checks":checks,"failures":errors,"field_centers":field_centers,"field_incident_edges":field_edges,"field_perimeter_edges":perimeter_edges,"manual_actors":manual_actors,"fixed_transfers":fixed_transfers,"tide_routes":tide_routes,"source_hashes":before,"source_changed_during_run":changed,"scope":"PRIVATE actual original100 North-frame full-envelope430shore/915incident/174perimeter Native geometry and exact305082/305092 positions, native approaches and normal F/source no-item dialogue. Optional--routes records eight Town transfers and four tide variants/returns, including exact standstill and leave/reentry; empty arrays mean not run. Same-source scene seam movement, pet locomotion and visual captures remain separate unfinished contracts. No canonical activation or full region completion."}
 var file=FileAccess.open(FIELD_OUT+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("EAST_SOURCE_CONTEXT_FIELD checks=",checks," failures=",errors," edges=",field_edges.size()," perimeter=",perimeter_edges.size());quit(1 if errors else 0)
