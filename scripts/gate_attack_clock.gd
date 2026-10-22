extends RefCounted
## Gate cadence is independent of player hits and the shrine's slower clock.
const INTERVAL=1.25
var remaining=INTERVAL
var strike_left=0.0
func reset() -> void:remaining=INTERVAL;strike_left=0.0
func advance(delta: float,eligible: bool,paused: bool=false) -> bool:
 if paused:return false
 if not eligible:reset();return false
 var dt=maxf(0,delta);strike_left=maxf(0,strike_left-dt);remaining-=dt
 if remaining>.000001:return false
 remaining=INTERVAL;strike_left=.3;return true
func pose() -> StringName:
 if strike_left>0:return &"strike"
 if remaining<=.65:return &"windup"
 if remaining>.8 and remaining<INTERVAL:return &"recover"
 return &"chase"
