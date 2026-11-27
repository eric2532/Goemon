extends "res://tests/forest-shrine/east_il_water_walk_actual_review.gd"
## Camera-only follow-up; retain the separate clean2512/0 movement report.
func run():
 phase="IlWaterWalkCameraOnly";review_area="il_village";root.size=Vector2i(1440,900)
 var technical:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE+"actual-review-clean-03.json"))
 var paths=technical.source_hashes.keys();paths.append(get_script().resource_path);paths.append(CANDIDATE+"actual-review-clean-03.json")
 paths.append_array(["scripts/forest/forest_east_village_buildings.gd","scripts/forest/forest_il_chief.gd","assets/maps/falan/east_region/village_buildings/data.json"])
 var before=Fresh.snapshot(paths);check(technical.checks==2512 and technical.failures==0 and technical.source_changed_during_run.is_empty(),"Camera follow-up references the clean2512/0 movement proof")
 candidate_data=JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE+"data.json"));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-il-water-camera-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game;game.settings.forest_pet_loadout=[]
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate");await site(2000,"il_village");await prepare_private_world()
 for ramp:Dictionary in candidate_data.ramps:
  if ramp.source_bank_cell==[57.,76.]:continue
  await clear_second_view(ramp)
 var changed=Fresh.changed(before);check(changed.is_empty(),"Camera-only loaded sources remained current")
 var file=FileAccess.open(CANDIDATE+"camera-only-review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors,"source_hashes":before,"source_changed":changed,"observations":observations,"captures":captures,"scope":"Two replacement ordinary second-angle views from original-open/native-reachable bank lips or water controls; no geometry/support/source changes and no rerun of2512movement assertions. Whole393shore and143directcontact parity remain separate."},"  "));file.close();print("IL_WATER_CAMERA_ONLY checks=",checks," failures=",errors," captures=",captures.size());await finish()

func clear_second_view(ramp:Dictionary):
 var bank=Vector2i(ramp.source_bank_cell[0],ramp.source_bank_cell[1]);var last:Array=ramp.source_run_cells[-1];var original=Vector2i(last[0],last[1]);var target_local=Vector2(ramp.a[0],ramp.a[1]);var frame=Tour.Regions.village_transform("il_village");var at=frame*target_local
 var target=game.model.world_point(at,.3);var roofs=[];var village=game.world.find_child("Connected_il_village",true,false)
 var buildings=load("res://scripts/forest/forest_east_village_buildings.gd");var chief=load("res://scripts/forest/forest_il_chief.gd")
 # Static batching removes individual mesh nodes; reconstruct the same visual
 # bounds from the existing placement plan and unchanged approved masters.
 for row:Array in game.model.get_meta("joined_village").falan_frontier_plan:
  if row[0]!="il_laruka_building":continue
  var serial=int(row[3]);var mesh:Mesh=buildings.prepare(serial) if buildings.owns(serial) else chief.prepare() if serial==11268 else null
  if mesh==null:continue
  var pose=Transform3D(Basis.from_scale(Vector3(1,buildings.Fit.VILLAGE_HEIGHT,1)),row[1].origin)
  roofs.append((village.global_transform*pose)*mesh.get_aabb())
 var choices=[];var shore_rows:Dictionary=WholeShore.data(SHORE_DATA)
 for shift in [Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-2),Vector2i(0,2)]:
  var cell=bank+shift
  for row:Dictionary in shore_rows.rows:
   if Vector2i(row.source_cell[0],row.source_cell[1])!=cell or not row.source_attribute_open:continue
   var g:Dictionary=BankCaps.data().graphics[str(int(row.serial))];var deep=Vector2(g.deepest_stand[0],g.deepest_stand[1])
   choices.append({"cell":cell,"point":village_cell(cell)+frame.basis_xform(deep),"kind":"observed native grass lip"})
 var water=Vector2i(ramp.source_water_cell[0],ramp.source_water_cell[1])
 for shift in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2)]:
  var cell=water+shift
  if candidate_data.water_rows.any(func(w):return Vector2i(w.source_cell[0],w.source_cell[1])==cell):choices.append({"cell":cell,"point":village_cell(cell),"kind":"original252water floor"})
 var found=false;var attempts=[]
 for choice:Dictionary in choices:
  var stand:Vector2i=choice.cell
  if not IlSource.source_open(stand):continue
  var point:Vector2=choice.point;var world=game.model.world_point(point)
  if not game.army_runtime.native.ally_ground_clear(world,.6):continue
  if not allied_probe.can_reach(game.model.world_point(village_cell(original)),world,.35):continue
  await position_at(point);var direction=(at-point).normalized();var yaw=atan2(-direction.x,-direction.y)
  game.camera_rig.yaw=yaw;game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
  for i in 20:await physics_frame;game.camera_rig.update_camera(1./60.)
  var camera:Camera3D=game.camera_rig.camera;var distance_ok=game.camera_rig.current_distance>game.camera_rig.unobstructed_distance*.8
  var house_clear=not roofs.any(func(box:AABB):return box.grow(.15).intersects_segment(camera.global_position,target))
  var ray=PhysicsRayQueryParameters3D.create(camera.global_position,target,1);ray.exclude=game.camera_rig.water_camera.probe.exclude;var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
  var clear=house_clear and (hit.is_empty() or hit.position.distance_to(target)<.75);var framed=camera.is_position_in_frustum(target)
  attempts.append({"stand":str(stand),"stand_kind":choice.kind,"distance_ok":distance_ok,"house_clear":house_clear,"visual_house_bounds":roofs.size(),"ray_clear":clear,"framed":framed})
  if not clear or not framed or not distance_ok:continue
  check(game.player.is_on_floor(),"Replacement ordinary camera stands on actual source support")
  observations.append({"bank":str(bank),"stand":str(stand),"stand_kind":choice.kind,"physical_foot":str(game.player.position),"original_connected_stand":str(original),"target":str(target),"ordinary_pitch":.32,"native_route_from_original_stand":true,"camera_distance":game.camera_rig.current_distance,"desired_distance":game.camera_rig.unobstructed_distance,"house_clear":house_clear,"attempts":attempts})
  await gameplay_capture("il252-entry-%s-%s-clear-second"%[bank.x,bank.y],"Ordinary second angle from original-open/native-reachable source support; roof-bounding/ray/frustum/distance checks retained",yaw);found=true;break
 check(found,"Found an unobscured ordinary second view for entry "+str(bank))
 if not found:observations.append({"bank":str(bank),"failed_camera_attempts":attempts})
