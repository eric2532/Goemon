extends SceneTree
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var report={"enemies":2000,"allies":2000,"minimum_enemies":2000,"minimum_allies":2000,"wall_seconds":60.0,"simulation_seconds":60.0,"frames":3600,"attacks":4000,"damage_events":6000,"deaths":1000,"replacements":1000,"foreground":true,"normal_stats":true,"frame_ms":[],"dropped_hits":0,"activity":[]}
 report.frame_ms.resize(3600);report.frame_ms.fill(1000.0/60)
 for i in 6:report.activity.append({"seconds":10.0,"attacks":100,"damage_events":150,"deaths":20})
 check(Metrics.violations(report).is_empty(),"Complete60second normal-stat active trace can pass")
 for activity in [[],report.activity.slice(0,2),[{"seconds":60.0,"attacks":600,"damage_events":900,"deaths":120}]]:
  var bad=report.duplicate(true);bad.activity=activity;check(not Metrics.violations(bad).is_empty(),"Missing, truncated and one-shot activity cannot prove sustained battle")
 var missing=report.duplicate(true);missing.erase("activity");check(not Metrics.violations(missing).is_empty(),"Absent activity evidence cannot qualify")
 for seconds in [-1.0,NAN,INF,15.001]:
  var bad=report.duplicate(true);bad.activity[0].seconds=seconds;check(not Metrics.violations(bad).is_empty(),"Malformed or overlong activity intervals are rejected")
 var bad=report.duplicate(true);bad.frame_ms=bad.frame_ms.slice(0,30);check(not Metrics.violations(bad).is_empty(),"A high frame count cannot stand in for missing raw frame samples")
 bad=report.duplicate(true);bad.frame_ms.fill(1.0);check(not Metrics.violations(bad).is_empty(),"Raw frame intervals must cover measured wall duration")
 for value in [-1.0,NAN,INF]:
  bad=report.duplicate(true);bad.frame_ms[0]=value;check(not Metrics.violations(bad).is_empty(),"Invalid frame durations cannot qualify")
 print("ARMY_BENCHMARK_COVERAGE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
