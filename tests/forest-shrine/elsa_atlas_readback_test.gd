extends SceneTree
## Compare imported texture pixels with the authorized PNG derivative, without a map scene.
func _initialize():run.call_deferred()
func run():
 var path="res://assets/maps/original_crossgate/elsa/atlas-40.png"
 var native=Image.load_from_file(path);var texture:Texture2D=load(path);var actual=texture.get_image()
 var failures=0;var checks=0;var examples=[]
 var retained=[]
 # The scene probe caches several readback images. Check that later reads do
 # not alter an image already returned by the renderer.
 for other_path in ["res://assets/maps/original_crossgate/elsa/atlas-41.png","res://assets/maps/original_crossgate/elsa/atlas-42.png","res://assets/maps/falan/elsa/props/solid-12.png"]:
  var other:Texture2D=load(other_path);retained.append(other);retained.append(other.get_image())
 for pixel in [Vector2i(153,1746),Vector2i(1925,1688),Vector2i(305,1744)]:
  var expected=native.get_pixelv(pixel);var received=actual.get_pixelv(pixel)
  print("ELSA_ATLAS_PIXEL ",pixel," expected=",expected.to_html()," actual=",received.to_html())
  checks+=1
  if expected!=received:failures+=1
 for y in range(0,native.get_height(),16):
  for x in range(0,native.get_width(),16):
   var expected=native.get_pixel(x,y);var received=actual.get_pixel(x,y)
   if expected.a==0. and received.a==0.:continue # Godot extends hidden border RGB.
   checks+=1
   if expected!=received:
    failures+=1
    if examples.size()<8:examples.append({"pixel":[x,y],"expected":expected.to_html(),"actual":received.to_html()})
 print("ELSA_ATLAS_READBACK checks=",checks," failures=",failures," display=",DisplayServer.get_name()," examples=",examples)
 quit(1 if failures else 0)
