extends SceneTree
## Checks delivery metadata without exporting an app or resource pack.
const Full=preload("res://scripts/forest/forest_east_alyut_source_completion.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Canonical Stage/"
var checks=0
var failures=[]
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func _initialize():
 var preset=ConfigFile.new();assert(preset.load("res://export_presets.cfg")==OK)
 assert(preset.get_value("preset.4","name")=="Painterly Preview macOS")
 var filters:String=preset.get_value("preset.4","include_filter")
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"publication.json"));var records=[]
 check(not FileAccess.file_exists(Full.ROOT+"map-data.json"),"Canonical Alyut remains inactive")
 for name_ in ["mask.png","ground-index.png","ground-atlas.png","props/native.png"]:
  var canonical=Full.ROOT.trim_prefix("res://")+name_;var staged=FOLDER+name_;var config=ConfigFile.new()
  check(canonical in filters.split(","),"Exact original CPUimage is selected for future export: "+name_)
  check(config.load(staged+".import")==OK and config.get_value("remap","importer","")=="keep","Keep File preserves PNG bytes instead of texture remapping: "+name_)
  check(config.get_section_keys("remap").size()==1,"CPUimage has no imported Texture2D dependency/remap: "+name_)
  var image=Image.load_from_file(staged)
  check(image!=null and not image.is_empty(),"Prepared raw CPUimage decodes: "+name_)
  check(manifest.runtime_files[name_]==FileAccess.get_sha256(staged) and manifest.runtime_files[name_+".import"]==FileAccess.get_sha256(staged+".import"),"Reviewed stage manifest pins PNG and Keep sidecar: "+name_)
  records.append({"canonical":canonical,"canonical_exists":FileAccess.file_exists("res://"+canonical),"staged_sha256":FileAccess.get_sha256(staged),"sidecar_sha256":FileAccess.get_sha256(staged+".import"),"size":[image.get_width(),image.get_height()],"importer":"keep"})
 var file=FileAccess.open(FOLDER+"raw-image-delivery-contract.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"files":records,"preset_sha256":FileAccess.get_sha256("res://export_presets.cfg"),"manifest_sha256":FileAccess.get_sha256(FOLDER+"publication.json"),"primary_sources":["https://github.com/godotengine/godot/blob/4.6.1-stable/editor/export/editor_export_platform.cpp#L1331-L1340","https://github.com/godotengine/godot/blob/4.6.1-stable/editor/file_system/editor_file_system.cpp#L610-L612"],"scope":"Static ConfigFile/filter/manifest and original PNG decode checks. Keep File is supported by pinned Godot exporter source. No app/PCK export or packaged runtime claim."}," "));file.close()
 print("EAST_ALYUT_EXPORT_CONTRACTS checks=",checks," failures=",failures.size());quit(failures.size())
