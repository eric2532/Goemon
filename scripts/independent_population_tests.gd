extends SceneTree
const Balance=preload("res://scripts/forest/core_balance.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():
 var defaults=Balance.defaults()
 check(defaults.waves[0]==[120,120,0,120],"The first wave replaces 72 groups with 360 independent ordinary enemies")
 check(defaults.waves[2][2]==1 and defaults.bosses_per_portal==1,"Rare giants and portal bosses retain their explicit counts")
 var api=Balance.new()
 check(api.has_method("from_saved"),"Saved group counts have an explicit one-time population migration")
 if api.has_method("from_saved"):
  var legacy={"starting_gold":321,"enemy_health_mult":4.0,"waves":[[2,1,1,3],[2000,0,0,0]]}
  var migrated:Dictionary=api.from_saved(legacy)
  check(migrated.waves==[[10,5,1,15],[10000,0,0,0]],"Migration expands each ordinary group into five separately counted enemies")
  check(migrated.starting_gold==321 and migrated.enemy_health_mult==4,"Migration preserves the player's other balance choices")
  check(legacy.waves[0]==[2,1,1,3],"Migration leaves its source settings data intact")
  check(api.from_saved(migrated)==migrated,"Saving/loading the new population cannot multiply it again")
  check(api.from_saved({})==defaults,"A fresh settings file uses the new defaults once")
  var edited=Balance.sanitized({"waves":[[2,1,1,3]]})
  check(edited.waves[0]==[2,1,1,3],"New balance-editor counts mean individual enemies")
  var config_path="user://independent-population-%d.cfg"%OS.get_process_id()
  var config=ConfigFile.new();config.set_value("core_balance","values",legacy);config.save(config_path)
  var game=load("res://scripts/forest/forest_game.gd").new();game.settings_path=config_path;game.load_settings()
  check(game.core_balance.waves==migrated.waves,"The game actually migrates legacy settings on load")
  game.save_settings();game.load_settings()
  check(game.core_balance.waves==migrated.waves,"Actual settings save/reload retains individual counts")
  game.free();DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("INDEPENDENT_POPULATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
