extends SceneTree
## Native pixels catch shaders discarding parent scale; node transforms alone do not.
var failures=0
var checks=0
var sprite: Sprite3D
var output="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Ben Bomb Audio and Scale"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label)
func image_bounds()->Rect2i:
 await process_frame;await process_frame;RenderingServer.force_draw(false)
 var picture=root.get_texture().get_image()
 var low=Vector2i(picture.get_width(),picture.get_height());var high=Vector2i(-1,-1)
 for y in picture.get_height():
  for x in picture.get_width():
   var color=picture.get_pixel(x,y)
   if maxf(color.r,maxf(color.g,color.b))>.04:
    low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
 return Rect2i(low,high-low+Vector2i.ONE) if high.x>=0 else Rect2i()
func run():
 root.size=Vector2i(512,512)
 var scene=Node3D.new();root.add_child(scene);current_scene=scene
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;scene.add_child(environment)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=24;camera.position=Vector3(0,0,10);scene.add_child(camera);camera.make_current()
 var holder=Node3D.new();scene.add_child(holder)
 sprite=Sprite3D.new();sprite.texture=preload("res://assets/characters/recovered_leaders/ben/bomb_explosion_atlas.png");sprite.hframes=10;sprite.frame=4;sprite.pixel_size=.1;holder.add_child(sprite)
 var material=ShaderMaterial.new();material.set_shader_parameter("albedo_texture",sprite.texture);material.set_shader_parameter("textured",true);material.set_shader_parameter("billboard",true);sprite.material_override=material
 for name_ in ["source_palette","ben/source_explosion"]:
  material.shader=load("res://assets/characters/recovered_leaders/"+name_+".gdshader")
  holder.scale=Vector3.ONE;var normal=await image_bounds()
  holder.scale=Vector3.ONE*2;var enlarged=await image_bounds()
  check(normal.size.x>20 and normal.size.y>20,"Native explosion fixture is visible: "+name_)
  check(enlarged.size.x>=normal.size.x*1.9 and enlarged.size.y>=normal.size.y*1.9,"Billboard pixels honor doubled parent scale: "+name_)
  print("BILLBOARD_BOUNDS ",name_," normal=",normal," doubled=",enlarged)
 print("BEN_BOMB_BILLBOARD_RESULT checks=",checks," failures=",failures)
 scene.queue_free();await process_frame;quit(1 if failures else 0)
