extends SceneTree
## Pure generated-array census: no map scene, viewport, imports or rendering.
const Dungeons=preload("res://scripts/forest/forest_original_dungeons.gd")
const PATH="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Owned240/generator-placements.json"
func _initialize():run.call_deferred()
func run():
 var sources={};for path in["scripts/forest/forest_original_dungeons.gd","assets/maps/falan/east_region/dungeon_specs.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
 var rows=[];var total=0;var failures=[]
 for key in["east_704","east_4102"]:
  var spec:Dictionary=Dungeons.SPECS[key]
  for seed_ in[1729,2718,31415]:
   var floors=Dungeons.count(key,seed_)
   for number_ in range(1,floors+1):
    var id=Dungeons.floor_id(key,number_);var map=Dungeons.make(id,seed_);var n=int(map.size.x*map.size.y);var cells=[]
    for i in n:
     var serial=map.raw.decode_u16(20+(n+i)*2)
     if serial==11627:
      var cell=Vector2i(i%map.size.x,i/map.size.x);cells.append([cell.x,cell.y])
      if Dungeons.Winter.Recovered.open(map.bits,map.size,cell):failures.append("Decoration changed a source-generated open cell")
     if serial==15183:failures.append("Unwhitelisted15183 unexpectedly spawned")
    total+=cells.size();rows.append({"config":int(spec.config),"branch":key,"seed":seed_,"floor":number_,"runtime_map":id,"size":[map.size.x,map.size.y],"graphic":11627,"eligible_cells":cells,"placement_count":cells.size(),"raw_sha256":map.raw.hex_encode().sha256_text()})
 for path in sources:
  if sources[path]!=FileAccess.get_sha256("res://"+path):failures.append("Source changed: "+path)
 var report={"scope":"Three fixed seeds, every generated floor in both11627-eligiblebranches. Array-only existing production generator; no scene or rendered proof.","source_hashes":sources,"source_config_ids":[704,4102],"graphic":11627,"floor_samples":rows.size(),"eligible_placements":total,"rows":rows,"failures":failures}
 var f=FileAccess.open(PATH,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print("EAST_NATURE_GENERATOR_CENSUS floors=",rows.size()," eligible=",total," failures=",failures.size());quit(1 if not failures.is_empty()else 0)
