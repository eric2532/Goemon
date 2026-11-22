extends RefCounted
## Prepared source tuning shared by the playable skill and native mirror kit.
const MELEE_REACH=3.6
const SPIN_TIME=3.0
const SPIN_INTERVAL=.25
const SPIN_DAMAGE=24.0
const SPIN_RADIUS=3.2
const MIRROR_TIME=30.0
const MIRROR_COUNT=5
const MIRROR_COOLDOWN=22.0
const WIND_TIME=8.0
const WIND_COOLDOWN=12.0
const WIND_SPEED=1.5
const IMMOLATION_DAMAGE=30.0
const IMMOLATION_RADIUS=3.5
static func profile()->Dictionary:
 var attacks=[]
 for i in 6:attacks.append({"duration":[1.2,1.167,1.167][i%3],"contact":.733 if i%3==2 else .33,"damage":90.0 if i%3==2 else 48.0,"reach":MELEE_REACH,"arc":1.42,"stop":0.0,"swingSide":1.0})
 return {"hp":150.0,"speed":7.0,"damage_multiplier":1.0,"attack_rate":1.0,"critical_chance":0.0,"primary":attacks}
static func append_native(data:Dictionary,game:Node=null):
 var row=profile()
 if game!=null:
  row.speed=game.balance_value(31,"walk_speed");row.damage_multiplier=game.balance_value(31,"damage_mult");row.attack_rate=game.balance_value(31,"attack_speed");row.critical_chance=game.balance_value(31,"critical_chance")
  for attack in row.primary:attack.reach*=game.balance_value(31,"melee_reach")
 data.blademaster_scale=game.balance_value(31,"model_scale") if game!=null else 1.0
 data.ally_kinds.append(31)
 for field in ["hp","speed","damage_multiplier","attack_rate","critical_chance"]:data.ally_profiles.append(row[field])
 for attack in row.primary:
  for field in ["duration","contact","damage","reach","arc","stop","swingSide"]:data.ally_primaries.append(attack[field])
 for sample in 161:data.walk_cadence.append(clampf(sample*.25/7.0,.4,2.0)/(.7333333))
 data.blademaster=PackedFloat64Array([SPIN_TIME,SPIN_INTERVAL,SPIN_DAMAGE,SPIN_RADIUS])
