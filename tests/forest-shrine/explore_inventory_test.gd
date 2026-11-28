extends "res://tests/forest-shrine/original_maps_test.gd"
const Routes=preload("res://scripts/forest/forest_explore_routes.gd")
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const ACCESS="res://build/Other Files/Asset Toolkit/Explore Access/"

func run():
 var census=JSON.parse_string(FileAccess.get_file_as_string(ACCESS+"map-checklist.json"))
 var indoor=Tour.Indoor
 var native_ids:Array=[100,300,1000,1500,2000,2100,2300,2400,3000,3200]
 native_ids.append_array(indoor.Data.FLOORS.keys());native_ids.append_array(indoor.Freyja.ROOMS.keys())
 native_ids.append_array(Winter.TITLES.keys());native_ids.append_array(Winter.Decree.TITLES.keys());native_ids.append_array(Tour.Falken.TITLES.keys())
 native_ids.append_array(Tour.Prayer.FLOORS+[Tour.Prayer.ENTRY,Tour.Prayer.BOSS])
 for n in Original.Beast.COUNT:native_ids.append(Original.Beast.FIRST+n)
 var generated=Original.generated()
 for branch in generated.SPECS:
  for n in range(1,generated.count(branch,20261127)+1):native_ids.append(generated.floor_id(branch,n))
 Routes.data()
 for pair in[[51009,51301,1051009],[51010,51302,1051010]]:
  check(Original.source_id(pair[0])==pair[1]and Original.runtime_id(pair[1])==pair[0],"Generated mountain source/runtime identity is reversible without changing saved floors")
  check(Original.runtime_id(pair[0])==pair[2]and Original.source_id(pair[2])==pair[0],"Recovered original palace retains its separate source/runtime identity")
  check(not East.owns(pair[0])and East.owns(pair[2]),"Native mountain and recovered palace select their own prepared enemy banks")
 check(Original.links(51009,20261127).any(func(link):return int(link.get("floor",-1))==51010)and Original.links(51010,20261127).any(func(link):return int(link.get("floor",-1))==51303),"The original mountain stair chain cannot pick up recovered palace doors")
 check(not Routes.complete_destination(4400),"An incompatible partial campus is not advertised as an Explore destination")
 check(Routes.complete_destination(5005)and Routes.complete_destination(5006),"Complete pinned well layouts remain eligible for their verified Explore entrances")
 for id_ in native_ids:
  var source:int=Original.source_id(int(id_))
  if census.maps.any(func(row):return int(row.map)==source):continue
  census.maps.append({"map":source,"name":Routes.destination_title(source),"catalog":"scripts/forest/forest_original_dungeons.gd"if generated.owns(int(id_))else"scripts/forest/forest_falan_interior.gd","layout_complete":true,"native_layout_defined":true,"generated_layout_seed":20261127 if generated.owns(int(id_))else 0,"entrances":Routes.data().get(str(source),[]),"bosses":Routes.catalog.bosses.get(str(source),[])})
 # Attach source-777 templates only to branches that actually declare them.
 var attached=[]
 for branch in generated.SPECS:
  var spec:Dictionary=generated.SPECS[branch]
  if not spec.get("east",false)or int(spec.get("terminal_enemy",0))<=0:continue
  var id=generated.floor_id(branch,generated.count(branch,20261127))
  var rows=census.maps.filter(func(row):return int(row.map)==id)
  if rows.is_empty():continue
  var declarations=Routes.catalog.bosses.get("777",[]).filter(func(row):return str(row.actor)==str(int(spec.terminal_enemy)))
  var bosses=[]
  for declaration in declarations:
   if bosses.any(func(old):return old.actor==declaration.actor and old.declarations==declaration.declarations):continue
   var boss:Dictionary=declaration.duplicate(true);boss.source=id;boss.template_source=777
   var at=generated.doors(id,20261127)[1]+Vector2i.DOWN;boss.cell=[at.x,at.y]
   bosses.append(boss);attached.append(str(boss.actor))
  rows[0].bosses=bosses
 set_meta("falan_venture",{})
 var report={"qualification":"Runtime ownership/source contracts only. Does not establish on-foot interaction or battle completion.","maps":[],"bosses":[],"native_bosses":[],"blockers":[],"source_zone_blockers":[],"known_sources":[],"missing_fixed_destinations":[],"missing_script_destinations":[]}
 for source in Routes.catalog.source_events.get("bank_sources",[]):check(East.owns(Original.runtime_id(int(source))),"Every restored inline formation owns its prepared native map bank: "+str(int(source)))
 var bank=East.data()
 var regional=preload("res://scripts/forest/forest_university_region.gd")
 for row in census.maps:
  var id=Original.runtime_id(int(row.map));var original=Original.owns(id);var active=known_source(int(row.map))
  var item={"source":row.map,"runtime":id,"name":row.name,"runtime_owner":active,"runtime_owner_kind":"generated"if generated.owns(id)else"original"if original else"native"if active else"unowned","available_source":active,"layout_complete":row.layout_complete,"doors":[],"script_routes":row.entrances,"source_catalog":row.catalog}
  if generated.owns(id)and row.bosses.any(func(b):return b.has("template_source")):item.generated_terminal_bosses=row.bosses
  var links=[]
  if original:links=Original.links(id,20261127)
  elif active and int(row.map)not in[100,300,1000,1500,2000,2100,2300,2400,3000,3200]:
   var model=preload("res://scripts/forest/forest_model.gd").new();model.falan_area="interior";model.falan_floor=id;model.seed_value=20261127
   links=Tour.links(model,self)
  elif active:
   for link in Tour.LINKS.get("city"if int(row.map)==1000 else"castle"if int(row.map)==1500 else"",[]):links.append(link)
   for door in indoor.Data.DOORS.get(int(row.map),[])+Tour.Regions.Sites.DOORS.get(int(row.map),[]):links.append({"at":door[0],"floor":door[1],"to":"native_source","arrival":door[2]})
   item.door_qualification="Native source declarations; authored building alignment and regional seams require the normal-play map owner."
  if active:
   for link in links:
    item.doors.append({"at":str(link.at),"to":link.to,"target":link.get("floor",-1),"restricted":Routes.restricted(link)})
  report.maps.append(item)
  for boss in row.bosses:
   var source=East
   var role:Dictionary=Routes.catalog.get("source_events",{}).get("actors",{}).get("%d:%s"%[int(row.map),str(boss.actor)],{})
   var owner:String=role.get("battle_owner","")
   if owner.begins_with("regional:"):source=regional.bank_for(owner.trim_prefix("regional:"))
   for key in regional.BOSSES:
    var spec=regional.specification(key,20261127)
    if spec.map==id and str(boss.actor)in spec.get("actors",[]):source=regional.bank_for(key);break
   var cape=load("res://scripts/forest/forest_sokia_cape.gd")
   if cape.access().actors.get(str(boss.actor),{}).get("battle_owner","")=="sokia_cape":source=cape
   var boss_bank:Dictionary=source.data()
   var status={"source":row.map,"runtime":id,"actor":boss.actor,"name":boss.name,"runtime_owner":active,"encounters":[],"blockers":[]}
   for declaration in boss.declarations:
    var args:String=declaration.strip_edges()
    var expression=RegEx.new();expression.compile("(?i)^encount\\s+");args=expression.sub(args,"")
    var fields=args.split("|",true)
    var choices=preload("res://scripts/forest/forest_east_battles.gd").encounter_choices(args)
    if choices.is_empty():status.blockers.append("Unresolved original encounter syntax: "+args);continue
    var pending=choices.duplicate();var seen={}
    while not pending.is_empty():
     var encounter:int=pending.pop_back()
     if encounter<=0 or seen.has(encounter):continue
     seen[encounter]=true;status.encounters.append(encounter)
     if owner=="frostpass_slot" and encounter==12008:
      status.native_owner="forest_waves.gd original native dual-king/cursed spell owner";continue
     if owner=="falken_slot" and encounter==11009:
      status.native_owner="forest_waves.gd native Falken formation";continue
     if int(row.map)==16508 and encounter==11007:
      status.native_owner="scripts/forest/forest_black_prayer_events.gd + forest_waves.gd native Ruby formation";continue
     var zone:Dictionary=boss_bank.bosses.get(str(encounter),{})
     if zone.is_empty():status.blockers.append("Original encounter %d is not in the prepared East source bank; review its original owner."%encounter);continue
     if zone.groups.is_empty():status.blockers.append("Original encounter %d has no prepared source party."%encounter)
     if not zone.get("preparation_blockers",[]).is_empty():status.get_or_add("source_party_blockers",[]).append({"encounter":encounter,"details":zone.preparation_blockers})
     for choice in zone.groups:
      if boss_bank.groups[choice[0]].details.is_empty():status.blockers.append("Original encounter %d group %s has no prepared members."%[encounter,choice[0]])
      for member in boss_bank.groups[choice[0]].details:
       if not source.available(int(member.species))if source==East else boss_bank.species[int(member.species)].bank not in["companion","sokia_region","university"]:
        var message="Original appearance %d lacks an authenticated attack contact marker (encounter %d)."%[boss_bank.species[int(member.species)].id,encounter]
        if message not in status.blockers:status.blockers.append(message)
     if int(zone.next_encounter)>0:pending.append(int(zone.next_encounter))
   report.bosses.append(status)
   if active and not status.blockers.is_empty():report.blockers.append(status)
 for key in regional.BOSSES:
  var spec=regional.specification(key,20261127);var source=regional.bank_for(key);var payload:Dictionary=source.data()
  var status={"source":Original.source_id(spec.map),"runtime":spec.map,"actor":"regional:"+key,"actors":spec.get("actors",[]),"name":key,"runtime_owner":known_source(Original.source_id(spec.map)),"encounters":[],"blockers":[]}
  var pending=[int(spec.encounter)];var seen={}
  while not pending.is_empty():
   var encounter:int=pending.pop_back()
   if encounter<=0 or seen.has(encounter):continue
   seen[encounter]=true;status.encounters.append(encounter)
   var zone:Dictionary=payload.bosses.get(str(encounter),{})
   if zone.is_empty()or zone.get("groups",[]).is_empty():status.blockers.append("Original encounter %d has no prepared source party."%encounter);continue
   for choice in zone.groups:
    for detail in payload.groups[choice[0]].details:
     var species:Dictionary=payload.species[int(detail.species)]
     if species.bank=="unavailable":status.blockers.append("Original appearance %d (%s): %s"%[species.id,species.name,species.get("reason","Original native action/contact contract is unavailable.")])
   if int(zone.next_encounter)>0:pending.append(int(zone.next_encounter))
  report.native_bosses.append(status)
  if not status.blockers.is_empty():report.blockers.append(status)
 for warp in Original.Art.data().warps:
  for source in[int(warp[0]),int(warp[3])]:
   if source not in report.known_sources and known_source(source):report.known_sources.append(source)
  if known_source(int(warp[0]))and not known_source(int(warp[3])):report.missing_fixed_destinations.append(warp)
 for source in Routes.data():
  if not known_source(int(source)):continue
  for route in Routes.data()[source]:
   if not known_source(int(route.target)):report.missing_script_destinations.append(route)
 for zone in bank.zones:
  if not zone.get("preparation_blockers",[]).is_empty():
   report.source_zone_blockers.append({"source":int(zone.map),"encounter":int(zone.id),"reason":"Original party distribution is incomplete.","details":zone.preparation_blockers})
 var file=FileAccess.open(ACCESS+"runtime-inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EXPLORE_INVENTORY_RESULT maps=",report.maps.size()," runtime_owners=",report.maps.filter(func(m):return m.runtime_owner).size()," scripted_bosses=",report.bosses.size()," source_contract_blockers=",report.blockers.size())
 finish()

func known_source(source:int)->bool:
 if source in[100,300,1000,1500,2000,2100,2300,2400,3000,3200]:return true
 var id=Original.runtime_id(source);var indoor=load("res://scripts/forest/forest_falan_interior.gd")
 return Original.owns(id)or indoor.Data.FLOORS.has(id)or indoor.Freyja.ROOMS.has(id)or indoor.Winter.TITLES.has(id)or indoor.Winter.Decree.owns(id)or indoor.Falken.owns(id)or indoor.Prayer.owns(id)or indoor.RoomArt.palace(id)
