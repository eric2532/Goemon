extends SceneTree
# Gate squads must share the army's native combat broadphase and cosmetic pose
# budget, while explicit gameplay pose samples and original kits stay intact.
class CountedRaider extends "res://scripts/forest/forest_raider.gd":
 var bounds_calls=0
 func combat_bounds()->AABB:
  bounds_calls+=1;return super.combat_bounds()
class PoseCounter extends Node3D:
 var samples=0
 func animate_pose(_pose,_delta,_time,_movement):samples+=1
var game
var checks=0
var failures=0
var cfg="user://gate-shared-combat-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false)
 for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
 var gate=load("res://scripts/forest/forest_gate_defender.gd").new();gate.game=game;game.add_child(gate);gate.set_physics_process(false)
 check(gate.character_models.keys()==[1] and gate.character_abilities.is_empty(),"Gate startup builds only its required Goemon bootstrap model")
 gate.select_character(10)
 check(gate.character_models.size()==2 and gate.character_abilities.size()==1,"Preparation selection lazily builds only the requested Ranger kit")
 check(gate.get("director")==game.explorer_helpers,"Gate defenders use the existing shared army director")
 check(gate.character_models[1].get_script()==game.player.character_models[1].get_script(),"Goemon keeps its original character model")
 var combat=gate.active_ability
 check(combat.fx.army_trails,"AI gate Ranger opts into shared immutable arrow trails")
 var actors=[]
 for i in 240:
  var point=Vector3(20+(i%24)*3,0,40+floori(i/24.0)*3)
  var e=game.model.waves.spawn_enemy(0,point);e.hp=10000;e.max_hp=10000
  var a=CountedRaider.new();a.game=game;a.forest_id=e.id;a.variant=0;a.swarm=true;a.position=point
  game.add_child(a);a.set_physics_process(false);a._sync_fitted_pose();game.actors[e.id]=a;game.enemies.append(a);actors.append(a)
  game.model.visible_cells[game.model.cell_of(point)]=true
 for actor in actors:actor.bounds_calls=0
 var target_count=0
 for i in 12:
  combat._begin_projectile_queries();target_count=combat._projectile_targets.size();combat._end_projectile_queries()
 var calls=0
 for actor in actors:calls+=actor.bounds_calls
 print("GATE_SHARED_PROJECTILE_BOUND_CALLS ",calls)
 check(target_count>=240,"Shared gate Ranger snapshots still include all 240 real visible foes")
 check(calls<=240,"Twelve gate Ranger preparations fit each raider at most once instead of 2,880 times")
 var visual=PoseCounter.new();game.add_child(visual);var previous=combat.visual_actor;combat.visual_actor=visual
 if combat.get("visual_left")!=null:combat.visual_left=0;combat.visual_elapsed=0;combat.visual_frame=-1
 combat._animate(1,0);combat._animate(1,0)
 check(visual.samples==1,"Gate cosmetic pose samples at most once between rendered frames")
 combat._animate(0,0);combat._animate(0,0)
 check(visual.samples==3,"Explicit zero-time gate gameplay pose requests always sample immediately")
 combat.visual_actor=previous;visual.queue_free()
 gate.select_character(1);check(gate.character_id==1 and gate.active_ability==null,"Gate selection can return to native Goemon")
 gate.select_character(2);check(gate.character_id==2 and gate.active_ability==gate.character_abilities[2],"Gate selection can return to native Edo")
 check(gate.character_abilities[2].get_script()==game.player.character_abilities[2].get_script(),"Selecting Edo lazily builds its original native combat implementation")
 check(gate.character_models.size()==3 and gate.character_abilities.size()==2,"Switching kits retains only explicitly selected roster models and abilities")
 gate.select_character(10)
 check(gate.active_ability==combat,"Reselecting Ranger preserves its original cooldown and combat state owner")
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GATE_DEFENDER_SHARED_COMBAT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
