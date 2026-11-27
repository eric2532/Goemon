extends SceneTree
## Staged source-party selectors only; no runtime map, combat or visual certification.
const Events=preload("res://scripts/forest/forest_east_events.gd")
var event_report=[]
const South=preload("res://scripts/forest/forest_south_kili_population.gd")
const ROOT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Altar Approaches/"
var checks=0
var failures=0
var draws=0
var identities={}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("ALTAR_SOURCE_FAIL ",label)
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
 var expected=["16011","16012","16013","16014","16015","16016","16017","16018"]
 check(identities.size()==expected.size()and expected.all(func(id):return identities.has(id)),"Every distinct source enemy ID exercised across the three original generated pools")
 event_choices()
 var f=FileAccess.open(ROOT+"source-party-contracts.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"draws":draws,"source_enemy_ids":identities.keys(),"goal_complete":false,"native_combat":false,"runtime_maps_exercised":false,"visual_verified":false,"event_choices":event_report,"original_follow_on_verified":false,"all171_generated_layouts_verified":false},"  "));f.close()
 print("ALTAR_SOURCE_PARTIES checks=",checks," failures=",failures," draws=",draws);quit(1 if failures else 0)
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

func event_context()->Dictionary:
 return {"items":{},"gold":5000,"level":100,"group":1,"seed":341,"external":{},"bags":{},"refills":{},"now":1000000.,"hp":100.,"max_hp":100.}
func branch(actor:Dictionary,source:Dictionary,answers:Array,ctx:Dictionary)->Dictionary:
 var session=Events.begin_context(actor,source.scripts[actor.script],ctx)
 for answer in answers:
  if session.status!="window":break
  Events.choose_context(session,answer)
 event_report.append({"actor":actor.id,"answers":answers,"status":session.status,"destination":session.get("destination",[]),"blocker":session.get("blocker",{}),"items":session.context.items})
 return session
func event_choices():
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"Staged/events/data.json"))
 var server:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_server/events/data.json"))
 for id in ["5288","5291","5294","5297"]:
  var actor:Dictionary=server.actors[id];data.actors[id]=actor;data.scripts[actor.script]=server.scripts[actor.script]
 for pair in [["5284",15557],["5285",15558],["5286",15548],["5288",15549],["5289",15559],["5291",15560]]:
  for answer in ["YES","NO"]:
   var x=11 if pair[0]=="5288" and answer=="YES" or pair[0]!="5288" and answer=="NO" else 15
   var result=branch(data.actors[pair[0]],data,[answer],event_context())
   check(result.status=="warp"and result.destination==[0,pair[1],x,19],"Original inquiry choice retains exact landing "+pair[0]+answer)
 for pair in [[["NEXT","YES"],15],[["NEXT","NO"],11]]:
  var result=branch(data.actors["5287"],data,pair[0],event_context())
  check(result.status=="warp"and result.destination==[0,15550,pair[1],19],"Conscription retains both sequential windows")
 for pair in [[["YES"],11],[["NO","YES"],15],[["NO","NO"],13]]:
  var result=branch(data.actors["5290"],data,pair[0],event_context())
  check(result.status=="warp"and result.destination==[0,15553,pair[1],19],"Hunger retains three distinct original choices")
 for pair in [["5292",1530,15,6,18780],["5293",1530,15,6,18781],["5294",1530,15,6,18782],["5295",15551,76,47,18780],["5296",15551,81,87,18781],["5297",15551,74,67,18782]]:
  var unknown=branch(data.actors[pair[0]],data,["OK"],event_context())
  check(unknown.status=="blocked"and unknown.blocker.reason.contains("itemspace"),"Unknown original capacity remains guarded "+pair[0])
  var ctx=event_context();ctx.external.itemspace=1
  var result=branch(data.actors[pair[0]],data,["OK"],ctx)
  check(result.status=="warp"and result.destination==[0,pair[1],pair[2],pair[3]],"Original emissary capacity branch landing "+pair[0])
  check(Events.item_count(result.context.items,pair[4])==1,"Original emissary award retained "+pair[0])
 var statue=branch(data.actors["5298"],data,["NEXT","YES"],event_context())
 check(statue.status=="warp"and statue.destination==[0,15552,14,14]and Events.item_count(statue.context.items,18783)==1,"First statue retains original award and entry")
 var dark=branch(data.actors["5299"],data,["NEXT","YES"],event_context())
 check(dark.status=="blocked"and dark.blocker.reason.contains("consumption lacks"),"Second statue's source KillItem18784remains unresolved; no invented award")
