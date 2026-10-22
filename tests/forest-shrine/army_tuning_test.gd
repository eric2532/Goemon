extends SceneTree
## Current preparation tuning uses original kit contacts and visible poses.
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var script="res://scripts/forest/crowd/army_tuning.gd"
 if not ResourceLoader.exists(script):
  check(false,"Shared ally tuning must preserve current fitted reach and visible weapon scale");finish();return
 set_meta("forest_army_backend","native")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-tuning-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 var data_script=load("res://scripts/forest/crowd/army_kit_data.gd")
 var original=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")
 for kind in [11,5,7,8]:
  game.character_tuning[game.CharacterBalance.key_for(kind)]={"melee_reach":2.0}
  var data:Dictionary=data_script.from_model(game.model,1,game)
  var unit=load("res://scripts/forest/explorer_helper_unit.gd").new();unit.director=game.explorer_helpers;unit.game=game;unit.kit_id=kind;unit.slot=game.explorer_helpers.KITS.find(kind);game.add_child(unit);unit.set_physics_process(false)
  unit.position=Vector3.ZERO;unit.facing=Vector3.BACK;unit.model.rotation.y=PI;unit.show()
  var c=unit.active_ability;c.active=true;c.reset_run();var index=data.ally_kinds.find(kind)
  for sample in 6:
   c.Actions.begin_attack(c,c.Actions.primary_config(c,sample%3),sample%3)
   check(absf(data.ally_primaries[(index*6+sample)*7+3]-c.player.attack.reach)<.0001,"Kit%d primary%d preserves its original fitted custom reach"%[kind,sample])
   if kind==11:c.player.bladeSide*=-1
  check(data.pose_resources.has(kind),"Kit%d shares one custom pose atlas across all its fighters"%kind)
  if data.pose_resources.has(kind):
   var resource:Resource=data.pose_resources[kind]
   var baked:Resource=load("res://assets/characters/ally_crowd/%d.res"%kind)
   check(resource.get_meta("mesh").get_surface_count()==baked.get_meta("mesh").get_surface_count(),"Kit%d custom reach preserves original mesh surfaces"%kind)
   check(resource.get_meta("contacts").primary0[roundi(original[kind].primary[0].contact*60)].length()>baked.get_meta("contacts").primary0[roundi(original[kind].primary[0].contact*60)].length()*1.2,"Kit%d extended contact follows a visibly longer weapon"%kind)
  unit.free()
 var again:Dictionary=data_script.from_model(game.model,1,game)
 var cached:Dictionary=data_script.from_model(game.model,1,game)
 check(again.pose_resources==cached.pose_resources,"Repeated refresh reuses immutable shared tuning resources")
 game.army_runtime.refresh_kits()
 for kind in [11,5,7,8]:check(game.crowd.army.resources[kind]==cached.pose_resources[kind],"Kit%d renderer uses the exact tuned contact atlas"%kind)
 check(game.explorer_helpers.pool.all(func(u):return not u is Hero),"No source Hero controllers remain in the native ally pool")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 finish()
func finish():
 print("ARMY_TUNING_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
