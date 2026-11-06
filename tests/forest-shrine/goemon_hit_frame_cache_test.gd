extends SceneTree
const FX=preload("res://scripts/recovered_goemon_vfx.gd")
class ReferenceFX extends "res://scripts/recovered_goemon_vfx.gd":
 func _process(delta:float):
  age+=delta
  if age>=lifetime:queue_free();return
  var frame=mini(3,int(age/lifetime*4))
  burst.texture=load(ROOT+"burst_%d.png"%frame);stars.texture=load(ROOT+"stars_%d.png"%frame)
  burst.scale=Vector3.ONE*lerpf(.7,1.55,age/lifetime)
  stars.scale=Vector3.ONE*lerpf(.8,1.7,age/lifetime)
  var alpha=1-smoothstep(.45,1,age/lifetime)
  burst.modulate.a=alpha;stars.modulate.a=alpha
class Owner extends Node3D:
 var settings={"reduced_flashes":false}
var checks=0
var failures=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func _initialize():run.call_deferred()
func run():
 var owner=Owner.new();root.add_child(owner)
 var shot=FX.hit(owner,Vector3.ZERO)
 shot.set_process(false);shot._process(.01);shot.free()
 for kind in ["burst","stars"]:
  for frame in 4:check(ResourceLoader.has_cached(FX.ROOT+"%s_%d.png"%[kind,frame]),"All original hit pages remain prepared between impacts")
 for heavy in [false,true]:
  for reduced in [false,true]:
   owner.settings.reduced_flashes=reduced
   var effect=FX.hit(owner,Vector3.ZERO,heavy);effect.set_process(false)
   for frame in 4:
    effect.age=effect.lifetime*(frame+.25)/4.0;effect._process(0)
    check(effect.burst.texture.resource_path==FX.ROOT+"burst_%d.png"%frame and effect.stars.texture.resource_path==FX.ROOT+"stars_%d.png"%frame,"Original sprite pages and frame timing stay exact")
    check(is_equal_approx(effect.burst.pixel_size,(.026 if heavy else .021)) and is_equal_approx(effect.stars.pixel_size,(.035 if heavy else .027)),"Original heavy/light sprite size stays exact")
    check(effect.scale==Vector3.ONE*(1 if reduced else 2),"Reduced flashes preserve original effect scaling")
    var t=effect.age/effect.lifetime
    check(effect.burst.scale==Vector3.ONE*lerpf(.7,1.55,t) and effect.stars.scale==Vector3.ONE*lerpf(.8,1.7,t),"Original continuous expansion stays exact")
    check(is_equal_approx(effect.burst.modulate.a,1-smoothstep(.45,1,t)),"Original continuous fade stays exact")
   effect.age=effect.lifetime;effect._process(0);check(effect.is_queued_for_deletion(),"Original effect lifetime stays exact")
   await process_frame
 if DisplayServer.get_name()!="headless":await compare_render(owner)
 owner.free()
 print("GOEMON_HIT_FRAME_CACHE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

func compare_render(owner):
 root.size=Vector2i(480,360)
 var camera=Camera3D.new();owner.add_child(camera);camera.position=Vector3(2,2,6);camera.look_at(Vector3.ZERO);camera.current=true
 var output="res://build/Other Files/Asset Toolkit/24 Hero Smoothness/Rendered Hit Frames/"
 DirAccess.make_dir_recursive_absolute(output)
 for heavy in [false,true]:
  for reduced in [false,true]:
   owner.settings.reduced_flashes=reduced
   var current=FX.hit(owner,Vector3.ZERO,heavy);current.set_process(false)
   var reference=ReferenceFX.new();owner.add_child(reference);reference.set_process(false)
   reference.scale=Vector3.ONE*(1 if reduced else 2);reference.lifetime=.32 if heavy else .24
   reference.burst=reference._sprite(load(FX.ROOT+"burst_0.png"),.026 if heavy else .021)
   reference.stars=reference._sprite(load(FX.ROOT+"stars_0.png"),.035 if heavy else .027)
   reference.stars.rotation.z=.35 if heavy else -.18
   for frame in 4:
    current.age=current.lifetime*(frame+.5)/4;reference.age=current.age
    current._process(0);reference._process(0)
    current.hide();reference.show()
    for i in 15:await process_frame
    await RenderingServer.frame_post_draw
    var before=root.get_texture().get_image();before.convert(Image.FORMAT_RGBA8)
    reference.hide();current.show()
    for i in 15:await process_frame
    await RenderingServer.frame_post_draw
    var after=root.get_texture().get_image();after.convert(Image.FORMAT_RGBA8)
    var label="%s-%s-%d"%["heavy" if heavy else "light","reduced" if reduced else "full",frame]
    before.save_png(output+label+"-original.png");after.save_png(output+label+"-cached.png")
    check(before.get_data()==after.get_data(),"Prepared hit texture renders pixel-identically: "+label)
    var background=before.get_pixel(0,0);var drawn=false
    for y in before.get_height():
     for x in before.get_width():
      if before.get_pixel(x,y)!=background:drawn=true;break
     if drawn:break
    check(drawn,"Comparison contains visible original hit pixels: "+label)
   current.free();reference.free()
