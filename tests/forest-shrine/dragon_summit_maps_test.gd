extends SceneTree
## Complete source ownership, gates and exact available ports; no scenery or natural travel claim.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const South=preload("res://scripts/forest/forest_south_kili_population.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/"
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("DRAGON_MAP_FAIL ",label)
func _initialize():run.call_deferred()
func run():
 Maps.Art.load_sokia_dragon_summit();var flags={};var rows=[];var unavailable=[]
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_dragon_summit/catalog.json"))
 var existing:Dictionary=Maps.Art.data().maps[Maps.path_for(15577)].duplicate(true)
 for id in Maps.Art.SOKIA_DRAGON_SUMMIT_IDS:
  var row:Dictionary=Maps.Art.data().maps[Maps.path_for(id)]
  check(row.sokia_visual_only and not Maps.owns(id)and not East.owns(id),"Normal source access remains gated "+str(id))
  flags[id]=row.sokia_visual_only;row.sokia_visual_only=false
 var actors={}
 for id in flags:
  var row=Maps.state(id);var prepared:Dictionary=source.maps[Maps.path_for(id)]
  check(Maps.owns(id)and East.owns(id)and not South.server_room(id),"One existing native map owner "+str(id))
  check(row.size==Vector2i(prepared.size[0],prepared.size[1])and Maps.crop(id).position==Vector2i.ZERO,"Complete source extent "+str(id))
  check(row.raw==Maps.Art.raw_map(Maps.path_for(id)),"Exact complete source floor/object/flag bytes "+str(id))
  check(Maps.outdoor(id)==prepared.outdoor,"Prepared presentation classification retained "+str(id))
  for actor in South.server_events(id).actors.values():
   if int(actor.source)==id and not actor.get("invisible",false):
    check(not actors.has(actor.id),"Original visible actor has one registry "+actor.id);actors[actor.id]=true
  for port in prepared.fixed_port_candidates:
   var target=int(port.target_map)
   if not Maps.owns(target):unavailable.append(port);continue
   var at=Maps.source_point(id,Vector2i(port.cell[0],port.cell[1]));var arrival=Maps.source_point(target,Vector2i(port.arrival[0],port.arrival[1]))
   var links=Maps.links(id).filter(func(link):return int(link.get("floor",-1))==target and link.at.distance_squared_to(at)<.01)
   check(links.size()==1 and links[0].get("source_arrival",links[0].arrival).distance_squared_to(arrival)<.01,"Exact original available directed port "+str(id)+str(port.cell))
  rows.append({"map":id,"size":str(row.size),"available_ports":Maps.links(id).size()})
 check(actors.size()==42,"Every original visible Dragon/Summit actor retained")
 Region.data();Region.residents();var piano:Dictionary=Region.source_actors.get("5648",{})
 check(not piano.is_empty()and piano.invisible and int(piano.graphic)==0,"Original piano remains an invisible Event anchor")
 var automatic=Region.data().automatic.filter(func(a):return str(a.actor)=="5648")
 check(automatic.is_empty(),"Original Event graphic0does not invent an automatic trigger")
 var anchors=Region.manual_anchors([15570],"interior").filter(func(a):return str(a.id)=="5648")
 check(anchors.size()==1 and anchors[0].quest_action=="sokia_server:5648","Original piano uses one transparent ordinary F anchor")
 check(Maps.Art.data().maps[Maps.path_for(15577)]==existing and South.server_events(15577).actors.values().filter(func(a):return int(a.source)==15577).size()==6,"Existing15577layout and six actors stay under their original owner")
 check(East.data().species.size()==258 and East.available(256)and int(East.data().species[256].id)==100452 and int(East.data().species[256].skin)==166,"Published original Jete uses one native East skin")
 for key in ["10029","10030","11011"]:
  check(East.data().bosses.has(key),"All source scripted pools retained "+key)
 check(East.data().scripted_battles.filter(func(b):return int(b.source)in Maps.Art.SOKIA_DRAGON_SUMMIT_IDS).size()==5,"All five source actor fight declarations retained")
 for id in flags:Maps.Art.data().maps[Maps.path_for(id)].sokia_visual_only=flags[id]
 check(flags.keys().all(func(id):return not Maps.owns(id)and not East.owns(id)),"All production review gates restored")
 var f=FileAccess.open(OUT+"runtime-map-contracts.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"maps":rows,"visible_actors":actors.keys(),"unavailable_port_targets":unavailable,"goal_complete":false,"native_combat":false,"natural_access_verified":false,"visual_verified":false},"  "));f.close()
 print("DRAGON_MAP_CONTRACT checks=",checks," failures=",failures," maps=",rows.size()," unavailable_ports=",unavailable.size());quit(1 if failures else 0)
