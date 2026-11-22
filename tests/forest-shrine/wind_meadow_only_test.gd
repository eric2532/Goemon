extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
var checks=0
var failures=0
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: Windmeadow verification timed out");quit(1))
	run.call_deferred()
func run():
	var maps=[]
	for name in DirAccess.get_files_at("res://assets/maps"):
		if name.ends_with(".json"):maps.append(name)
	maps.sort()
	check(maps==["forest_wind_meadow.json","forest_wind_meadow_large.json"],"Only Windmeadow layouts are bundled")
	var doc=Document.new(false)
	for method in ["load_original","load_ramparts","load_four_gates","load_kai_highway","load_blood_gulch"]:
		check(not doc.has_method(method),"Retired preset loader is absent: "+method)
	for path in [Document.WIND_MEADOW_PATH,Document.WIND_MEADOW_LARGE_PATH]:
		check(doc.read_file(path).is_empty() and doc.data.terrain_source=="wind_meadow","Windmeadow size validates: "+path)
		check(doc.play_error().is_empty(),"All four entrances reach the shrine: "+path)
	var game=load("res://scenes/forest_shrine.tscn").instantiate()
	var config_path="user://wind-meadow-only-%d.cfg"%OS.get_process_id()
	game.settings_path=config_path;root.add_child(game);current_scene=game
	for i in 4:await process_frame
	check(game.model.terrain_source=="wind_meadow" and not game.model.enemy_camps_prototype,"Normal startup uses Windmeadow even with retired launch flags")
	check_shrine(game)
	check(game.forest_ui.find_child("PreparationCamps",true,false)==null,"Tools offer no alternate prototype map")
	game.open_map_editor()
	for i in 4:await process_frame
	var editor=game.map_editor
	check(editor.active and editor.find_child("WindMeadowForestMap",true,false) is Button,"Editor keeps Windmeadow")
	for name in ["OriginalForestMap","RampartsForestMap","FourGatesForestMap","KaiHighwayForestMap","BloodGulchForestMap"]:
		check(editor.find_child(name,true,false)==null,"Retired map button is absent: "+name)
	editor.load_wind_meadow_large()
	for i in 4:await process_frame
	check(game.model.terrain_source=="wind_meadow" and game.model.terrain_scale==3.0,"Large Windmeadow remains playable")
	check_shrine(game)
	editor.load_wind_meadow()
	for i in 4:await process_frame
	check(game.model.terrain_source=="wind_meadow" and game.model.terrain_scale==2.0,"Standard Windmeadow remains playable")
	editor.close_discard();game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false
	for i in 4:await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("WIND_MEADOW_ONLY_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func check_shrine(game):
	var model=game.model
	check(model.buildings.is_empty() and model.shrine().is_empty() and model.survival_run,"The arena starts in pure survival without a castle")
	check(model.terrain_detail==model.Arena.ID and game.world.map_features.find_child("FalanSurvivalArena",true,false)!=null,"Both bundled sizes use the recovered Falan arena")
	check(game.enemy_objectives.is_empty() and not model.has_enemy_castles(),"Four spawn sides have no castle objectives")
