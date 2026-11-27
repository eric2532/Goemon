extends SceneTree
## Source layouts and dispatch contracts; review gates change only inside this process.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower/"
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("WIND_MAP_CONTRACT_FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_wind_tower/catalog.json"))
 Original.Art.load_sokia_wind();var flags={};var maps=[]
 for id in Original.Art.SOKIA_WIND_IDS:
  var path=Original.path_for(id);var row:Dictionary=Original.Art.data().maps[path]
  check(row.sokia_visual_only and not Original.owns(id) and not East.owns(id),"Unreviewed map remains gated "+str(id))
  flags[id]=row.sokia_visual_only;row.sokia_visual_only=false
 for id in flags:
  var state=Original.state(id);var row:Dictionary=source.maps[Original.path_for(id)]
  check(Original.owns(id)and East.owns(id),"Existing Original/East owners dispatch review map "+str(id))
  check(state.size==Vector2i(row.size[0],row.size[1])and Original.crop(id).position==Vector2i.ZERO,"Complete source extent, no route crop "+str(id))
  var raw=Original.Art.raw_map(Original.path_for(id));check(raw==state.raw,"All floor/object/flag bytes remain source complete "+str(id))
  var cells:int=state.size.x*state.size.y;var graphics={};var supported=true
  for i in cells:
   for serial in [state.raw.decode_u16(20+i*2),state.raw.decode_u16(20+(cells+i)*2)]:
    if serial<1000:continue
    graphics[serial]=true;supported=supported and Original.Art.data().graphics.has(str(serial))
  check(supported,"Every source graphic has one prepared owner "+str(id))
  maps.append({"id":id,"size":str(state.size),"source_cells":cells,"graphics":graphics.size(),"links":Original.links(id).size()})
 var data=East.data();var wind_zones=data.zones.filter(func(z):return z.get("wind_tower_source",false))
 check(wind_zones.size()==14,"All fourteen source zones are assigned")
 check(East.zone_at(20310,Vector2i(10,60)).id==6043 and East.zone_at(20310,Vector2i(56,60)).id==6044,"Both rare subzones outrank the ordinary floor10pool")
 check(East.zone_at(20002,Vector2i(43,7)).is_empty()and East.zone_at(20003,Vector2i(43,7)).is_empty(),"No invented ambient group at scripted gates")
 check(data.scripted_battles.filter(func(b):return int(b.source)in Original.Art.SOKIA_WIND_IDS).size()==4,"Both Arcas actors and both guardians retain their source pool")
 var rng=RandomNumberGenerator.new();rng.seed=20261128;var groups={};var identities={}
 for zone in wind_zones:
  for choice in zone.groups:
   var one:Dictionary=zone.duplicate(true);one.groups=[choice]
   for draw in 64:
    var party=East.group(one,{},rng)
    check(not party.is_empty()and party.size()<=int(zone.maximum)and party.all(func(m):return East.available(int(m[0]))and m.size()==4),"Existing source helper retains available native IDs and cap "+choice[0])
    groups[choice[0]]=true
    for member in party:identities[str(member[2])]=true
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 check(flags.keys().all(func(id):return not Original.owns(id)and not East.owns(id)),"Production gates restored")
 var report={"checks":checks,"failures":failures,"maps":maps,"ambient_groups":groups.keys(),"ambient_identities":identities.keys(),"native_combat":false,"visual_approval":false,"goal_complete":false}
 var file=FileAccess.open(OUT+"runtime-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("WIND_MAP_CONTRACT ",checks," checks ",failures," failures ",maps.size()," complete source maps")
 quit(1 if failures else 0)
