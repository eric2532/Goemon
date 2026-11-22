extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Streets=preload("res://scripts/forest/forest_falan_streets.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Details=preload("res://scripts/forest/forest_falan_street_details.gd")
const OUT="res://build/Other Files/Asset Toolkit/Falan City Details/"
var errors=0
func check(ok:bool,message:String):
 if not ok:errors+=1;printerr("FALAN_PLANTER_FAIL ",message)

func _initialize():run.call_deferred()

func triangles(mesh:Mesh)->int:
 var result=0
 for surface in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX]
  result+=(indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 return result

func run():
 set_meta("falan_venture",{})
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/reference/maps/forest_falan_city.json"))
 var model=Model.new();model.reset(42,{},layout,false)
 var links=Tour.links(model,self);model.set_meta("falan_links",links)
 var protected:Array[Vector2]=[]
 for link in links:protected.append(link.at)
 for npc in Tour.NPCS.AREAS.city:protected.append(npc[0])
 var records=[];var counts={}
 for row in Streets.Data.PLANTERS:
  var p=Streets.ground(model,row[0]);var reasons=[]
  if not model.terrain.disk_clear(p+Vector3.UP*.1,1.25):reasons.append({"kind":"terrain","covered":model.terrain.contains(p.x,p.z),"height":p.y})
  for link in links:
   if row[0].distance_to(link.at)<2.60:reasons.append({"kind":"door","link":str(link)})
  for npc in Tour.NPCS.AREAS.city:
   if row[0].distance_to(npc[0])<2.60:reasons.append({"kind":"npc","npc":str(npc)})
  var bounds=AABB(p-Vector3(1.25,0,1.25),Vector3(2.5,1.2,2.5))
  for anchor in model.scenery_obstacles:
   var obstacle:AABB=model.scenery_obstacles[anchor]
   if obstacle.intersects(bounds):reasons.append({"kind":"scenery","anchor":str(anchor),"prop":str(model.props.get(anchor,{})),"bounds":str(obstacle)})
  var fits=Streets.fits(model,p,1.25,protected)
  if not fits:
   for reason in reasons:counts[reason.kind]=counts.get(reason.kind,0)+1
   records.append({"at":[p.x,p.z],"graphic":row[1],"reasons":reasons})
 check(records.is_empty(),"Every one of the 226 native planter stations clears source-centered houses and preserved routes")
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/city_building_surfaces.json"))
 for anchor in model.CityHouses.Data.SOURCE_CENTERS:
  var original=model.props[anchor]
  var native:Vector2=model.CityHouses.Data.SOURCE_CENTERS[anchor]
  check(source.bindings.any(func(row):return row.marker.x==anchor.x and row.marker.z==anchor.y and Vector2(row.source_center[0],row.source_center[1])==native),"House center matches its original source record")
  var expected=model.CityArchitecture.collision(model.CityHouses.ArchitectureData.BINDINGS[anchor][0])
  expected.position+=model.scenery_point(anchor)+model.CityHouses.offset(model,anchor)
  check(model.scenery_obstacles[anchor].is_equal_approx(expected),"The house collider uses its recovered source footprint")
  for changed in [original.merged({"rotation":original.rotation+1},true),original.merged({"scale":original.scale+.01},true)]:
   model.props[anchor]=changed
   check(model.CityHouses.offset(model,anchor)==Vector3.ZERO,"Edited houses keep their custom placement")
  model.props[anchor]=original
  model.scenery_heights[anchor]=.1
  check(model.CityHouses.offset(model,anchor)==Vector3.ZERO,"Raised houses keep their custom placement")
  model.scenery_heights.erase(anchor)
  model.props.erase(anchor)
  check(model.CityHouses.offset(model,anchor)==Vector3.ZERO,"Removed source houses remain removed")
  model.props[anchor]=original
 for row in Tour.Indoor.Data.DOORS.get(1000,[]):
  check(links.any(func(link):return link.get("floor",-1)==row[1] and link.at==row[0]),"Every native city doorway retains its exact source station")
 var shrub_triangles=0;var metrics={}
 for part in Details.Assets.source("leafy_shrub"):shrub_triangles+=triangles(part.mesh)
 for serial in [10426,10427,10452,10453]:
  var body:Mesh=Details.prepare(serial);var leaves:Mesh=Details.foliage(serial)
  check(triangles(leaves)==shrub_triangles*2,"Native-painted canopies preserve both complete reused shrub meshes")
  metrics[str(serial)]={"body_triangles":triangles(body),"foliage_triangles":triangles(leaves),"body_surfaces":body.get_surface_count(),"foliage_surfaces":leaves.get_surface_count(),"body_bounds":str(body.get_aabb()),"foliage_bounds":str(leaves.get_aabb())}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Planter Recovery"))
 var audit=FileAccess.open(OUT+"Planter Recovery/procedural-meshes.json",FileAccess.WRITE)
 audit.store_string(JSON.stringify(metrics,"  "));audit.close()
 var file=FileAccess.open(OUT+"planter-placement-after.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"excluded":records,"reasons":counts},"  "));file.close()
 print("FALAN_PLANTER_DIAG excluded=",records.size()," reasons=",counts," failures=",errors)
 quit(1 if errors else 0)
