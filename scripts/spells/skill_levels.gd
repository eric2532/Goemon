extends RefCounted
## Shared run-level rules; equipment and upgrades modify their results separately.
const MAX_LEVEL=30
const EX_TIER=4
const SIZE_STEP=.01
const SHINE_FAMILIES=["sure-strike","double-edge","combo","two-birds","counter","random-shot","qigong","moon","assassination","fire","ice","wind","meteor","recovery","blink-flurry","guard-break"]
const ELEMENTS=["fire","ice","wind","meteor"]

static func family(id:String)->String:
 var key=id.get_slice("/",1)
 if key in ["qigong","qi"]:return "qigong"
 if id=="blademaster/mirror-image":return "mirror-image"
 return key

static func shine_tier(level:int)->int:
 return EX_TIER if level>=MAX_LEVEL else mini(3,(maxi(level,1)-1)/9)

static func is_ex(ticket:Dictionary)->bool:
 return int(ticket.get("skill_level",1))>=MAX_LEVEL

static func stats(id:String,level:int)->Dictionary:
 var n=clampi(level,1,MAX_LEVEL)-1
 var l=n+1
 var growth=1.0+SIZE_STEP*n
 match family(id):
  "blink-flurry":return {"damage":1.0,"critical_bonus":5.0*l}
  "sure-strike":return {"damage":1.1+.1*n,"size":growth,"hit_area":growth}
  "double-edge":return {"damage":1.6+.2*n,"defense_penalty":.10+.01*n,"size":growth}
  "combo":return {"damage":.8+.1*floori(l/2.0),"count":3+floori(n/2.0),"size":growth,"hit_area":growth}
  "two-birds":return {"damage":1.1+.1*n,"secondary_damage":2.1+.1*n,"size":growth,"hit_area":growth}
  "bodyguard":return {"chance":minf(1.0,.5+.01*n),"defense_bonus":.01*n}
  "counter":return {"damage":1.5+.2*n,"count":1+floori(l/5.0),"size":growth,"hit_area":growth}
  "guard-break":return {"damage":1.8+.2*n,"size":growth}
  "random-shot":return {"damage":.85,"count":l+2}
  "qigong":return {"damage":1.5+.2*n,"count":1+floori(l/2.0),"critical_bonus":10.0*floori(l/10.0),"size":growth,"hit_area":growth}
  "moon":return {"damage":1.4+.15*n,"count":3+floori(l/4.0),"size":growth,"hit_area":growth}
  "assassination":return {"chance":.25+.75*n/29.0,"size":growth}
  "kagerou":return {"chance":.25+.74*n/29.0}
  "mirror-image":return {"damage":.85+.05*n,"count":3+floori(l/5.0)}
  "barrage-shadows":return {"damage":1.0+.01*n,"count":1+floori(l/5.0)}
  "recovery":return {"healing":.20+.01*n,"effect_tier":shine_tier(l)}
  "meditation":return {"healing":.05+.01*n,"effect_tier":shine_tier(l)}
 if family(id) in ELEMENTS:return {"base_damage":100.0*l,"count":1+floori(l/5.0),"effect_tier":shine_tier(l)}
 return {}
