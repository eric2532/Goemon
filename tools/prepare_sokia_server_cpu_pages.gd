extends SceneTree
## Offline exact Images avoid the observed Metal imported-page upload corruption.
const ROOT="res://assets/maps/original_crossgate/"
const OUTPUT=ROOT+"sokia_server/cpu-pages/"
const PAGES=["atlas-1.png","university/atlas-0.png"]
const SOKIA_FIXED_PAGE="../falan/sokia/fixed/atlas-0.png"
func _initialize():
 create_timer(45).timeout.connect(func():printerr("SOKIA_SERVER_CPU_PAGES_TIMEOUT");quit(1))
 run.call_deferred()
func digest(bytes_:PackedByteArray)->String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes_)
 return context.finish().hex_encode()
func run():
 var checking="--check"in OS.get_cmdline_user_args();var records={}
 var output=OUTPUT;var pages=PAGES;var custom_pages=false;var custom_output=false
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--pages="):pages=argument.trim_prefix("--pages=").split(",");custom_pages=true
  if argument.begins_with("--output="):output=ROOT+argument.trim_prefix("--output=").trim_suffix("/")+"/";custom_output=true
 assert(custom_pages==custom_output,"Choose custom pages and output together; preserve the default regional inventory")
 assert(not pages.is_empty() and output.begins_with(ROOT) and not output.contains(".."),"CPU page output must stay under the original-map asset root")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 for page in pages:
  assert(page==SOKIA_FIXED_PAGE or not page.begins_with("/")and not page.contains("..")and page.ends_with(".png"),"CPU page input must be an original-map PNG or the exact Sokia fixed page")
  var source=ROOT+page;var image=Image.load_from_file(ProjectSettings.globalize_path(source));image.convert(Image.FORMAT_RGBA8)
  assert(image.get_size()==Vector2i(2048,2048),"Unexpected source-page dimensions: "+page)
  var rgba=digest(image.get_data());var source_sha=FileAccess.get_sha256(source)
  var resource=page.trim_prefix("../").replace("/","-").trim_suffix(".png")+".res";var path=output+resource
  if not checking:
   image.set_meta("source_page",source);image.set_meta("source_sha256",source_sha);image.set_meta("rgba_sha256",rgba)
   var previous:Image=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)if FileAccess.file_exists(path)else null
   if previous==null or previous.get_data()!=image.get_data()or previous.get_meta("source_sha256","")!=source_sha:
    assert(ResourceSaver.save(image,path,ResourceSaver.FLAG_COMPRESS)==OK,"Could not prepare original page "+page)
  var saved:Image=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
  assert(saved.get_format()==Image.FORMAT_RGBA8 and saved.get_size()==image.get_size()and saved.get_data()==image.get_data(),"Prepared CPU page differs from original RGBA: "+page)
  assert(saved.get_meta("source_page")==source and saved.get_meta("source_sha256")==source_sha and saved.get_meta("rgba_sha256")==rgba,"Stale CPU page identity: "+page)
  records[page]={"resource":output.trim_prefix(ROOT)+resource,"source_sha256":source_sha,"rgba_sha256":rgba,"resource_sha256":FileAccess.get_sha256(path),"size":[2048,2048]}
 if checking:
  var previous=JSON.parse_string(FileAccess.get_file_as_string(output+"provenance.json"))
  assert(previous is Dictionary and previous.size()==records.size(),"Stale CPU page inventory")
  for page in records:
   assert(previous.has(page)and int(previous[page]["size"][0])==2048 and int(previous[page]["size"][1])==2048,"Stale CPU page dimensions")
   for key in ["resource","source_sha256","rgba_sha256","resource_sha256"]:
    assert(previous[page][key]==records[page][key],"Stale CPU page provenance: "+page+" "+key)
 else:
  var file=FileAccess.open(output+"provenance.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  ")+"\n");file.close()
 print("SOKIA_SERVER_CPU_PAGES "if output==OUTPUT else"ORIGINAL_CPU_PAGES ","CHECK"if checking else"PREPARED"," ",records.size()," exact original pages")
 quit()
