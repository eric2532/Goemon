extends SceneTree
## Current immutable setup inputs only; no world, renderer or navigation owner.
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Reference/"
func _initialize():
 create_timer(120,true,false,true).timeout.connect(func():printerr("HOST100_REFERENCE_TIMEOUT");quit(2));run.call_deferred()
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_east_road.gd","scripts/forest/forest_freyja_regions.gd","assets/maps/falan/freyja_residual/data.gd","assets/maps/falan/freyja_residual/full/data.gd","assets/maps/falan/freyja_residual/full/cpu-masks/east_gate.res","assets/maps/falan/freyja_residual/full/cpu-masks/north_coast.res"]
 var before=Fresh.snapshot(paths);var records={}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for area:String in ["east_gate","north_coast"]:
  var terrain=Terrain.new();terrain.variant=area;terrain.horizontal_scale=2.;terrain.expansion=terrain.Regions.layout(area).get("map_expansion",1.);terrain.configure([])
  var field=terrain.terrain_field();var image=terrain.mask_image();var origin=terrain.mask_origin();var bounds=terrain.mask_bounds()
  assert(image!=null and image.get_format()==Image.FORMAT_RGBA8)
  assert(image.save_png(OUT+area+"-mask.png")==OK)
  var row={"area":area,"width":terrain.width,"spacing":terrain.spacing,"origin":[origin.x,origin.y],"mask_size":[image.get_width(),image.get_height()],"mask_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"heights":field.get_meta("heights"),"bed":field.get_meta("bed",field.get_meta("heights")),"covered":field.get_meta("covered"),"bridges":field.get_meta("bridges"),"pieces":terrain.pieces}
  var file=FileAccess.open(OUT+area+"-field.json",FileAccess.WRITE);file.store_string(JSON.stringify(row,"",true,true));file.close()
  records[area]={"width":terrain.width,"spacing":terrain.spacing,"field_path":OUT+area+"-field.json","field_sha256":FileAccess.get_sha256(OUT+area+"-field.json"),"mask_sha256":FileAccess.get_sha256(OUT+area+"-mask.png"),"height_samples":terrain.heights.size(),"mask_size":row.mask_size}
 var changed=Fresh.changed(before)
 var file=FileAccess.open(OUT+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source_hashes":before,"source_changed":changed,"areas":records,"scope":"Current canonical terrain CPU setup fields/masks only. No default/native/frame/mesh mutation; privateHost100 derivative must preserve unmodified regions against these pinned inputs."},"  "));file.close()
 print("HOST100_REFERENCE_INPUTS areas=",records.size()," source_changed=",changed);quit(0 if changed.is_empty() else 1)
