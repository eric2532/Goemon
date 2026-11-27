extends SceneTree
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
var checks=0
var failures=[]
class Model extends RefCounted:
 var terrain_detail="falan_arena"
 var falan_area="interior"
 var falan_floor=1155
 var seed_value=1701
 var props={}
func _initialize():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 if not value:failures.append(label)
func run():
 set_meta("falan_venture",{"falan_areas":{"city":{}}})
 var rows=[]
 for source in Region.data().fixed_maps:
  var id:int=Maps.runtime_id(source)
  if Maps.owns(id):continue
  if source in [2000,2400]:continue
  var model=Model.new();model.falan_floor=id
  var links=Tour.links(model,self);var expected=Region.links_source(source,1701)
  check(not links.any(func(link):return link.to in ["city","castle","interior","freyja_outside","freyja_return"]),"Legacy phantom return in source%d"%source)
  for wanted in expected:
   check(links.any(func(link):return link.at.is_equal_approx(wanted.at) and link.get("floor",-1)==wanted.get("floor",-1) and link.get("east_source_return",{})==wanted.get("east_source_return",{})),"Source door omitted by Tour integration source%d"%source)
  for i in links.size():
   for j in range(i):
    check(not (links[i].at.is_equal_approx(links[j].at) and links[i].to==links[j].to and links[i].get("floor",-1)==links[j].get("floor",-1) and links[i].get("east_source_return",{})==links[j].get("east_source_return",{})),"Duplicate Tour door in source%d"%source)
  rows.append({"source":source,"runtime":id,"source_links":expected.size(),"merged_links":links.size(),"legacy_data_rows":Tour.Indoor.Data.DOORS.get(id,[]).size()})
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/legacy-door-matrix.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"maps":rows}," ")+"\n");file.close()
 print("EAST_LEGACY_DOORS_RESULT maps=",rows.size()," checks=",checks," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(0 if failures.is_empty() else 1)
