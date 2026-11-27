extends "res://tests/forest-shrine/east_village_buildings_review.gd"
## Process-only compatible source completion. No canonical asset publication.
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const Field=preload("res://scripts/forest/forest_east_field_cliffs.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
const ALYUT_FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate/"
var bank_probes=[]
var underlay_audit={}
var overlap_audit=[]
var run_folder=ALYUT_FOLDER
var report_folder=ALYUT_FOLDER
const STAGE_FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Canonical Stage/"
const BODY_FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Body Material Candidate/"
func run():
 var published="--published" in OS.get_cmdline_user_args()
 run_folder=Full.ROOT if published else STAGE_FOLDER if "--stage" in OS.get_cmdline_user_args() else ALYUT_FOLDER
 report_folder=STAGE_FOLDER+"Canonical Review/" if published else run_folder
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_folder))
 Full.review_root="" if published else run_folder
 root.size=Vector2i(1440,900);phase="FullAlyutCanonical" if published else "FullAlyutStagePrivate" if "--stage" in OS.get_cmdline_user_args() else "FullAlyutBodyPrivate" if "--bank-body-material" in OS.get_cmdline_user_args() else "FullAlyutUnderlayPrivate" if "--bank-underlay" in OS.get_cmdline_user_args() else "FullAlyutPrivate";review_area="alyut"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 var paths=[get_script().resource_path.trim_prefix("res://"),"scripts/forest/forest_east_alyut_source_completion.gd","scripts/forest/forest_east_bank_caps.gd","scripts/forest/forest_east_region.gd","scripts/forest/forest_rampart_art.gd","scripts/forest/forest_falan_frontier.gd","scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_freyja_art.gd","scripts/forest/forest_east_field_cliffs.gd","assets/maps/falan/east_region/bank_caps/data.json",String(run_folder+"map-data.json").trim_prefix("res://"),String(run_folder+"banks.json").trim_prefix("res://")]
 paths.append_array(["tests/forest-shrine/east_village_buildings_review.gd","tests/forest-shrine/east_village_props_review.gd","tests/forest-shrine/il_chief_review.gd","tests/forest-shrine/east_region_review.gd","tests/forest-shrine/freyja_villages_habaru_test.gd"])
 paths.append_array(["scripts/forest/forest_model.gd","scripts/forest/crowd/army_runtime.gd","scripts/forest/forest_original_maps.gd"])
 if FileAccess.file_exists(run_folder+"gate-handoffs.json"):paths.append(String(run_folder+"gate-handoffs.json").trim_prefix("res://"))
 if "--bank-underlay" in OS.get_cmdline_user_args() or "--stage" in OS.get_cmdline_user_args() or published:paths.append_array(["scripts/forest/forest_east_bank_underlay.gd","scripts/forest/wind_meadow_ground.gdshader","assets/maps/freyja_west_gate/water.gdshader"])
 if "--bank-body-material" in OS.get_cmdline_user_args():paths.append_array([String(BODY_FOLDER+"surfaces.png").trim_prefix("res://"),String(BODY_FOLDER+"source-contract.json").trim_prefix("res://"),String(BODY_FOLDER+"material-review.json").trim_prefix("res://")])
 if "--stage" in OS.get_cmdline_user_args() or published:
  var manifest_file="prepared-source-manifest.json" if published else "publication.json"
  var publication:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(run_folder+manifest_file))
  paths.append(String(run_folder+manifest_file).trim_prefix("res://"))
  if published:check(FileAccess.get_sha256(run_folder+manifest_file)==FileAccess.get_sha256(STAGE_FOLDER+"publication.json"),"Canonical prepared-source manifest exactly equals the reviewed staged manifest")
  for relative:String in publication.runtime_files:
   paths.append(String(run_folder+relative).trim_prefix("res://"))
   if published:check(FileAccess.get_sha256(run_folder+relative)==publication.runtime_files[relative],"Published asset equals the reviewed source file "+relative)
  for path:String in publication.source_inputs:paths.append(path)
 var hashes=Sources.snapshot(paths)
 check(Full.enabled() and Full.review_root.is_empty() and Full.folder()==Full.ROOT if published else not FileAccess.file_exists(Full.ROOT+"map-data.json"),"Published Alyut uses the canonical default owner without a review-root override" if published else "Complete Alyut stays process-only private")
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-full-alyut-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("north_coast");await site(2400,"alyut")
 if "--bank-underlay" in OS.get_cmdline_user_args() or "--stage" in OS.get_cmdline_user_args() or published:apply_bank_underlay()
 if "--bank-body-material" in OS.get_cmdline_user_args():apply_bank_body_material()
 await scene_contracts()
 if "--overlap-checks" in OS.get_cmdline_user_args():await source_overlap_probes()
 if "--gates-only" not in OS.get_cmdline_user_args() and "--banks-only" not in OS.get_cmdline_user_args() and "--minimal-default" not in OS.get_cmdline_user_args():await source_contracts(2400)
 if "--banks-only" not in OS.get_cmdline_user_args():await check_alyut_coast_gates()
 if "--gates-only" not in OS.get_cmdline_user_args() and "--material-only" not in OS.get_cmdline_user_args():await source_bank_probes()
 if "--banks-only" in OS.get_cmdline_user_args() or "--minimal-default" in OS.get_cmdline_user_args():
  await prop_views("full-alyut-source-shore",Vector2i(39,13),Vector2i(47,18),Vector2i(43,7))
  await prop_views("full-alyut-close-bank",Vector2i(66,18),Vector2i(61,16),Vector2i(63,14))
 elif "--gates-only" in OS.get_cmdline_user_args():
  await prop_views("full-alyut-north-gate",Vector2i(58,35),Vector2i(58,27),Vector2i(58,31))
  await prop_views("full-alyut-south-gate",Vector2i(66,66),Vector2i(66,60),Vector2i(66,64))
  await bank_visual_diagnostic()
 else:
  await prop_views("full-alyut-source-north",Vector2i(39,13),Vector2i(47,18),Vector2i(43,7))
  await prop_views("full-alyut-stable-context",Vector2i(51,44),Vector2i(63,35),Vector2i(60,41))
 if "--wedge-diagnostic" in OS.get_cmdline_user_args():await wedge_diagnostic()
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Private completion inputs remain current through actual review")
 var file=FileAccess.open(report_folder+("actual-bank-body-review.json" if "--bank-body-material" in OS.get_cmdline_user_args() else "actual-underlay-review.json" if "--bank-underlay" in OS.get_cmdline_user_args() else "actual-review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"doors":door_audit,"building_placements":placement_audit,"bank_probes":bank_probes,"source100_overlap":overlap_audit,"bank_underlay":underlay_audit,"source_hashes":hashes,"source_changed_during_run":changed,"source_hybrid_sha256":Full.data().source.sha256,"prior_unchanged_house_bank_evidence":ALYUT_FOLDER+"actual-review-01.json" if "--gates-only" in OS.get_cmdline_user_args() or "--banks-only" in OS.get_cmdline_user_args() or "--minimal-default" in OS.get_cmdline_user_args() else "","prior_unchanged_gate_evidence":"actual-review-03.json" if "--banks-only" in OS.get_cmdline_user_args() else "","canonical_default_owner":published,"review_root_override":Full.review_root,"scope":"Published default full2400 compatible source recovery; no review-root override. Original gate/support/overlap routes and current normal/second views; unchanged earlier five-house proof remains separate." if published else "Private full2400 compatible source recovery in the existing joined Alyut owner. Exact scene placement, original on-foot gates and actual gameplay views. The first full run separately records five passed house enter/returns and117bank anchor/lip stands; a focused rerun does not repeat or replace unchanged evidence. Visual acceptance remains separate; canonical cliff material candidate is not published by this fixture."}," "));file.close()
 print("EAST_ALYUT_COMPLETE_REVIEW checks=",checks," failures=",errors," bankprobes=",bank_probes.size());await finish()

func wedge_diagnostic():
 var cell=walkable_anchor(Vector2i(39,13));var at=village_cell(cell);await position_at(at)
 var facing=(village_cell(Vector2i(43,7))-at).normalized();var yaw=atan2(-facing.x,-facing.y)
 var caps=game.world.map_features.find_children("NativeSourceBankCap_*","GeometryInstance3D",true,false);var ground=[]
 for valley:Node3D in game.world.map_features.find_children("WindMeadowValley","Node3D",true,false):
  for node in valley.get_children():
   if node is MeshInstance3D and node.material_override is ShaderMaterial and node.material_override.shader.resource_path=="res://scripts/forest/wind_meadow_ground.gdshader":ground.append(node)
 for row in [["caps",caps],["terrain",ground]]:
  var paths=[]
  for node:GeometryInstance3D in row[1]:paths.append(str(node.get_path()));node.visible=false
  await gameplay_capture("full-alyut-wedge-hide-"+row[0],"Read-only owner diagnostic; temporarily hidden visual geometry only: "+row[0],yaw)
  for node:GeometryInstance3D in row[1]:node.visible=true
  observations.append({"diagnostic_hidden_visual_owner":row[0],"nodes":paths,"collision_native_walk_and_source_unchanged":true})

func apply_bank_body_material():
 var image=Image.load_from_file(BODY_FOLDER+"surfaces.png");var texture=ImageTexture.create_from_image(image);var seen={};var rows=[]
 for node:MultiMeshInstance3D in game.world.map_features.find_children("NativeSourceBankCap_*","MultiMeshInstance3D",true,false):
  var mesh:Mesh=node.multimesh.mesh
  if seen.has(mesh.get_instance_id()):continue
  seen[mesh.get_instance_id()]=true
  var arrays=var_to_bytes(mesh.get_meta("source_surface_arrays_all"));var front=mesh.surface_get_material(1);var material:ShaderMaterial=mesh.surface_get_material(0).duplicate()
  material.set_shader_parameter("base_texture",texture);mesh.surface_set_material(0,material)
  check(arrays==var_to_bytes(mesh.get_meta("source_surface_arrays_all")) and front==mesh.surface_get_material(1),"Private natural bank finish preserves all exactCPUgeometry and original source-front material "+str(node.get_meta("source_graphic")))
  rows.append({"graphic":node.get_meta("source_graphic"),"instances":node.multimesh.instance_count,"mesh":mesh.get_instance_id()})
 check(not rows.is_empty(),"Only enrolled native bank meshes receive the process-private natural body material")
 underlay_audit["body_material"]={"texture_sha256":FileAccess.get_sha256(BODY_FOLDER+"surfaces.png"),"distinct_meshes":rows,"original_geometry_and_front_unchanged":true,"prior_unchanged_actual_support_report":"actual-underlay-review-07.json","scope":"Process-only replacement of inferred hidden bank-body finish using existing natural Edo rock/soil. No native grass/front, meshCPUarrays, source masks, water/support heights, nav or routes change."}

func apply_bank_underlay():
 # Review the production setup hook; this fixture does not inject its masks.
 var source_sha=String(Full.data().source.sha256);var found=[];var water_nodes=[];var seen={}
 check(not game.model.terrain.has_meta("alyut_complete_material_blocker"),"Production Alyut material ownership has no blocker: "+String(game.model.terrain.get_meta("alyut_complete_material_blocker","")))
 for valley:Node3D in game.world.map_features.find_children("WindMeadowValley","Node3D",true,false):
  for node in valley.get_children():
   if not node is MeshInstance3D:continue
   var material=node.material_override
   if not material is ShaderMaterial or material.shader.resource_path!="res://scripts/forest/wind_meadow_ground.gdshader" or seen.has(material.get_instance_id()):continue
   seen[material.get_instance_id()]=true
   check(material.get_meta("alyut_complete_material_source","")==source_sha,"Production ground material is owned by exact Alyut source")
   check(material.get_shader_parameter("use_native_land_visibility")==true,"Production hook enrolled the existing nearest visibility sampler")
   var mask:Texture2D=material.get_shader_parameter("native_land_visibility")
   var water_count=76 if not Full.source_overlap_data().is_empty() else 82
   check(mask!=null and mask.get_meta("source_bank_cut_cells",[]).size()==117 and mask.get_meta("source_water_cut_cells",[]).size()==water_count,"Production mask cuts exact117native banks and its separate2400water ring, preserving original100overlaps")
   found.append(str(node.get_path()))
 for node:MeshInstance3D in game.world.map_features.find_children("FreyjaWater","MeshInstance3D",true,false):
  var material=node.material_override
  if not material is ShaderMaterial or material.shader.resource_path!="res://assets/maps/freyja_west_gate/water.gdshader":continue
  check(material.get_meta("alyut_complete_material_source","")==source_sha,"Production water material retains the exact source owner")
  var mask:Texture2D=material.get_shader_parameter("layout_mask")
  check(mask!=null and mask.get_meta("alyut_source_water_bank_cells",[]).size()==117,"Production cloned water mask backs only117source-water banks")
  water_nodes.append(str(node.get_path()))
 check(found.size()==1 and water_nodes.size()==1,"One existing terrain material and one water material receive the production Alyut source masks")
 underlay_audit={"production_hook":true,"material_nodes":found,"water_material_nodes":water_nodes,"source_bank_cells":117,"source_water_context_cells":Full.bank_underlay_water_rows().size(),"source_water_backing_cells":117,"source100_overlap_cells":Full.source_overlap_data().get("source100_overlap_cells",[]).size(),"source_hybrid_sha256":source_sha,"prior_unchanged_actual_support_report":ALYUT_FOLDER+"actual-underlay-review-07.json","prior_unchanged_five_house_report":ALYUT_FOLDER+"actual-review-01.json","inferred":"Source-bank visual underlay closure and cloned original2mwater backing; no original source pixels, height/collision/native walk/routes change. Natural hidden bank finish belongs to the accepted canonical Caps owner."}

func walk_overlap_leg(target:Vector2)->bool:
 var original=game.model;var direction=(target-map_position()).normalized();game.camera_rig.yaw=atan2(-direction.x,-direction.y)
 Input.action_press("move_forward")
 for i in 110:
  await physics_frame
  if game.model!=original or map_position().distance_to(target)<.30:break
 Input.action_release("move_forward")
 for i in 4:await physics_frame
 return game.model==original and map_position().distance_to(target)<.65

func source_overlap_probes():
 var region=load("res://scripts/forest/forest_east_region.gd");var source=Full.source_overlap_data();check(source.source100_overlap_cells.size()==6,"Exactly six original100overlap records are enrolled")
 var flowers=game.world.map_features.find_children("*","Node3D",true,false).filter(func(node):return node.has_meta("source100_overlap_graphics"))
 check(flowers.size()==1 and flowers[0].get_meta("source100_overlap_graphics")[0].graphic==12172,"One original100flower appears through the existing native prop owner")
 for row:Dictionary in source.source100_overlap_cells:
  var cell=Vector2i(row.village_cell[0],row.village_cell[1]);var at=village_cell(cell);var start=village_cell(cell+Vector2i.DOWN) if row.field_native_open else village_cell(Vector2i(34,3))
  check(region.current_source(game.model,at)==100 and not Full.field_handoff(cell),"Original100context stays separate from gate buffers "+str(cell))
  check(clear_point(at)==bool(row.field_native_open),"Assembled native/scenery clearance matches original100cell "+str(cell))
  await position_at(start);for i in 5:await physics_frame
  var before=map_position();var reached=await walk_overlap_leg(at);var final=map_position();var returned=false
  if row.field_native_open:
   check(reached and region.current_source(game.model,final)==100,"Normal on-foot approach reaches the original100land cell "+str(cell))
   check(absf(game.player.position.y/game.model.falan_scale-6.)<.45,"Original100overlap retains its existing6mfield datum "+str(cell))
   returned=await walk_overlap_leg(start);check(returned,"Normal on-foot return preserves the original100connection "+str(cell))
  else:
   check(not reached and final.distance_to(at)>1.4,"Original12172flower blocks entry into its closed source cell")
   returned=await walk_overlap_leg(start);check(returned,"Blocked flower approach can return normally")
  overlap_audit.append({"village_cell":row.village_cell,"field_cell":row.field_cell,"source100_native_open":row.field_native_open,"graphic":row.field_pg1,"approach_start":var_to_str(before),"approach_end":var_to_str(final),"entered_target":reached,"returned_on_foot":returned,"source2400_raw_open":Full.source_open(cell)})
 await prop_views("full-alyut-source100-flower",Vector2i(33,5),Vector2i(36,5),Vector2i(35,3))

func scene_contracts():
 var complete=game.world.find_children("*","Node3D",true,false).filter(func(node):return node.has_meta("alyut_complete_owner_counts"))
 check(complete.size()==1,"One complete compatible Alyut visual owner")
 if complete.is_empty():return
 var counts:Dictionary=complete[0].get_meta("alyut_complete_owner_counts")
 check(int(counts.native_prop)==334 and int(counts.existing_tree_owner)==31,"All334 native props and31 source trees are accounted")
 check(complete[0].get_meta("alyut_recovered_bank_support_count",0)==117,"All117 original shore lips, including99 recovered, retain source support")
 var cliffs=game.world.find_children("*","Node3D",true,false).filter(func(node):return node.get_meta("east_native_cliff_source_map",0)==2400)
 check(cliffs.size()==1 and cliffs[0].get_meta("east_native_cliff_source_placements",[]).size()==204,"All204 source-confirmed Alyut cliff placements are mounted once")
 var source=Full.data();check(source.actors.size()==14 and source.connections.size()==27,"Full source actor and event/static endpoint inventory retained")
 var supports=game.world.find_children("*","StaticBody3D",true,false).filter(func(node):return node.has_meta("native_bank_cap") and node.has_meta("source_cell"))
 var expected={}
 for row:Dictionary in Full.bank_rows():expected[row.source_cell]=int(row.serial)
 var actual={}
 for node:StaticBody3D in supports:
  var cell:Vector2i=node.get_meta("source_cell");check(not actual.has(cell),"One source physical bank owner per native cell "+str(cell));actual[cell]=int(node.get_meta("native_bank_cap"))
 check(actual==expected,"Each original bank has an exact source-cell physical support owner")
 for node:CollisionObject3D in game.world.find_children("*","CollisionObject3D",true,false):
  var index=int(node.get_meta("map_terrain_index",-1))
  if index<0 or index>=game.model.terrain.pieces.size():continue
  check(not game.model.terrain.pieces[index].get("source_bank_cap",false),"Native bank support never becomes a fortress/parapet collider")

func source_bank_probes():
 for row:Dictionary in Full.bank_rows(true):
  var original_anchor:Vector2=row.anchor
  check(is_equal_approx(game.model.surface_height(original_anchor.x,original_anchor.y),6.),"Original source anchor retains6m shore height "+str(row.source_cell))
  check(game.model.terrain.disk_clear(Vector3(original_anchor.x,6.,original_anchor.y),.55),"Original source anchor remains natively walkable "+str(row.source_cell))
  await position_at(original_anchor)
  for i in 6:await physics_frame
  check(absf(game.player.position.y-6.*game.model.falan_scale)<.45*game.model.falan_scale,"Actual player retains the original source bank anchor "+str(row.source_cell))
  var at:Vector2=row.anchor+Vector2(row.deepest_stand[0],row.deepest_stand[1]);var expected=Vector3(at.x,6.,at.y)*game.model.falan_scale
  check(is_equal_approx(game.model.surface_height(at.x,at.y),6.),"Prepared source shore cap has the original6m land datum "+str(row.source_cell))
  var dry=game.model.terrain.disk_clear(Vector3(at.x,6.,at.y),.55)
  check(dry,"Native terrain accepts the drawn shore lip at source cell "+str(row.source_cell))
  await position_at(at)
  for i in 6:await physics_frame
  var retained=Tour.area(game.model)=="north_coast";var height_ok=absf(game.player.position.y-expected.y)<.45*game.model.falan_scale
  check(retained and height_ok,"Actual player remains supported on original bank cell "+str(row.source_cell))
  bank_probes.append({"source_cell":[row.source_cell.x,row.source_cell.y],"graphic":row.serial,"map_point":[at.x,at.y],"native_disk_radius_local":.55,"disk_clear":dry,"expected_world_y":expected.y,"actual_player_world_y":game.player.position.y,"height_ok":height_ok,"retained_map":retained,"world_scale":game.model.falan_scale,"source_clearance":row.outline_clearance_local})

func bank_visual_diagnostic():
 var cell=walkable_anchor(Vector2i(39,13));var at=village_cell(cell);await position_at(at)
 var facing=(village_cell(Vector2i(43,7))-at).normalized();var yaw=atan2(-facing.x,-facing.y)
 await gameplay_capture("full-alyut-bank-diagnostic-all","Unchanged-source diagnostic view; all native owners visible",yaw)
 for pattern in ["NativeSourceBankCap_*","NativeKnownLandBankSeams","ArchivedUnderseaCoastBanks"]:
  var nodes=game.world.find_children(pattern,"GeometryInstance3D",true,false);var paths=[]
  for node:GeometryInstance3D in nodes:paths.append(str(node.get_path()));node.visible=false
  await gameplay_capture("full-alyut-bank-diagnostic-hide-"+pattern.replace("*","all"),"One diagnostic capture temporarily hides only "+pattern,yaw)
  observations.append({"diagnostic_hidden_pattern":pattern,"temporarily_hidden_nodes":paths})
  for node:GeometryInstance3D in nodes:node.visible=true
