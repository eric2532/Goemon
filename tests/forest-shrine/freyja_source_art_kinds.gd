extends SceneTree
## Read-only production dispatch export; no meshes/world/renderer are constructed.
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source art inventory/"
func _initialize():
 create_timer(45).timeout.connect(func():printerr("FREYJA_SOURCE_ART_KIND_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var inputs=JSON.parse_string(FileAccess.get_file_as_string(OUT+"graphics-source.json"))
 Art.load_sokia_server();Art.load_black_prayer()
 var rows={};var count=0
 for serial in inputs.graphics:
  var source:Dictionary=inputs.graphics[serial]
  var found=Art.data().graphics.has(serial)
  var g:Dictionary=Art.data().graphics[serial]if found else source.native_kind_input
  var kind:String=Forms.kind(int(serial),false,g)
  rows[serial]={"kind":kind,"catalog_found":found,"catalog_rgba_matches":found and g.get("rgba_sha256","")==source.rgba_sha256,"catalog_family":g.get("family","")}
  count+=int(source.anchors)
 assert(count==6943 and rows.size()==464)
 var file=FileAccess.open(OUT+"native-kinds.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"source_sha256":inputs.source_sha256,"solids_script_sha256":FileAccess.get_sha256("res://scripts/forest/forest_original_map_solids.gd"),"graphics":rows,"anchors":count,"worlds_constructed":0,"meshes_constructed":0,"limits":"Actual production kind dispatch and catalog binding only; no geometry/appearance or runtime station coverage is certified."},"  ")+"\n");file.close()
 print("FREYJA_SOURCE_ART_KINDS ",rows.size()," graphics / ",count," anchors; worlds=0 meshes=0")
 quit()
