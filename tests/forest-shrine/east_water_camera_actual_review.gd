extends "res://tests/forest-shrine/east_landmark_review.gd"
## Same source-valid stand/rig; only a fixture-owned query object's exclusions differ.
const WATER_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Water Camera Actual Final/"
func review_path()->String:return WATER_OUT
func run():
 var inputs=Sources.snapshot([get_script().resource_path,"scripts/camera.gd","scripts/forest/forest_original_maps.gd","scripts/forest/forest_original_water_camera.gd","assets/maps/original_crossgate/east/catalog.json"])
 var maps_script:Script=Maps;var loaded_maps_sha=maps_script.get_source_code().sha256_text()
 check(loaded_maps_sha==inputs["scripts/forest/forest_original_maps.gd"],"Loaded Maps script matches the source file at fixture start")
 root.size=Vector2i(1440,900);root.title="Cross Gate · Source Water Camera Proof"
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-water-camera-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for frame in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false
 game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WATER_OUT))
 var cell=Vector2i(15,140);var at=Maps.point(33200,cell)
 Tour.travel(game,Tour.Indoor.layout(33200),{"arrival":at,"yaw":PI,"velocity":Vector3.ZERO})
 for frame in 30:await physics_frame
 await position_at(at)
 var state:Dictionary=Maps.state(33200);var n=state.size.x*state.size.y
 check(Maps.open(state.bits,state.size,cell) and game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55),"Exact source land stand15,140 supports the ordinary player")
 for step in [2,3,4]:
  var behind=cell+Vector2i.UP*step;var index=behind.y*state.size.x+behind.x;var floor_=state.raw.decode_u16(20+index*2)
  check(not Maps.open(state.bits,state.size,behind) and floor_>=5000 and floor_<=5008 and state.raw.decode_u16(20+(n+index)*2)==0,"Camera backs over confirmed object-free source water "+str(behind))
 var features:Node3D=game.world.map_features;var rids:Array=features.get_meta(Maps.WaterCamera.ROOT_RIDS,[]);var original_helper=game.camera_rig.water_camera
 check(rids.size()==430,"Actual root retains430eligible original water boundary RIDs")
 var unfiltered=Maps.WaterCamera.new();unfiltered.sync(features);unfiltered.lateral.exclude=[];unfiltered.probe.exclude=[]
 game.camera_rig.yaw=PI;game.camera_rig.pitch=.32;game.camera_rig.water_camera=unfiltered;game.camera_rig.reset_follow()
 for frame in 90:await physics_frame;game.camera_rig.update_camera(1./60.)
 var before=game.camera_rig.current_distance;var desired=game.camera_rig.unobstructed_distance;var fov=game.camera_rig.camera.fov
 var ordinary=PhysicsRayQueryParameters3D.create(unfiltered.probe.from,unfiltered.probe.to,1)
 var raw_hit=game.world.get_world_3d().direct_space_state.intersect_ray(ordinary)
 check(not raw_hit.is_empty() and raw_hit.collider.get_meta(Maps.WaterCamera.WATER_BOUNDARY,false),"Unmodified layer1ray hits exactly the invisible water-only navigation boundary")
 check(before<desired*.70,"Without water exclusion the same default.32rig contracts at that water boundary")
 await capture("water-boundary-unfiltered",33200,cell,"Fixture-owned old query without water exclusions; same default.32camera and original player stand")
 game.camera_rig.water_camera=original_helper;game.camera_rig.reset_follow()
 for frame in 90:await physics_frame;game.camera_rig.update_camera(1./60.)
 check(game.camera_rig.current_distance>=desired*.98,"Integrated water-only exclusion restores the unobstructed ordinary distance at the same stand")
 check(game.camera_rig.pitch==.32 and is_equal_approx(game.camera_rig.camera.fov,fov) and is_equal_approx(game.camera_rig.unobstructed_distance,desired),"Pitch/FOV/requested distance are unchanged between the comparisons")
 check(game.model.falan_floor==33200 and game.world.map_features==features and features.get_meta(Maps.WaterCamera.ROOT_RIDS)==rids,"The map, source boundary bodies and exclusion metadata remain unchanged")
 await capture("water-boundary-filtered",33200,cell,"Active integrated water-only query; same default.32camera and original player stand")
 var house_from=Maps.point(33200,Vector2i(104,148));var house_to=Maps.point(33200,Vector2i(116,136))
 var visible=PhysicsRayQueryParameters3D.create(game.model.world_point(house_from,2.),game.model.world_point(house_to,2.),1);visible.exclude=original_helper.probe.exclude
 var wall=game.world.get_world_3d().direct_space_state.intersect_ray(visible)
 check(not wall.is_empty() and not wall.collider.get_meta(Maps.WaterCamera.WATER_BOUNDARY,false) and not wall.collider.get_meta("original_map_ground",false),"The same integrated query still stops at the visible living-house navigation proxy")
 check(Sources.changed(inputs).is_empty(),"Loaded water proof sources remain current")
 var report={"checks":checks,"failures":errors,"observations":observations,"captures":captures,"source_hashes":inputs,"source_changed_during_run":Sources.changed(inputs),"maps_loaded_sha256":loaded_maps_sha,"maps_disk_end_sha256":FileAccess.get_sha256("res://scripts/forest/forest_original_maps.gd"),"maps_disk_end_mtime":FileAccess.get_modified_time("res://scripts/forest/forest_original_maps.gd"),"source_cell":[15,140],"pitch":.32,"desired_distance":desired,"without_water_exclusions":before,"with_water_exclusions":game.camera_rig.current_distance,"water_boundary_hit":{} if raw_hit.is_empty() else {"node":str(raw_hit.collider.get_path()),"position":var_to_str(raw_hit.position)},"visible_house_hit":{} if wall.is_empty() else {"node":str(wall.collider.get_path()),"position":var_to_str(wall.position)},"scope":"Actual camera-only comparison at one source-confirmed eligible water edge; no collision, map, FOV or pitch change. Not art/performance/full-walkthrough acceptance."}
 var file=FileAccess.open(WATER_OUT+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EAST_WATER_ACTUAL_RESULT checks=",checks," failures=",errors," before=",before," after=",game.camera_rig.current_distance," desired=",desired)
 await finish()
