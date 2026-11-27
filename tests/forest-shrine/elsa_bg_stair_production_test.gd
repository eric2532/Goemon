extends "res://tests/forest-shrine/elsa_second_stair_support_test.gd"
## The shared movement checks run with normal resources and no scene injections.
var first_stair_mesh:Mesh

func _initialize():
 capture_output=OUTPUT+"second-stair-production/";stair_node_name="ElsaOriginalBGStair"
 create_timer(900).timeout.connect(func():printerr("ELSA_BG_STAIR_PRODUCTION_TIMEOUT");quit(1))
 run.call_deferred()

func setup_review_game():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-elsa-stair-production.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.save_left=600.
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_output))
 second_spec=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/scenery/temple-bg-stair/mesh.json"))
 check(not second_spec.candidate_only,"Movement loads the installed source stair asset")

func prepare_review_point(_point:Dictionary):
 var node=game.world.find_child(stair_node_name,true,false)
 check(node!=null and node.is_visible_in_tree(),"Normal scenery builder constructs the source BG stair")
 check(game.world.find_children("ElsaPrivate*","MeshInstance3D",true,false).is_empty(),"Production proof contains no injected private geometry")
 check(not Steps.data(59530).candidate_only,"Normal model/native/physics owner loads installed support")
 var floor=Floor.data(59530)
 check(not floor.candidate_only and floor.regions.keys().size()==2,"Canonical floor contains only published pedestal/stair regions")
 if node!=null:first_stair_mesh=node.mesh

func verify_return_scene():
 if game.model.falan_floor!=59530:return
 var node=game.world.find_child(stair_node_name,true,false)
 check(node!=null and node.is_visible_in_tree(),"Normal return rebuilds the source stair without a fixture injection")
 if node!=null:check(node.mesh==first_stair_mesh,"Temple re-entry reuses its immutable prepared mesh")
