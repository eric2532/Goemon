extends SceneTree
## Compare the actual imported texture against the preserved PNG, including opaque pixels.
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server fixed maps/"
func _initialize():run.call_deferred()
func run():
 var path="res://assets/maps/original_crossgate/atlas-1.png"
 var texture:Texture2D=load(path);var actual:Image=texture.get_image();var source=Image.load_from_file(path)
 if actual.is_compressed():actual.decompress()
 actual.convert(Image.FORMAT_RGBA8);source.convert(Image.FORMAT_RGBA8)
 var mismatch=0;var first=[];var alpha_mismatch=0
 for y in source.get_height():
  for x in source.get_width():
   var a=actual.get_pixel(x,y);var b=source.get_pixel(x,y)
   if not is_equal_approx(a.a,b.a):alpha_mismatch+=1
   if b.a>.99 and a!=b:
    mismatch+=1
    if first.size()<8:first.append({"pixel":[x,y],"actual":str(a),"source":str(b)})
 actual.save_png(OUT+"loaded-base-atlas-1.png")
 var file=FileAccess.open(OUT+"texture-import-comparison.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"path":path,"size":str(actual.get_size()),"source_size":str(source.get_size()),"opaque_pixel_mismatches":mismatch,"alpha_mismatches":alpha_mismatch,"first":first},"  ")+"\n");file.close()
 print("SOKIA_TEXTURE_COMPARE opaque_mismatch=",mismatch," alpha_mismatch=",alpha_mismatch)
 quit(0)
