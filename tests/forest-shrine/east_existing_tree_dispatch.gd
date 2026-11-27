extends SceneTree
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
func _initialize():call_deferred("run")
func run():
 var model=Node3D.new();root.add_child(model);Maps.build(model,43700)
 var expected={1233199:7,1233200:12,1233201:5,1233208:2,1233209:3};var rows=[];var failures=[]
 for serial in expected:
  var reference:Mesh=East.mesh(43700,serial,Maps.Art.data().graphics[str(serial)]);var count=0;var batches=0
  for child in model.get_children():
   if not child is MultiMeshInstance3D or int(child.get_meta("source_graphic",0))!=serial:continue
   if child.multimesh.mesh!=reference:failures.append("Existing conifer bypassed East source-fit owner "+str(serial))
   count+=child.multimesh.instance_count;batches+=1
  if count!=expected[serial]:failures.append("Missing actual source conifer placements "+str(serial)+": "+str(count))
  rows.append({"graphic":serial,"instances":count,"source_instances":expected[serial],"batches":batches,"source_fit_owner":true,"surfaces":reference.get_surface_count()})
 var path="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/existing-tree-dispatch.json"
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"source_map":43700,"rows":rows,"failures":failures},"  "));f.close()
 print("EAST_EXISTING_TREE_DISPATCH rows=",rows.size()," source_instances=29 failures=",failures.size())
 for failure in failures:push_error(failure)
 model.free();quit(0 if failures.is_empty() else 1)
