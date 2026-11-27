extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-model-publication-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
 game.model.waves.pending=100000000;game.model.waves.spawn_clock=100000000;game.model.workers.clear()
 var army=game.army_runtime;army.profile_enabled=true
 var row:Dictionary=game.model.waves.spawn_enemy(0,Vector3(-60,0,60));row.boss=true
 var far:Dictionary=game.model.waves.spawn_enemy(1,Vector3(100,0,-100));army.import_arrivals();army.sync_compatibility()
 var actor=game.actors[row.id];var handle:int=actor.handle
 var gate:Dictionary=game.model.buildings.values().filter(func(b):return b.kind=="gate")[0]
 var readers={
  "world tick":func():game.model.tick(0,game.player.position),
  "minimap":func():game.forest_ui.enemy_minimap.refresh(),
  "tower candidates":func():game.model.workforce.tower_candidates(actor.position),
  "worker threat":func():check(game.model.workforce.threatened(actor.position+Vector3.RIGHT),"Worker threat reads the current native position without model copies"),
  "invalid gate repair":func():check(not game.model.close_repaired_gate(-999),"Missing gates reject repair"),
  "gate repair":func():
   gate.breached=true;gate.hp=gate.max_hp
   check(game.model.close_repaired_gate(gate.id) and not gate.breached,"A fully repaired empty gate closes after reading current enemies"),
  "portal spawn capture":func():game.model.waves.begin_spawn_query();game.model.waves.end_spawn_query(),
  "spawn clearance":func():game.model.waves.spawn_space_clear(Vector3(-60,0,60),1.3),
  "tower arrow simulation":func():
   game.model.workforce.arrows[900002]={"target":row.id,"pos":Vector3(-70,4,70),"age":0.0}
   game.model.workforce.tick_arrows(0);game.model.workforce.arrows.clear(),
  "tower arrow presentation":func():
   var node=Node3D.new();game.tower_arrows.add_child(node);game.tower_arrows.visuals[900001]=node
   game.model.workforce.arrows[900001]={"target":row.id,"pos":Vector3(-70,4,70),"age":0.0}
   game.tower_arrows.sync(0);game.tower_arrows.clear();game.model.workforce.arrows.clear()
 }
 var serial=0
 for label_ in readers:
  var old_point:Vector3=row.pos;var point=Vector3(-58+serial,0,60);serial+=1
  army.set_pose(handle,point,.375);army.set_pose(army.handles[far.id],Vector3(100+serial,0,-100),.5);army.sync_compatibility()
  check(actor.position==point and actor.combat_bounds().has_point(point+Vector3.UP),label_+": physics/contact pose stays current before any dictionary copy")
  check(row.pos==old_point,label_+": unused model row was not rewritten by physics")
  var before:int=army.model_rows_publications;var writes:int=army.model_rows_written;var far_before:Vector3=far.pos
  readers[label_].call()
  if label_ in ["world tick","minimap","worker threat","invalid gate repair"]:
   check(row.pos==old_point and army.model_rows_publications==before,label_+": packed/native readers create no model copies")
   if label_=="minimap":check(game.forest_ui.enemy_minimap.markers[0].is_equal_approx(game.forest_ui.enemy_minimap.map_position(point)),"Minimap reads current packed positions in original model order")
  else:
   check(row.pos==point and row.facing==.375 and row.hp==army.unit_state(handle).hp,label_+": reader receives exact current source fields")
   check(army.model_rows_publications==before+1,label_+": one publication covers this request")
   if label_ in ["tower candidates","tower arrow simulation","tower arrow presentation"]:
    check(far.pos==far_before and army.model_rows_written==writes+1,label_+": only the requested nearby target is copied")
  game.model.sync_enemy_records();var full_count:int=army.model_rows_publications
  check(row.pos==point and far.pos==Vector3(100+serial,0,-100),"Explicit full-model readers synchronize every live row")
  game.model.sync_enemy_records();check(army.model_rows_publications==full_count,"Repeated full readers reuse their publication")
 var before:int=army.model_rows_publications
 for i in 120:army.set_pose(handle,Vector3(-45+i*.01,0,60),.5);army.sync_compatibility()
 check(army.model_rows_publications==before and actor.position==Vector3(-45+119*.01,0,60),"120 unconsumed physics snapshots create zero model copies while poses advance")
 # Rebinding must invalidate both a full publication and sparse coverage.
 game.model.sync_enemy_records()
 var original:Dictionary=row;var held_point:Vector3=original.pos;var replacement:Dictionary=row.duplicate(true);replacement.pos=Vector3(999,999,999)
 game.model.enemies[row.id]=replacement;army.register_actor_facade(actor,replacement);game.model.sync_enemy_records(PackedInt64Array([handle]))
 check(replacement.pos==actor.position and original.pos==held_point,"Same-tick rebind publishes the new dictionary without mutating the held old row")
 var second:Dictionary=replacement.duplicate(true);second.pos=Vector3(998,998,998)
 game.model.enemies[row.id]=second;army.register_actor_facade(actor,second);game.model.sync_enemy_records(PackedInt64Array([handle]))
 check(second.pos==actor.position,"Rebinding also invalidates sparse coverage for the same generation")
 row=second
 army.apply_hit(handle,{"amount":.125,"provoke":false})
 check(row.hp==actor.hp and row.hp==army.unit_state(handle).hp,"Damage events preserve immediate model health before a deferred model publication")
 game.model.sync_enemy_records();check(row.pos==actor.position and row.hp==actor.hp,"Consumption preserves exact fractional health and latest pose")
 var retained:Dictionary=row;var old:int=handle;army.despawn(handle)
 var next:Dictionary=game.model.waves.spawn_enemy(1,Vector3(-30,0,60));army.import_arrivals();army.sync_compatibility();game.model.sync_enemy_records()
 check(army.native.sync_model_rows_for(PackedInt64Array([old,-1,0]))==0,"Stale/invalid generation handles never copy replacement records")
 check(not game.model.enemies.has(retained.id) and army.handles[next.id]!=old and next.pos==Vector3(-30,0,60),"Retirement and slot reuse cannot copy a replacement's pose into a held old row")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 print("ARMY_MODEL_PUBLICATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
