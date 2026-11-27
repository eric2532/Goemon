extends RefCounted
## Sparse AI overrides feed the existing wave stats and native army profiles.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROWS=[
 ["hp","Base maximum HP",1,1000000,10],
 ["damage","Base attack damage",0,100000,1],
 ["dodge_chance","Dodge chance (%)",0,100,1],
 ["speed","Movement speed",.05,200,.1]]
static func sanitized(raw:Variant,types:Array)->Dictionary:
 var result={}
 if not raw is Dictionary:return result
 for type in types:
  var values=raw.get(str(type))
  if not values is Dictionary:continue
  var profile={}
  for row in ROWS:
   var value=values.get(row[0])
   if (value is int or value is float) and is_finite(float(value)):profile[row[0]]=clampf(float(value),row[2],row[3])
  if not profile.is_empty():result[str(type)]=profile
 return result
static func base_stats(balance:Dictionary,type:int)->Dictionary:
 var stats=Roles.stats(type)
 stats.dodge_chance=5.0
 if type==Roles.BOSS:stats.hp=balance.boss_health;stats.speed=balance.boss_speed*Roles.BOSS_MOVE_SPEED
 stats.merge(balance.get("enemy_profiles",{}).get(str(type),{}),true)
 return stats
