extends SceneTree
## Complete source planes, conditional shuffle bags and rare identities; no visual/combat claim.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const South=preload("res://scripts/forest/forest_south_kili_population.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Desert Temple/"
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("DESERT_MAP_FAIL ",label)
func _initialize():run.call_deferred()
func run():
 Maps.Art.load_sokia_desert_temple();var flags={};var map_rows=[]
 for id in Maps.Art.SOKIA_DESERT_TEMPLE_IDS:
  var row:Dictionary=Maps.Art.data().maps[Maps.path_for(id)]
  check(row.sokia_visual_only and not Maps.owns(id)and not East.owns(id),"Normal source access stays gated "+str(id));flags[id]=row.sokia_visual_only;row.sokia_visual_only=false
 for id in flags:
  var row=Maps.state(id);var source:Dictionary=Maps.Art.data().maps[Maps.path_for(id)]
  check(Maps.owns(id)and East.owns(id),"One existing map/native owner "+str(id))
  check(row.size==Vector2i(source.size[0],source.size[1])and Maps.crop(id).position==Vector2i.ZERO,"Full source extent "+str(id))
  check(row.raw==Maps.Art.raw_map(Maps.path_for(id)),"Exact complete floor/object/flag bytes "+str(id))
  var residents=South.server_events(id)
  check(residents.actors.values().filter(func(a):return int(a.source)==id).size()==[4,1,2,1,4,2,0][id-13016],"Every original source actor retained "+str(id))
  map_rows.append({"id":id,"size":str(row.size),"ports":Maps.links(id).size()})
 check(Maps.state(13022).raw.decode_u16(20+(400+4*20+7)*2)==13998,"Recorded client entrance marker survives server zero")
 var zones=East.data().zones.filter(func(z):return z.get("source_party_contract",false));check(zones.size()==9,"All nine source zones assigned")
 check(East.zone_at(13016,Vector2i(15,20)).id==7022 and East.zone_at(13018,Vector2i(15,10)).id==7025,"Rare pockets retain priority5over ordinary priority1")
 var rng=RandomNumberGenerator.new();rng.seed=20261127;var groups={};var identities={};var draws=0
 for zone in zones:
  for choice in zone.groups:
   var one:Dictionary=zone.duplicate(true);one.groups=[choice]
   var held={"source_item_18462":1}
   for draw in 128:
    var party=East.group(one,{},rng,held);draws+=1
    check(not party.is_empty()and party.size()<=int(zone.maximum)and party.all(func(m):return m.size()==4 and East.available(int(m[0]))),"Original native contract "+str(choice[0]))
    groups[choice[0]]=true;var counts={};var g:Dictionary=East.data().groups[choice[0]]
    for m in party:
     identities[str(m[2])]=true;counts[str(m[2])]=int(counts.get(str(m[2]),0))+1
     var at=g.source_members.find_custom(func(s):return str(s.enemy_id)==str(m[2]))
     check(at>=0 and int(m[1])>=int(g.members[at][1])and int(m[1])<=int(g.members[at][2]),"Source identity and level range "+str(m[2]))
    for m in g.source_members:
     var count_=int(counts.get(str(m.enemy_id),0))
     check(count_<=int(m.count[1])and(not m.mandatory or count_>=int(m.count[0])),"Member cap/mandatory source rule "+str(m.enemy_id))
 var gated=zones[0].duplicate(true);gated.groups=[["desert:7021",1]]
 check(East.group(gated,{},rng,{}).is_empty(),"Missing source item denies gated group")
 var allowed=East.group(gated,{},rng,{"source_item_18462":1})
 check(allowed.count(allowed.filter(func(m):return str(m[2])=="11040")[0])==1,"Held item enables one mandatory general")
 var zone:Dictionary=East.zone_at(13016,Vector2i(30,30));var bags={};var held={"source_item_18462":1}
 var expected=South.eligible_groups(zone,held,East.data().groups);var total=0
 for c in expected:total+=int(c[1])
 var counts={}
 for i in total:
  var party=East.group(zone,bags,rng,held);var id=str(party[0][3]);counts[id]=int(counts.get(id,0))+1
 for c in expected:check(int(counts.get(str(c[0]),0))==int(c[1]),"Held-item shuffle bag retains exact source group tickets "+str(c[0]))
 expected=South.eligible_groups(zone,{},East.data().groups);total=0
 for c in expected:total+=int(c[1])
 counts={}
 for i in total:
  var party=East.group(zone,bags,rng,{});var id=str(party[0][3]);counts[id]=int(counts.get(id,0))+1
 for c in expected:check(int(counts.get(str(c[0]),0))==int(c[1]),"Inventory change excludes stale gated tickets "+str(c[0]))
 check(not counts.has("desert:7021"),"Removed item cannot draw an obsolete gated group")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_desert_temple/encounters.json"));var generated:Dictionary=source.generated_approach.pool
 var approach_ids={};var approach_levels={}
 for choice in generated.groups:
  var one:Dictionary=generated.duplicate(true);one.groups=[choice]
  for i in 128:
   var party=East.group(one,{},rng,{"source_item_18462":1})
   check(not party.is_empty()and party.size()<=6,"Required approach source party uses existing selector "+str(choice[0]))
   for m in party:
    approach_ids[str(m[2])]=true;approach_levels[int(m[1])]=true
    check(int(m[1])>=26 and int(m[1])<=28 and str(m[2])in["15007","15008","15009"],"Approach template level1does not replace configured26-28interval")
 check(approach_ids.size()==3 and approach_levels.size()==3,"All approach enemy identities and configured levels exercised; generated floors remain unverified")
 check(groups.size()==7 and identities.size()==5 and identities.has("7012")and identities.has("7014"),"All source groups and rare level-one identities exercised")
 for id in flags:Maps.Art.data().maps[Maps.path_for(id)].sokia_visual_only=flags[id]
 check(flags.keys().all(func(id):return not Maps.owns(id)and not East.owns(id)),"Original production gates restored")
 var report={"checks":checks,"failures":failures,"maps":map_rows,"groups":groups.keys(),"enemy_ids":identities.keys(),"draws":draws,"native_combat":false,"visual_approval":false,"goal_complete":false}
 var f=FileAccess.open(OUT+"runtime-contracts.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("DESERT_MAP_RESULT checks=",checks," failures=",failures," draws=",draws);quit(1 if failures else 0)
