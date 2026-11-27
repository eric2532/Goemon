extends "res://tests/forest-shrine/original_maps_test.gd"
## Exact original map/route contracts; scenery does not own movement or transfers.
const RouteArt=preload("res://scripts/forest/forest_university_route_art.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Jenova University Route/"

func run():
 var plan=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"route.json"))
 var actual=[]
 for stage in plan.stages:
  var id=int(stage.floor);var row=Original.state(id,341);var cut=Original.crop(id)
  var original=Original.Art.raw_map(Original.path_for(id));var full_width=original.decode_u32(12)
  var full_cells=full_width*original.decode_u32(16);var cells=row.size.x*row.size.y
  for p in stage.path:
   var source=Vector2i(p[0],p[1]);var cell=source-cut.position;var index=source.y*full_width+source.x
   check(Original.open(row.bits,row.size,cell),"Route remains on original open cells "+stage.key)
   check((original.decode_u16(20+(full_cells*2+index)*2)&0xc000)!=0,"Reference walking cell is recorded "+stage.key)
  var equal=true
  for y in row.size.y:
   for x in row.size.x:
    var index=(y+cut.position.y)*full_width+x+cut.position.x
    for plane in 3:
     equal=equal and row.raw.decode_u16(20+(plane*cells+y*row.size.x+x)*2)==original.decode_u16(20+(plane*full_cells+index)*2)
  check(equal,"All three original map planes retained "+stage.key)
  for placement in RouteArt.catalog().maps[str(int(stage.source))].placements:
   var index=int(placement[1])*full_width+int(placement[0])
   check(original.decode_u16(20+(full_cells+index)*2)==int(placement[2]),"Scenery has its original source anchor "+stage.key)
  var links=Original.links(id,341)
  actual.append({"source":stage.source,"floor":id,"links":links.map(func(l):return {"at":str(l.at),"floor":l.get("floor",0),"arrival":str(l.get("arrival",Vector2.ZERO)),"source_gate":str(l.get("source_gate",l.at))})})
 for edge in plan.edges:
  var id=Original.runtime_id(int(edge[0]));var target=Original.runtime_id(int(edge[3]))
  var at=Original.source_point(id,Vector2i(edge[1],edge[2]))
  var links=Original.links(id,341).filter(func(l):return l.get("floor")==target and l.get("source_gate",l.at).is_equal_approx(at))
  check(links.size()==1,"Exact original route crossing "+str(edge))
 check(not RouteArt.contains(4200,Vector2i(47,42)),"Tina is outside the route-owned art")
 check(RouteArt.contains(4300,Vector2i(37,70)),"Snow-region pass includes the Abanis gate approach")
 check(not RouteArt.contains(4310,Vector2i(1,8)),"Optional hospital interior stays outside the snow-region pass")
 var file=FileAccess.open(REVIEW+"runtime-route.json",FileAccess.WRITE);file.store_string(JSON.stringify(actual,"  "));file.close()
 print("UNIVERSITY_ROUTE_PRESERVATION_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
