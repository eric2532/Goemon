extends SceneTree
## Offline Image resources keep native terrain independent of GPU texture readback.
const ROOT="res://assets/maps/falan/sokia/"
const AREAS=["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]
func _initialize():
 create_timer(45).timeout.connect(func():printerr("SOKIA_CPU_MASKS_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var folder=ROOT;var checking=false;var source_only=false;var areas=AREAS;var resource_root=ROOT;var suffix="_surface.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--mask-root="):folder=arg.trim_prefix("--mask-root=").trim_suffix("/")+"/"
  elif arg=="--check":checking=true
  elif arg=="--source-only":source_only=true
  elif arg=="--freyja-source":
   areas=["freyja","east_gate","south_gate","west_lakes","north_coast","south_lakes","east_coast"]
   resource_root="res://assets/maps/falan/freyja_residual/full/";suffix="-surface.png"
   if folder==ROOT:folder=resource_root
 var output=folder+"cpu-masks/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var sources=areas.duplicate()
 if resource_root!=ROOT:
  for area in areas:sources.append(area+"-source-support")
  sources.append("source-domain")
 var records={};var checks=0
 for area in sources:
  var filename=area+suffix if area in areas else area+".png"
  var disk=Image.load_from_file(ProjectSettings.globalize_path(folder+filename));disk.convert(Image.FORMAT_RGBA8)
  var image=disk
  if not source_only:
   image=load(resource_root+filename).get_image();image.convert(Image.FORMAT_RGBA8)
   assert(image.get_size()==disk.get_size()and image.get_data()==disk.get_data(),"Refresh imports before validating Sokia CPU masks: "+area)
   checks+=1
  var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data());var sha=digest.finish().hex_encode()
  var path=output+area+".res"
  if checking:
   var saved:Image=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
   assert(saved.get_size()==image.get_size()and saved.get_format()==Image.FORMAT_RGBA8 and saved.get_data()==image.get_data(),"CPU mask differs from original imported pixels: "+area)
   assert(saved.get_meta("rgba_sha256")==sha,"CPU mask source hash differs: "+area)
   checks+=2
  else:
   image.set_meta("rgba_sha256",sha);image.set_meta("source_mask",resource_root+filename)
   var previous:Image=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)if FileAccess.file_exists(path)else null
   if previous==null or previous.get_data()!=image.get_data()or previous.get_meta("rgba_sha256","")!=sha:
    assert(ResourceSaver.save(image,path,ResourceSaver.FLAG_COMPRESS)==OK,"Could not save CPU mask "+area)
  records[area]={"size":[image.get_width(),image.get_height()],"rgba_sha256":sha,"resource_sha256":FileAccess.get_sha256(path)}
 if checking:
  var manifest=JSON.parse_string(FileAccess.get_file_as_string(output+"provenance.json"));var matches=true
  for area in sources:
   matches=matches and manifest[area].rgba_sha256==records[area].rgba_sha256 and manifest[area].resource_sha256==records[area].resource_sha256 and int(manifest[area]["size"][0])==records[area]["size"][0]and int(manifest[area]["size"][1])==records[area]["size"][1]
  if not matches:printerr("SOKIA_CPU_MASKS_FAIL stale manifest");quit(1);return
  checks+=1
 else:
  var file=FileAccess.open(output+"provenance.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  ")+"\n");file.close()
 print("SOKIA_CPU_MASKS ","CHECK"if checking else"PREPARED"," ",checks," checks ",sources.size()," exact Images; source_only=",source_only)
 quit()
