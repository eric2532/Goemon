extends SceneTree
## Staged source-party selectors only; no runtime map, combat or visual certification.
const South=preload("res://scripts/forest/forest_south_kili_population.gd")
const ROOT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/"
var checks=0
var failures=0
var draws=0
var identities={}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("DRAGON_SOURCE_FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"Staged/encounters.json"))
 var rng=RandomNumberGenerator.new();rng.seed=20261127
 for zone in data.pools.values():
  var bags={};var seen={};var tickets=0
  for choice in zone.groups:tickets+=int(choice[1])
  for i in tickets:
   var party=South.group_from_data(zone,bags,rng,data.groups,{})
   check(not party.is_empty(),"Every source group ticket draws "+str(zone.id))
   if not party.is_empty():seen[str(party[0][3])]=int(seen.get(str(party[0][3]),0))+1
  for choice in zone.groups:check(int(seen.get(str(choice[0]),0))==int(choice[1]),"Exact whole-bag source group tickets "+str(choice[0]))
  for choice in zone.groups:
   var one:Dictionary=zone.duplicate(true);one.groups=[choice]
   for i in 128:verify_party(one,data,rng)
 for branch in data.generated_branches:
  check(not branch.runtime_registered,"Required source branch remains unregistered "+str(branch.config))
  var zone:Dictionary=branch.pool
  for i in 256:verify_party(zone,data,rng)
 var expected=["2023","2024","2025","2026","10091","10092","11051","11052","14037","14038","14039","14040","15016","15017","15018","15019"]
 check(identities.size()==expected.size()and expected.all(func(id):return identities.has(id)),"Every distinct source enemy ID exercised across fixed, scripted and generated pools")
 var f=FileAccess.open(ROOT+"source-party-contracts.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"draws":draws,"source_enemy_ids":identities.keys(),"goal_complete":false,"native_combat":false,"runtime_maps_exercised":false,"visual_verified":false},"  "));f.close()
 print("DRAGON_SOURCE_PARTIES checks=",checks," failures=",failures," draws=",draws);quit(1 if failures else 0)
func verify_party(zone:Dictionary,data:Dictionary,rng:RandomNumberGenerator):
 var party=South.group_from_data(zone,{},rng,data.groups,{})
 draws+=1;check(not party.is_empty()and party.size()<=int(zone.maximum),"Original total source cap "+str(zone.id))
 if party.is_empty():return
 var group:Dictionary=data.groups[str(party[0][3])];var counts={}
 for member in party:
  var at=group.source_members.find_custom(func(m):return str(m.enemy_id)==str(member[2]))
  check(at>=0 and int(member[0])==int(group.members[at][0]),"Source enemy and appearance index retained "+str(member[2]))
  if at<0:continue
  var levels:Array=zone.get("levels",group.members[at].slice(1,3))
  check(int(member[1])>=int(levels[0])and int(member[1])<=int(levels[1]),"Source/configured level interval "+str(member[2]))
  identities[str(member[2])]=true;counts[str(member[2])]=int(counts.get(str(member[2]),0))+1
 for member in group.source_members:
  var n=int(counts.get(str(member.enemy_id),0))
  check(n<=int(member.count[1])and(not member.mandatory or n>=int(member.count[0])),"Source mandatory/member count cap "+str(member.enemy_id))
