extends SceneTree
## Gates no longer grant free fighters; purchased mercenaries own ally targets.
var game
var checks=0
var failures=0
var cfg="user://gate-defenders-removed-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(60).timeout.connect(func():printerr("FAIL: gate removal timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func frames():
 for i in 3:await process_frame
func check_no_gate_squad():
 check(game.get("gate_defenders")==null and not game.has_method("show_gate_defenders"),"The scene has no gate squad controller or selection action")
 check(game.forest_ui.find_child("PreparationDefenders",true,false)==null and game.forest_ui.find_child("GateDefenderPanel",true,false)==null,"Preparation has no gate defender button or panel")
 check(game.find_children("DefenderName","Label3D",true,false).is_empty(),"No free gate fighter is instantiated")
 check(not game.army_runtime.external_targets().kinds.has(3),"Native targets contain no external gate fighters")
func run():
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 await frames();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 var gate_count=doc.data.buildings.filter(func(b):return b.kind=="gate").size()
 check(gate_count>0 and game.model.buildings.values().filter(func(b):return b.kind=="gate").size()==gate_count,"The map keeps all of its gates")
 check_no_gate_squad()
 check(game.model.defenders.is_empty() and game.explorer_helpers.active_units().is_empty(),"Preparation starts without free fighters")
 game.model.gold=2000
 check(not game.model.build("barracks",Vector2i(12,10),0).is_empty(),"Barracks still provides recruitment capacity")
 var helpers=game.explorer_helpers;var point=Vector3.INF
 for z in range(4,18):
  for x in range(-12,13):
   var candidate=game.model.point(Vector2i(x,z))
   if helpers.placement_error(1,candidate).is_empty():point=candidate;break
  if point.is_finite():break
 var gold=game.model.gold
 check(point.is_finite() and helpers.purchase(1,point),"A mercenary can still be purchased on clear ground")
 if helpers.active_units().is_empty():await finish();return
 var unit=helpers.active_units()[0]
 check(game.model.gold==gold-helpers.COSTS[1] and game.model.defenders.has(unit.gate_id),"Purchase charges once and registers the paid ally target")
 game.start_wave();game.model.waves.pending=100000;game.model.waves.spawn_clock=100000
 check_no_gate_squad()
 check(game.model.defenders.size()==1 and game.model.defenders.has(unit.gate_id),"Wave start retains only the purchased mercenary")
 game.model.phase="preparing";game.set_phase_view()
 check_no_gate_squad()
 check(helpers.active_units().size()==1 and game.model.defenders.size()==1,"Next preparation retains the survivor without free gate reinforcements")
 game.preview_forest_map(doc.data,false)
 check_no_gate_squad()
 check(game.model.defenders.is_empty() and helpers.active_units().is_empty(),"Reloading a map creates no gate fighters")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GATE_DEFENDERS_REMOVED_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
