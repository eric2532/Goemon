extends "res://tests/forest-shrine/east_nature_actual_review.gd"
## Three replacement native-axis diagnostics; no repeat of unchanged gameplay views.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Indoor Native Axis/"
func run():
 var hashes=Sources.snapshot(review_source_paths());root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-native-axis-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for frame in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_path()))
 for site:Array in sites().slice(5,8):
  var id=Maps.runtime_id(int(site[0]));camera_component_map=-1;camera_component.clear();var initial=walk_cell(id,site[4]);use_camera_component(id,initial)
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,initial),"yaw":0.,"velocity":Vector3.ZERO})
  for frame in 20:await process_frame
  check(game.model.falan_floor==id,"Native-axis diagnostic retains original room "+str(site[0]))
  var live=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))==int(site[1]) and node.multimesh.mesh.has_meta("east_nature_kind"):live+=node.multimesh.instance_count
  check(live>0,"Diagnostic uses actual Nature mesh, not prior fallback "+str(site[1]))
  var roof=game.world.map_features.find_child("SolidCaveCeiling",true,false) as Node3D
  check(roof!=null,"Original indoor roof exists before diagnostic")
  await capture_native_axis(site,initial)
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Native-axis diagnostic sources remain current")
 var file=FileAccess.open(review_path()+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors,"captures":captures,"observations":observations,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Only three indoor native-axis diagnostic captures with synthetic ceiling temporarily hidden and restored. Existing normal/second gameplay views remain in160/4historical actual report; no new gameplay-camera acceptance or production camera change."},"  "));file.close();print("EAST_NATIVE_AXIS_DIAGNOSTIC checks=",checks," failures=",errors);await finish()
