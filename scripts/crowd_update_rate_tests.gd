extends SceneTree
const Game=preload("res://scripts/forest/forest_game.gd")
class WorldSink extends RefCounted:
 var enemies={}
 var elapsed=[]
 func tick(delta:float,_hero:Vector3):elapsed.append(delta)
class Allies extends Node:
 var living_count=0
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
 # This observes the scheduling boundary with a tick sink; no AI behavior is
 # replaced in the live-game combat/contact tests that run alongside it.
 var game=Game.new();var allies=Allies.new();var player=Hero.new()
 game.player=player;game.explorer_helpers=allies
 for fixture in [[0,0,60],[47,0,60],[48,0,30],[127,0,30],[128,0,20],[240,0,20],[0,11,60],[0,12,30]]:
  var sink=WorldSink.new();game.model=sink;game.world_step_elapsed=0;allies.living_count=fixture[1]
  for i in fixture[0]:sink.enemies[i]={}
  var advances=0
  for step in 60:
   if game._advance_world(1.0/60):advances+=1
  var total=0.0;var maximum=0.0
  for delta in sink.elapsed:total+=delta;maximum=maxf(maximum,delta)
  check(advances==fixture[2] and sink.elapsed.size()==fixture[2],"Enemy/allied load schedules the expected world updates: "+str(fixture))
  check(absf(total-1.0)<.00001 and maximum<=.050001,"Crowd scheduling preserves elapsed attack/movement time with at most50ms steps")
 game.model=WorldSink.new();allies.living_count=0;game.world_step_elapsed=0
 for i in 128:game.model.enemies[i]={}
 game._advance_world(1.0/60);game.model.enemies.clear()
 check(game._advance_world(1.0/60) and absf(game.model.elapsed[0]-1.0/30)<.00001,"Clearing a large crowd promptly flushes accumulated world time")
 game.free();allies.free();player.free()
 print("CROWD_UPDATE_RATE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
