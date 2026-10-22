extends RefCounted
## Acceptance uses wall time and actual active populations, never idle allocation.
static func summary(samples:Array)->Dictionary:
 var values=samples.duplicate();values.sort()
 if values.is_empty():return {"mean_ms":INF,"p95_ms":INF,"p99_ms":INF,"max_ms":INF}
 var sum_=0.0
 for value in values:sum_+=value
 return {"mean_ms":sum_/values.size(),"p95_ms":values[mini(values.size()-1,ceili(values.size()*.95)-1)],"p99_ms":values[mini(values.size()-1,ceili(values.size()*.99)-1)],"max_ms":values.back()}
static func violations(report:Dictionary,performance:bool=true)->Array:
 var errors=[];var seconds=float(report.wall_seconds)
 for pair in [["minimum_enemies","enemies"],["minimum_allies","allies"]]:
  if report[pair[0]]!=report[pair[1]]:errors.append("Population fell below "+pair[1])
 if absf(float(report.simulation_seconds)-seconds)>maxf(.1,seconds*.001):errors.append("Simulation time differs from wall time")
 for key in ["attacks","damage_events","deaths"]:
  if report[key]<=0:errors.append("Inactive battle: no "+key)
 var coverage=0.0
 if not report.has("activity") or report.activity.is_empty():errors.append("Sustained battle activity is missing")
 for bucket in report.get("activity",[]):
  var duration=float(bucket.get("seconds",NAN))
  if not is_finite(duration) or duration<0 or duration>15:
   errors.append("Invalid activity interval");continue
  coverage+=duration
  if duration<5:continue
  for key in ["attacks","damage_events","deaths"]:
   if bucket.get(key,0)<=0:errors.append("Sustained battle became idle: no "+key)
 if not is_finite(coverage) or absf(coverage-seconds)>maxf(.1,seconds*.001):errors.append("Activity intervals do not cover the full battle")
 if seconds>=600:
  var samples=report.get("memory_samples",[]).filter(func(row):return row[0]>=seconds*.5-1)
  if samples.size()<3:errors.append("Soak lacks post-warmup resource samples")
  else:
   for pair in [[1,33554432,"memory"],[2,512,"nodes"],[3,32,"resources"]]:
    var low=INF;var high=-INF
    for row in samples:low=minf(low,row[pair[0]]);high=maxf(high,row[pair[0]])
    if high-low>pair[1]:errors.append("Soak accumulates "+pair[2])
 if report.replacements<report.deaths:errors.append("Deaths were not explicitly reinforced")
 if report.dropped_hits!=0:errors.append("Gameplay event delivery has gaps")
 if not report.foreground:errors.append("Foreground GPU rendering was not validated")
 if not report.normal_stats:errors.append("Diagnostic health/timing cannot qualify")
 if performance:
  var intervals:Array=report.frame_ms;var frame_total=0.0
  if intervals.size()!=report.frames:errors.append("Raw frame sample count differs from reported frames")
  for interval in intervals:
   if not is_finite(float(interval)) or float(interval)<0:errors.append("Invalid frame interval")
   else:frame_total+=float(interval)
  if absf(frame_total-seconds*1000)>maxf(50,seconds*5):errors.append("Raw frame intervals do not cover wall time")
  var frames=summary(report.frame_ms)
  if seconds<=0 or float(report.frames)/maxf(.001,seconds)<55:errors.append("Average FPS below55")
  if frames.p95_ms>25:errors.append("p95 frame time above25ms")
  if frames.p99_ms>50:errors.append("p99 frame time above50ms")
 return errors
