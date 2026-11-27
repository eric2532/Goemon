extends "res://tests/forest-shrine/original_maps_test.gd"
const Routes=preload("res://scripts/forest/forest_explore_routes.gd")
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const ACCESS="res://build/Other Files/Asset Toolkit/Explore Access/"

func run():
 var census=JSON.parse_string(FileAccess.get_file_as_string(ACCESS+"map-checklist.json"))
 var report={"qualification":"Runtime ownership/source contracts only. Does not establish on-foot interaction or battle completion.","maps":[],"bosses":[],"blockers":[],"missing_fixed_destinations":[]}
 var bank=East.data()
 for row in census.maps:
  var id=Original.runtime_id(int(row.map));var active=Original.owns(id)
  var item={"source":row.map,"runtime":id,"name":row.name,"runtime_owner":active,"layout_complete":row.layout_complete,"doors":[],"script_routes":row.entrances}
  if active:
   for link in Original.links(id,20261127):
    item.doors.append({"at":str(link.at),"to":link.to,"target":link.get("floor",-1),"restricted":Routes.restricted(link)})
  report.maps.append(item)
  for boss in row.bosses:
   var source=East
   var cape=load("res://scripts/forest/forest_sokia_cape.gd")
   if cape.access().actors.get(str(boss.actor),{}).get("battle_owner","")=="sokia_cape":source=cape
   var boss_bank:Dictionary=source.data()
   var status={"source":row.map,"runtime":id,"actor":boss.actor,"name":boss.name,"runtime_owner":active,"encounters":[],"blockers":[]}
   for declaration in boss.declarations:
    var args:String=declaration.strip_edges()
    var expression=RegEx.new();expression.compile("(?i)^encount\\s+");args=expression.sub(args,"")
    var fields=args.split("|",true)
    if fields.size()<10 or not fields[9].is_valid_int():status.blockers.append("Unresolved original encounter syntax: "+args);continue
    var pending=[int(fields[9])];var seen={}
    while not pending.is_empty():
     var encounter:int=pending.pop_back()
     if encounter<=0 or seen.has(encounter):continue
     seen[encounter]=true;status.encounters.append(encounter)
     var zone:Dictionary=boss_bank.bosses.get(str(encounter),{})
     if zone.is_empty():status.blockers.append("Original encounter %d is not in the prepared East source bank; review its original owner."%encounter);continue
     for choice in zone.groups:
      for member in boss_bank.groups[choice[0]].details:
       if not source.available(int(member.species))if source==East else boss_bank.species[int(member.species)].bank not in["companion","sokia_region"]:
        var message="Original appearance %d lacks an authenticated attack contact marker (encounter %d)."%[boss_bank.species[int(member.species)].id,encounter]
        if message not in status.blockers:status.blockers.append(message)
     if int(zone.next_encounter)>0:pending.append(int(zone.next_encounter))
   report.bosses.append(status)
   if active and not status.blockers.is_empty():report.blockers.append(status)
 for warp in Original.Art.data().warps:
  if known_source(int(warp[0]))and not known_source(int(warp[3])):report.missing_fixed_destinations.append(warp)
 var file=FileAccess.open(ACCESS+"runtime-inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EXPLORE_INVENTORY_RESULT maps=",report.maps.size()," runtime_owners=",report.maps.filter(func(m):return m.runtime_owner).size()," scripted_bosses=",report.bosses.size()," source_contract_blockers=",report.blockers.size())
 finish()

func known_source(source:int)->bool:
 if source in[100,300,1000,1500,2000,2100,2300,2400,3000,3200]:return true
 var id=Original.runtime_id(source);var indoor=load("res://scripts/forest/forest_falan_interior.gd")
 return Original.owns(id)or indoor.Data.FLOORS.has(id)or indoor.Freyja.ROOMS.has(id)or indoor.Winter.TITLES.has(id)or indoor.Winter.Decree.owns(id)or indoor.Falken.owns(id)or indoor.Prayer.owns(id)or indoor.RoomArt.palace(id)
