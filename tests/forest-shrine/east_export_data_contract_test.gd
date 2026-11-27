extends SceneTree
## Static delivery contract only; this does not export an app or resource pack.
const ROOTS=["assets/maps/original_crossgate/east/","assets/maps/falan/east_region/","assets/maps/falan/east_field_cliffs/","assets/maps/falan/east_village_props/","assets/characters/crossgate/east_region/"]
var checks=0
var failures=0
var files=[]
func _initialize():
 var config=ConfigFile.new();assert(config.load("res://export_presets.cfg")==OK)
 assert(config.get_value("preset.4","name")=="Painterly Preview macOS")
 var filters:String=config.get_value("preset.4","include_filter")
 for path in ROOTS:scan(path,filters.split(","))
 for name in["mask.png","ground-index.png","ground-atlas.png","props/native.png"]:
  var path="assets/maps/falan/east_region/alyut_source_completion/"+name
  var matched=path in filters.split(",");checks+=1
  if not matched:failures+=1;printerr("FAIL exact FullAlyut CPUimage filter omitted: ",path)
  files.append({"path":path,"included":matched,"canonical_exists":FileAccess.file_exists("res://"+path)})
  if FileAccess.file_exists("res://"+path):
   var sidecar=ConfigFile.new();var loaded=sidecar.load("res://"+path+".import")==OK
   var kept=loaded and sidecar.get_value("remap","importer","")=="keep";checks+=1
   if not kept:failures+=1;printerr("FAIL CPUimage must retain raw bytes through Keep File: ",path)
   files.append({"raw_png_importer_keep":kept,"path":path,"sidecar_sha256":FileAccess.get_sha256("res://"+path+".import")})
 var output="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/export-data-contract.json"
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"files":files,"preset_sha256":FileAccess.get_sha256("res://export_presets.cfg"),"scope":"Static Godot filter matching of East rawJSON/BIN; no app/PCK export or packaged runtime claim."},"  "));file.close()
 print("EAST_EXPORT_DATA_RESULT checks=",checks," failures=",failures);quit(failures)
func scan(folder:String,filters:PackedStringArray):
 for name in DirAccess.get_files_at("res://"+folder):
  if name.get_extension() not in["json","bin"]:continue
  var path=folder+name;var matched=false
  for filter:String in filters:matched=matched or path.match(filter)
  checks+=1
  if not matched:failures+=1;printerr("FAIL raw runtime data omitted: ",path)
  files.append({"path":path,"included":matched})
 for sub in DirAccess.get_directories_at("res://"+folder):scan(folder+sub+"/",filters)
