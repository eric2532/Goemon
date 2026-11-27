extends SceneTree
## Offline lossless CPU image for the inferred surface; runtime never reads PNG files.
const ROOT="res://assets/maps/falan/east_region/carved_pier_study/"
const NAME="inferred-masonry-albedo-v1"
func _initialize():
 var source=ROOT+NAME+".png";var output=ROOT+NAME+".res"
 var image=Image.load_from_file(ProjectSettings.globalize_path(source));image.convert(Image.FORMAT_RGBA8)
 assert(image.get_size()==Vector2i(1254,1254),"Unexpected generated material dimensions")
 var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data());var rgba=digest.finish().hex_encode()
 image.set_meta("source_png_sha256",FileAccess.get_sha256(source));image.set_meta("rgba_sha256",rgba)
 if not "--check"in OS.get_cmdline_user_args():
  assert(ResourceSaver.save(image,output,ResourceSaver.FLAG_COMPRESS)==OK,"Could not prepare inferred CPU image")
 var saved:Image=ResourceLoader.load(output,"",ResourceLoader.CACHE_MODE_IGNORE)
 assert(saved!=null and saved.get_data()==image.get_data() and saved.get_format()==Image.FORMAT_RGBA8,"CPU resource differs from original generated pixels")
 assert(saved.get_meta("source_png_sha256")==FileAccess.get_sha256(source) and saved.get_meta("rgba_sha256")==rgba,"Stale inferred-image provenance")
 var record={"source":source,"source_sha256":FileAccess.get_sha256(source),"resource":output,"resource_sha256":FileAccess.get_sha256(output),"rgba_sha256":rgba,"size":[1254,1254],"inferred_not_recovered":true}
 var report=ROOT+"cpu-provenance.json"
 if "--check"in OS.get_cmdline_user_args():assert(JSON.parse_string(FileAccess.get_file_as_string(report))==record,"Stale inferred CPU resource record")
 else:
  var file=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(record,"  ")+"\n");file.close()
 print("EAST_CARVED_MASONRY_CPU ","CHECK"if "--check"in OS.get_cmdline_user_args()else"PREPARED"," exact1254x1254RGBA")
 quit()
