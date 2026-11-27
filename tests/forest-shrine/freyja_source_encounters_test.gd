extends SceneTree
## Exercise the staged whole-map100 contract through the existing shuffle-bag owner.
const Source=preload("res://scripts/forest/forest_south_kili_population.gd")
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja source encounters/"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FREYJA_ENCOUNTER_FAIL ",label)
func run():
 var staged:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"prepared.json"))
 var original=Source.data();var source_species:Array=staged.species
 check(original.species.slice(0,int(staged.base_species_count))==source_species,"Every established species/member index stays exact")
 check(FileAccess.get_sha256("res://assets/characters/crossgate/falan_encounters/motions.json")==staged.bank_sha256,"Every source appearance uses the checked existing actor bank")
 Source.population=original.duplicate(true);Source.population.groups.merge(staged.groups,true)
 var rng=RandomNumberGenerator.new();rng.seed=41829558;var weights=[];var cases=[]
 for zone in staged.zones:
  var expected={};var observed={};var total=0;var bags={}
  for choice in zone.groups:expected[choice[0]]=int(choice[1]);total+=int(choice[1])
  for ticket in total:
   var party=Source.group(zone,bags,rng)
   check(not party.is_empty(),"Source zone%s releases a nonempty native party"%zone.id)
   if party.is_empty():continue
   var gid:String=party[0][3];observed[gid]=observed.get(gid,0)+1
  check(observed==expected,"Zone%s consumes exactly its documented weighted group bag"%zone.id)
  weights.append({"zone":zone.id,"expected":expected,"observed":observed})
 var ids=staged.groups.keys();ids.sort()
 for gid in ids:
  var raw:Dictionary=staged.groups[gid];var zone:Dictionary
  for candidate in staged.zones:
   if candidate.groups.any(func(choice):return choice[0]==gid):zone=candidate.duplicate(true);break
  zone.groups=[[gid,1]]
  var bags={"south-count:%s:%s"%[zone.id,gid]:[int(zone.maximum)]}
  var party=Source.group(zone,bags,rng);var counts={};var valid_levels=true;var exact_ids=true
  for member in party:
   var eid:String=member[2];counts[eid]=counts.get(eid,0)+1
   var matches=[]
   for i in raw.source_members.size():
    if raw.source_members[i].enemy_id==eid:matches.append(raw.members[i])
   exact_ids=exact_ids and member[3]==gid and not matches.is_empty()
   valid_levels=valid_levels and matches.any(func(row):return int(member[0])==int(row[0]) and int(member[1])>=int(row[1]) and int(member[1])<=int(row[2]))
  check(not party.is_empty() and party.size()<=int(zone.maximum),"Group%s retains source maximum and adapted one-member minimum"%gid)
  check(exact_ids and valid_levels,"Group%s preserves distinct enemy IDs, member indices and source level ranges"%gid)
  var within_caps=true;var mandatory=true
  for member in raw.source_members:
   within_caps=within_caps and counts.get(member.enemy_id,0)<=int(member.count[1])
   if member.mandatory:mandatory=mandatory and counts.get(member.enemy_id,0)>=int(member.count[0])
  check(within_caps and mandatory,"Group%s retains each documented member cap/mandatory minimum"%gid)
  cases.append({"group":gid,"zone":zone.id,"maximum":zone.maximum,"party":party,"source_counts":raw.source_members})
 var eastern=[]
 for zone in staged.zones:
  var party=East.group(zone,{},rng);var exact=not party.is_empty()
  for member in party:
   var group:Dictionary=staged.east_groups[member[3]];var matched=false
   for i in group.source_members.size():
    if group.source_members[i].enemy_id==member[2] and int(group.members[i][0])==int(member[0]):matched=true
   exact=exact and matched and East.available(int(member[0]))
  check(exact,"Existing East/companion owner retains source IDs and mapped indices for zone%s"%zone.id)
  eastern.append({"zone":zone.id,"party":party})
 Source.population=original
 var report={"active":true,"goal_complete":false,"checks":checks,"failures":failures,"zones":weights,"groups":cases,"east_owner":eastern,"qualification":"Source whole-map100 selection through the existing owners. Direct actor contact/camera review and original probability/count-algorithm execution remain separate."}
 var file=FileAccess.open(REVIEW+"selection.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("FREYJA_SOURCE_SELECTION ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
