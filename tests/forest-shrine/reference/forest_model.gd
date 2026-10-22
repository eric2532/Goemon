extends "res://scripts/forest/forest_model.gd"
## Historical test oracle only; the game scene never constructs this model.
var wave_step_delta=0.0
func reset(value:int,config:Dictionary={},layout:Dictionary={},include_mines:bool=true):
 cancel_wave_step()
 super.reset(value,config,layout,include_mines)
 waves=preload("res://tests/forest-shrine/reference/forest_waves.gd").new(self)
func wave_step_active()->bool:
 return waves!=null and waves.step_active
func wave_step_count()->int:
 return waves.step_ids.size() if wave_step_active() else 0
func begin_wave_step(delta:float,hero:Vector3):
 if wave_step_active() or phase!="wave" or delta<=0:return
 hero_position=hero
 if waves!=null and waves.begin_step(delta,hero):wave_step_delta=delta
func cancel_wave_step():
 wave_step_delta=0.0
 if waves!=null:
  waves.cancel_step()
  if phase!="wave":waves.projectiles.clear()
func advance_wave_slice(limit:int,hero:Vector3)->bool:
 if not wave_step_active():return true
 hero_position=hero
 var delta=wave_step_delta
 if not waves.advance_step(limit,hero):return false
 wave_step_delta=0.0
 if phase=="wave":
  workforce.tick(delta,hero)
  _tick_sight(delta,hero)
 return true


func tick(delta: float,hero: Vector3):
 # A synchronous call owns a new interval. Drain an older sliced interval
 # first using current targets, then consume the caller's full delta below.
 if wave_step_active():advance_wave_slice(wave_step_count(),hero)
 hero_position=hero
 if phase=="preparing":
  workforce.prepare_tick(delta)
  if waves!=null and waves.giant_pending:waves.navigation.refresh()
 elif phase=="wave":
  if is_instance_valid(army_runtime):waves.tick_native(delta,hero)
  else:waves.tick(delta,hero)
  if phase!="wave":return
  workforce.tick(delta,hero)
 else:return
 _tick_sight(delta,hero)

func damage_enemy(id: int,amount: float):
 if is_instance_valid(army_runtime):
  army_runtime.damage_enemy(id,amount);return
 if phase=="wave" and enemies.has(id):
  enemies[id].hp=maxf(0,enemies[id].hp-amount)
  if enemies[id].hp<=0:ryo.award_enemy_bounty(enemies[id])
