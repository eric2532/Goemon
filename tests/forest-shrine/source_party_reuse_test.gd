extends SceneTree
## Seeded equivalence for the existing owner, then source caps/rare IDs for new maps.
const Source=preload("res://scripts/forest/forest_south_kili_population.gd")
const REPORT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Trial caves/"
var checks=0
var failures=0
var source_contract:Script=Source
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("SOURCE_PARTY_REUSE_FAIL ",label)
func _initialize():
 create_timer(180).timeout.connect(func():printerr("SOURCE_PARTY_REUSE_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var before="--record-before"in OS.get_cmdline_user_args();var trace=[]
 for zone in Source.data().zones:
  var rng=RandomNumberGenerator.new();rng.seed=20261127+int(zone.id);var bags={};var parties=[]
  for items in [{},{"source_item_18403":1},{"source_item_18403":1,"source_item_18404":1}]:
   for draw in 8:parties.append(Source.group(zone,bags,rng,items))
  trace.append([zone.id,parties,str(rng.state),JSON.stringify(bags)])
 var signature=JSON.stringify(trace).sha256_text()
 var result={"source_zones":trace.size(),"seeded_signature":signature,"before":before}
 if before:
  var file=FileAccess.open(REPORT+"party-before.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
 else:
  var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"party-before.json"))
  check(signature==baseline.seeded_signature and trace.size()==int(baseline.source_zones),"Every existing source party/RNG/bag result stays byte-equivalent")
  var trial:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"Staged/encounters.json"));var original=JSON.stringify(trial);var seen={}
  for zone in trial.zones:
   var rng=RandomNumberGenerator.new();rng.seed=20261127+int(zone.id);var bags={}
   for draw in 512:
    var party:Array=source_contract.call("group_from_data",zone,bags,rng,trial.groups)
    var valid=not party.is_empty() and party.size()<=int(zone.maximum);var counts={}
    if party.is_empty():check(false,"Trial party is nonempty "+str(zone.id));continue
    var gid:String=party[0][3];var group:Dictionary=trial.groups[gid]
    valid=valid and zone.groups.any(func(choice):return choice[0]==gid)
    for member in party:
     valid=valid and member[3]==gid
     var index=group.source_members.find_custom(func(detail):return str(detail.enemy_id)==str(member[2]))
     if index<0:valid=false;continue
     var detail:Dictionary=group.source_members[index];var row:Array=group.members[index]
     valid=valid and int(member[0])==int(row[0]) and int(member[1])>=int(row[1]) and int(member[1])<=int(row[2])
     counts[str(member[2])]=int(counts.get(str(member[2]),0))+1;seen[str(member[2])]=true
    for detail in group.source_members:
     var count_=int(counts.get(str(detail.enemy_id),0))
     valid=valid and count_<=int(detail.count[1]) and (not detail.mandatory or count_>=int(detail.count[0]))
    check(valid,"Source trial group/level/cap/identity "+str(zone.id)+" "+str(draw))
  check(seen.size()==6 and seen.has("5000")and seen.has("5002"),"All six source IDs include both rare level1 variants")
  check(JSON.stringify(trial)==original,"Prepared source data stays immutable")
 result.merge({"checks":checks,"failures":failures,"qualification":"Pure party/RNG/index contracts only; native contact, map gates and rendered appearance remain separate."})
 var file=FileAccess.open(REPORT+("party-before-result.json"if before else"party-reuse.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
 print("SOURCE_PARTY_REUSE ",checks," checks ",failures," failures before=",before," zones=",trace.size());quit(1 if failures else 0)
