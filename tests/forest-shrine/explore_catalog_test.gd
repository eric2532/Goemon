extends "res://tests/forest-shrine/original_maps_test.gd"
const ACCESS_OUT="res://build/Other Files/Asset Toolkit/Explore Access/"
func run():
 var report={"generated":[],"fixed":[],"blockers":[],"qualification":"Prepared source-graph checks only; native on-foot/F/exit and rendered boss verification remain separate."}
 var generated=Original.generated();var count_=0;var graphics={}
 for key in preload("res://assets/maps/falan/explore-dungeon-specs.gd").SPECS:
  var spec:Dictionary=generated.SPECS[key]
  check(generated.count(key,20261127)>=int(spec.minimum)and generated.count(key,20261127)<=int(spec.maximum),"Configured floor count interval "+key)
  for n in range(1,generated.count(key,20261127)+1):
   var id:int=generated.floor_id(key,n);var state=Original.state(id,20261127)
   check(Original.owns(id),"Generated destination has a live map owner %d"%id)
   var cells=state.size.x*state.size.y
   for tile in cells*2:
    var serial=state.raw.decode_u16(20+tile*2)
    if serial==0 or tile>=cells and serial<1000 or graphics.has(serial):continue
    graphics[serial]=true
    check(Original.Art.data().graphics.has(str(serial)),"Generated source graphic has a loaded atlas dependency %d"%serial)
   var links=Original.links(id,20261127)
   check(links.size()==2,"Every generated floor has forward and return exits %d"%id)
   check(connected(id,links[0].at,links[1].at,20261127),"Generated entrances share one preserved walk component %d"%id)
   check(links.all(func(link):return Original.open(state.bits,state.size,Vector2i(((link.at-state.origin)/3.).round()))),"Generated doors occupy open cells %d"%id)
   report.generated.append({"id":id,"branch":key,"floor":n,"source_config":spec.config,"walk_interact_enter_leave":"PENDING","source_walk_component":true})
   count_+=1
 check(count_>=92 and count_<=93,"All required generated floors registered, including the 15–16 floor laboratory cave")
 var ids=Original.Art.FREYJA_TRIAL_IDS+Original.Art.SOKIA_WIND_IDS+Original.Art.SOKIA_DESERT_TEMPLE_IDS+Original.Art.SOKIA_DRAGON_SUMMIT_IDS+Original.Art.EXPLORE_RECOVERED_IDS+Original.Art.EXPLORE_SERVER_IDS+Original.Art.SOKIA_CAPE_ACCESS_IDS
 for id in ids:
  check(Original.owns(id),"Complete staged fixed layout is available %d"%id)
  var links=Original.links(id,20261127);var state=Original.state(id,20261127)
  var row={"id":id,"name":Original.title(id),"doors":[],"walk_interact_enter_leave":"PENDING"}
  for link in links:
   var cell=Vector2i(((link.at-state.origin)/3.).round())
   check(Original.open(state.bits,state.size,cell),"Fixed entrance is on original open ground %d"%id)
   row.doors.append({"at":str(link.at),"to":link.to,"floor":link.get("floor",-1),"arrival":str(link.get("arrival",Vector2.ZERO))})
  if links.is_empty():report.blockers.append({"map":id,"reason":"No ordinary fixed exit; explicit Explore return gate must be tested."})
  report.fixed.append(row)
 var f=FileAccess.open(ACCESS_OUT+"prepared-graph.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("EXPLORE_CATALOG_RESULT checks=",checks," failures=",failures," generated=",count_," fixed=",ids.size())
 finish()
