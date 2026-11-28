extends SceneTree
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const OUT="res://build/Other Files/Asset Toolkit/Explore Access/"
func _initialize():
 create_timer(120.).timeout.connect(func():printerr("EXPLORE_GRAPHICS_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 var reference=JSON.parse_string(FileAccess.get_file_as_string(OUT+"required-recovered-graphics.json"))
 for path in reference.source_catalog_sha256:
  if FileAccess.get_sha256("res://"+path)!=reference.source_catalog_sha256[path]:
   printerr("EXPLORE_GRAPHICS_STALE_REFERENCE ",path);quit(1);return
 Art.load_explore_recovered()
 var data=Art.data();var missing=[];var bad_pages=[];var pages={}
 for serial in reference.required:
  if not data.graphics.has(serial):missing.append(serial);continue
  var page=int(data.graphics[serial].page)
  if page<0 or page>=data.pages.size():bad_pages.append(serial);continue
  pages[page]=true
 for page in pages:
  if not FileAccess.file_exists(Art.ROOT+data.pages[page]):bad_pages.append(data.pages[page])
 var report={"qualification":"Actual loader metadata/page dependency check, not player-route verification.","required_graphics":reference.required.size(),"checked_pages":pages.size(),"missing":missing,"bad_pages":bad_pages}
 var file=FileAccess.open(OUT+"runtime-graphic-dependencies.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EXPLORE_GRAPHICS_RESULT required=",reference.required.size()," pages=",pages.size()," missing=",missing.size()," bad_pages=",bad_pages.size())
 quit(0 if missing.is_empty()and bad_pages.is_empty()else 1)
