extends SceneTree
## Direct source-party construction; this does not certify native combat or scenery.
const Source=preload("res://scripts/forest/forest_south_kili_population.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower/"
var checks=0
var failures=0
var seen={}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("WIND_TOWER_PARTY_FAIL ",label)
func _initialize():run.call_deferred()
func verify(party:Array,zone:Dictionary,data:Dictionary):
 var valid=not party.is_empty()and party.size()<=int(zone.maximum);var counts={}
 if party.is_empty():check(false,"Empty source party");return
 var gid:String=party[0][3];var group:Dictionary=data.groups[gid]
 valid=valid and zone.groups.any(func(choice):return choice[0]==gid)
 for member in party:
  var index=group.source_members.find_custom(func(detail):return str(detail.enemy_id)==str(member[2]))
  if index<0:valid=false;continue
  var row:Array=group.members[index]
  valid=valid and member[3]==gid and int(member[0])==int(row[0])and int(member[1])>=int(row[1])and int(member[1])<=int(row[2])
  counts[str(member[2])]=int(counts.get(str(member[2]),0))+1;seen[str(member[2])]=true
 for detail in group.source_members:
  var n=int(counts.get(str(detail.enemy_id),0))
  valid=valid and n<=int(detail.count[1])and(not detail.mandatory or n>=int(detail.count[0]))
 check(valid,"Source IDs/levels/member limits/mandatory rows/total cap "+str(zone.id))
func run():
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"Staged/encounters.json"))
 var initial=JSON.stringify(data);var reports=[];var draw_count=0
 var zones:Array=data.zones.duplicate();zones.append_array(data.bosses.values())
 for zone in zones:
  var rng=RandomNumberGenerator.new();rng.seed=20261128+int(zone.id);var bags={};var count_by_group={}
  # A complete source-weight bag must deliver exactly the documented ticket proportions.
  var period:int=zone.groups.reduce(func(total,row):return total+int(row[1]),0)
  for draw in period:
   var party:Array=Source.group_from_data(zone,bags,rng,data.groups);verify(party,zone,data);draw_count+=1
   var key:String=party[0][3];count_by_group[key]=int(count_by_group.get(key,0))+1
  for choice in zone.groups:check(int(count_by_group.get(choice[0],0))==int(choice[1]),"Exact complete shuffle-bag group weight "+str(zone.id)+":"+choice[0])
  reports.append({"zone":zone.id,"source_map":zone.map,"maximum":zone.maximum,"weight_period":period,"ticket_counts":count_by_group})
 # Select every source group directly, including both rare level1subzones and scripted parties.
 for key in data.groups:
  var original:Dictionary=zones.filter(func(z):return z.groups.any(func(choice):return choice[0]==key))[0]
  var zone:Dictionary=original.duplicate(true);zone.groups=[[key,1]]
  var rng=RandomNumberGenerator.new();rng.seed=20261128+key.hash();var bags={}
  for draw in 256:
   var party:Array=Source.group_from_data(zone,bags,rng,data.groups);verify(party,zone,data);draw_count+=1
   if key in ["wind:10007","wind:10010","wind:10011"]:
    check(party.size()==(5 if key=="wind:10007"else 7),"Every mandatory scripted member, no invented escort")
 var expected={}
 for group in data.groups.values():
  for member in group.source_members:expected[str(member.enemy_id)]=true
 check(expected.size()==25 and seen.size()==25 and expected.keys().all(func(id):return seen.has(id)),"All25source identities including rare variants exercised")
 check(JSON.stringify(data)==initial,"Source package remains immutable")
 var report={"checks":checks,"failures":failures,"draws":draw_count,"source_groups":data.groups.size(),"source_identities":seen.keys(),"zones":reports,
  "native_combat_verified":false,"visual_verified":false,"goal_complete":false,
  "qualification":"Pure existing helper contracts only. Relative group tickets are exact; uniform party sizes, formation, server probability/AI and native/rendered execution remain separately unverified."}
 var file=FileAccess.open(OUT+"party-source-review.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("WIND_TOWER_PARTY ",checks," checks ",failures," failures;",draw_count," draws25identities19groups; no native/visual claim")
 quit(1 if failures else 0)
