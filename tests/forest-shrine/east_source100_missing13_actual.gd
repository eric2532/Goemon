extends "res://tests/forest-shrine/east_region_review.gd"
const Candidate=preload("res://tests/forest-shrine/east_source100_missing13_candidate.gd")
const DEST=Candidate.ROOT
func run():
 phase="Source100 Missing13";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 var paths=["res://scripts/forest/forest_original_maps.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_falan_frontier.gd","res://scripts/forest/forest_east_region.gd","res://scripts/forest/crowd/army_runtime.gd","res://scripts/forest/forest_east_native_trees.gd","res://scripts/forest/forest_east_nature.gd","res://assets/maps/falan/east_region/native_trees/data.json","res://assets/maps/falan/east_region/nature/data.json",DEST+"source.json",DEST+"diagnosis.json","res://tests/forest-shrine/east_source100_missing13_candidate.gd"];var hashes={}
 for path in paths:hashes[path]=FileAccess.get_sha256(path)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east13-stage-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false);await open_area("east_gate")
 var before=var_to_bytes(game.army_runtime.navigation_data(game.model,true));var links=var_to_bytes(game.model.get_meta("falan_links",[]));var obstacles=var_to_bytes(game.model.scenery_obstacles);var added=Candidate.build(game.world.map_features,game.model)
 check(added.get_meta("source_placements").size()==13,"Thirteen confirmed source drawings are staged at their exact anchors")
 check(before==var_to_bytes(game.army_runtime.navigation_data(game.model,true)),"Visual staging preserves every Native navigation value")
 check(links==var_to_bytes(game.model.get_meta("falan_links",[])),"Original routes and protected gate cells are unchanged")
 check(obstacles==var_to_bytes(game.model.scenery_obstacles),"No player/army scenery obstacle is added or removed")
 check(added.find_children("*","CollisionObject3D",true,false).is_empty(),"The private source drawings create no collision owner")
 var detailed=[];var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEST+"source.json"))
 for record:Dictionary in source.records:
  var at:Vector2=Tour.Regions.frame("east_gate").inverse()*(Vector2(record.cell[0],record.cell[1])*3.);var center:float=game.model.terrain._covered_height(at.x,at.y);var samples=[]
  for axis:Vector2 in game.model.terrain.DISK_AXES:
   var point=at+axis*1.25;var height_:float=game.model.terrain._covered_height(point.x,point.y)
   samples.append({"axis":var_to_str(axis),"height":"uncovered"if is_nan(height_)else var_to_str(height_),"reject":is_nan(height_)or not is_nan(center)and absf(height_-center)>.15+1.25*.35})
  detailed.append({"cell":record.cell,"graphic":record.native_graphic,"center_height":"uncovered"if is_nan(center)else var_to_str(center),"samples":samples})
 for stand:Array in [[636,164],[642,164]]:
  var at:Vector2=Tour.Regions.frame("east_gate").inverse()*(Vector2(stand[0],stand[1])*3.);await position_at(at);var target=Tour.Regions.frame("east_gate").inverse()*(Vector2(639,160)*3.);var facing=(target-at).normalized()
  await gameplay_capture("fairy-grove-private13-"+str(stand[0]),"PRIVATE source scenery only at exact anchors; default.32camera. Routes, Native arrays and physical obstacles unchanged; not full-region visual acceptance.",atan2(-facing.x,-facing.y))
 var changed=[]
 for path in hashes:
  if FileAccess.get_sha256(path)!=hashes[path]:changed.append(path)
 check(changed.is_empty(),"Source inputs stayed unchanged during the private staging review")
 var f=FileAccess.open(DEST+"private-stage-review.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"source_changed":changed,"source_hashes":hashes,"placements":added.get_meta("source_placements"),"disk_samples":detailed,"scope":"PRIVATE exact-anchor source scenery; Native navigation, source walk/closed data, links and obstacle arrays unchanged. Not live and not a whole-region or complete source100 acceptance."},"  "));f.close();print("EAST13_PRIVATE_STAGE checks=",checks," failures=",errors);await finish()
