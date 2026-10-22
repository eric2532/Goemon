extends RefCounted
## Deliberately retain the original allocation and script-sampling paths as an oracle.
class Terrain extends "res://scripts/forest/forest_blood_gulch_terrain.gd":
 func cliff_cell(cell:Vector2i)->bool:
  if cliff_cache.has(cell):return bool(cliff_cache[cell])
  var result=_sample_cliff_cell(cell)
  if cliff_cache.size()>=8192:cliff_cache.clear()
  cliff_cache[cell]=result;return result
class Waves extends "res://scripts/forest/forest_waves.gd":
 func role_stats(variant:int)->Dictionary:
  return _simulation_stats(variant)
 func _simulation_stats(variant:int)->Dictionary:
  var stats=Roles.stats(variant)
  if variant==Roles.BOSS:stats.hp=m.balance.boss_health;stats.speed=m.balance.boss_speed
  stats.speed*=m.balance.enemy_speed_mult;stats.hp*=m.balance.enemy_health_mult;stats.damage*=m.balance.enemy_damage_mult
  return stats
class Corridors extends "res://scripts/forest/forest_terrain_corridors.gd":
 func _refresh(model):
  super._refresh(model)
  native_sampler=null
static func install(model):
 if model.terrain_source=="blood_gulch":
  var original=Terrain.new();original.horizontal_scale=float(model.terrain.get("horizontal_scale"));original.configure(model.ramparts);model.terrain=original
 model.waves=Waves.new(model)
 model.waves.navigation.terrain_corridors=Corridors.new(model,model.waves.navigation)
