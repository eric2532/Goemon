extends SceneTree
## The same current purchase/relocation contract runs against both backends.
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 for backend in ["legacy","native"]:
  set_meta("forest_army_backend",backend)
  var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
  var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-hiring-%d.cfg"%OS.get_process_id();root.add_child(game)
  for i in 3:await process_frame
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  var h=game.explorer_helpers;h.set_process(false);game.model.starting_food=1000;game.model.gold=10000
  for slot in 5:
   var point=Vector3.INF
   for z in range(5,18):
    for x in range(-12,13):
     var candidate:Vector3=game.model.point(Vector2i(x,z))
     if h.placement_error(slot,candidate).is_empty():point=candidate;break
    if point.is_finite():break
   check(point.is_finite(),backend+" exposes legal paid guard ground")
   if not point.is_finite():continue
   var gold:int=game.model.gold;var used:int=game.model.food_used()
   check(h.begin_placement(slot) and game.model.gold==gold,backend+" preview spends no money")
   check(h.purchase(slot,point) and h.active_units(slot).size()==1,backend+" buys exactly one kit%d"%slot)
   check(game.model.gold==gold-h.COSTS[slot] and game.model.food_used()==used+2,backend+" preserves price and two-food accounting")
   var unit=h.active_units(slot)[0]
   check(unit.hp==h.HEALTH[slot] and unit.guard_post==h.stand_point(point),backend+" retains kit health and assigned post")
   var money:int=game.model.gold;game.settings_open=true
   check(not h.begin_placement(slot) and not h.purchase(slot,point+Vector3(4,0,0)) and game.model.gold==money,backend+" settings blocks paid placement")
   game.settings_open=false
  var before:int=game.model.food_used();h.clear()
  check(h.active_units().is_empty() and game.model.food_used()==before-10,backend+" clear releases all five fighters' food exactly once")
  game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
  for i in 3:await process_frame
 print("ARMY_HIRING_PARITY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
