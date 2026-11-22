@static_unload
extends RefCounted
const CAST=780
const IMPACT=781
const SUMMON=782
const ARRIVAL=784
const AFFLICTION=790
const ROOT="res://assets/characters/crossgate/cursed_maze/spells/"
const NAMES={50:"連擊",104:"諸刃 LV5",105:"諸刃 LV6",304:"乾坤一擲 LV5",305:"乾坤一擲 LV6",505:"崩擊 LV6",850:"聖盾",1000:"攻擊魔法防禦",1104:"反擊 LV5",1105:"反擊 LV6",2702:"超強隕石魔法 LV3",2802:"超強冰凍魔法 LV3",2902:"超強火焰魔法 LV3",3002:"超強風刃魔法 LV3",2705:"超強隕石魔法 LV6",2805:"超強冰凍魔法 LV6",2905:"超強火焰魔法 LV6",3005:"超強風刃魔法 LV6",3105:"吸血魔法 LV6",4453:"超強中毒魔法",4553:"超強昏睡魔法",4653:"超強石化魔法",4753:"超強酒醉魔法",4853:"超強混亂魔法",4953:"超強遺忘魔法",5503:"攻擊反彈",5603:"魔法反彈",5703:"攻擊吸收",5803:"魔法吸收",5903:"攻擊無效",5950:"攻擊無效",6003:"魔法無效",6050:"魔法無效",6104:"補血魔法 LV5",6350:"超強補血魔法",6602:"超強恢復魔法 LV3",7300:"攻擊",7400:"防禦",8150:"吸血攻擊",8652:"超強即死",8850:"魔封攻擊",9301:"召喚"}
const STATUSES=["中毒","昏睡","石化","酒醉","混亂","遺忘"]
static var manifest:Dictionary={}
static var textures:Dictionary={}
static var sounds:Dictionary={}
static func prepare():
 if not manifest.is_empty():return
 manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
 for ref in manifest.clips:textures[ref]=load(manifest.clips[ref].runtime_path)
 for cue in manifest.sounds:sounds[cue]=load(manifest.sounds[cue].runtime_path)
static func physical(tech:int)->bool:return tech in [50,104,105,304,305,505,7300,8150]
static func visual(tech:int)->Dictionary:
 var family=tech/100
 var key=""
 if family in [27,28,29,30]:key=["h_super_earth","h_super_ice","h_super_fire","h_super_wind"][family-27]+":"+str(tech%100+1)
 elif tech==6104:key="heal:5"
 elif tech==6350:key="h_super_heal:3"
 elif tech==6602:key="h_super_recover:3"
 elif tech==3105:key="h_drain:6"
 return manifest.skills.get(key,{})
