extends "res://scripts/forest/explorer_helpers.gd"
## Exercise the real batch rollback after two recruits succeed.
var attempts=0
var spares:Array=[]
func active_units(_slot:int=-1)->Array:return pool.filter(func(unit):return unit.live)
func request(_slot:int,_reward:bool=false)->bool:
	attempts+=1
	if attempts==3:return false
	pool.append(spares.pop_back());summon_serial+=1;return true
func sync_targets():pass
