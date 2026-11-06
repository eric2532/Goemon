extends "res://tests/forest-shrine/large_army_benchmark.gd"
class PausedGame extends Node:
 var paused=false
var pretend_focus=false
func benchmark_has_focus()->bool:return pretend_focus
func _process(_delta:float)->bool:return false
func _initialize():
 create_timer(2).timeout.connect(func():quit(1))
 options={"await-focus":true};game=PausedGame.new();root.add_child(game)
 phase="measuring";started=Time.get_ticks_usec()-100000;previous=Time.get_ticks_usec()-10000
 var original_start=started;var original_previous=previous
 _monitor_focus()
 assert(phase=="focus-wait" and game.paused and paused)
 assert(focus_hold_at==original_previous and focus_holds==1)
 _monitor_focus()
 assert(phase=="focus-wait" and focus_holds==1 and started==original_start)
 pretend_focus=true;focus_ready_at=Time.get_ticks_usec()-3100000
 _monitor_focus()
 assert(phase=="measuring" and not game.paused and not paused)
 assert(previous-started==original_previous-original_start and focus_wait_usec>0)
 var resumed_start=started
 phase="finished";_monitor_focus();assert(started==resumed_start)
 paused=false;game.free()
 print("BENCHMARK_FOCUS_HOLD_RESULT checks=6 failures=0");quit()
