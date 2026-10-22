extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 set_meta("forest_army_backend","native");set_meta("forest_fighter",11)
 var doc=preload("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-retirement-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 for actor in game.gate_defenders.units.values():actor.set_physics_process(false)
 var army=game.army_runtime
 if army.get("retirement_rows_visited")==null:
  check(false,"Death cleanup must visit retirement events rather than the entire living army");await finish(game);return
 game.start_wave();game.model.waves.pending=100000;game.model.waves.spawn_clock=100000
 var ids=[]
 for i in 2000:ids.append(game.model.waves.spawn_enemy([0,1,3][i%3],Vector3(i%50*4,0,70+i/50*4)).id)
 army.import_arrivals();army.sync_compatibility()
 var visited:int=army.retirement_rows_visited
 for i in 10:army.sync_compatibility()
 check(army.retirement_rows_visited==visited and game.model.enemies.size()==2000,"Living 2000-unit snapshots require zero retirement scans")
 var id:int=ids[999];var victim=game.actors[id];var gold:int=game.model.gold
 army.apply_hit(army.handles[id],{"amount":100000,"source_id":-1})
 check(victim.dead and victim.collision_layer==0 and game.model.gold==gold+12,"Death removes the hitbox and pays before cleanup")
 army.sync_compatibility()
 check(army.retirement_rows_visited==visited+1 and not game.model.enemies.has(id) and not game.actors.has(id) and not army.enemies.has(id) and not game.enemies.has(victim),"One death retires exactly one model and contact facade")
 check(victim.is_queued_for_deletion(),"Retirement preserves deferred destruction for in-flight attack snapshots")
 army.sync_compatibility();check(army.retirement_rows_visited==visited+1 and game.model.gold==gold+12,"Repeated sync does not rescan or repay deaths")
 var retired:int=ids[100];army.despawn(army.handles[retired]);army.sync_compatibility()
 check(not game.model.enemies.has(retired) and not game.actors.has(retired),"Explicit despawn uses the same bounded retirement queue")
 var reuse:int=ids[101];army.apply_hit(army.handles[reuse],{"amount":100000,"source_id":-1})
 var replacement:int=army.spawn(reuse,0,0,Vector3(0,0,70),100,3.9)
 game.model.enemies[reuse]={"id":reuse,"hp":100,"variant":0,"pos":Vector3(0,0,70)}
 var fresh=army.enemy_target(reuse);game.actors[reuse]=fresh;game.enemies.append(fresh)
 army.sync_compatibility()
 check(army.valid(replacement) and game.model.enemies.has(reuse) and game.actors[reuse]==fresh and not fresh.is_queued_for_deletion(),"A recycled logical ID's live replacement survives an earlier death event")
 var waiting=game.model.waves.spawn_enemy(0,Vector3(0,0,70));waiting.hp=0
 army.import_arrivals();army.sync_compatibility()
 check(not game.model.enemies.has(waiting.id),"A pending arrival killed before import cannot leave an orphan model row")
 army.clear();check(army.pending_retirements.is_empty(),"Reset clears retirement state")
 army.sync_compatibility();check(game.model.enemies.is_empty() and game.actors.is_empty(),"Explicit runtime reset reconciles old scene rows once")
 await finish(game)
func finish(game):
 var cfg=game.settings_path
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ARMY_RETIREMENT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
