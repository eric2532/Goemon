extends SceneTree
const SHADER=preload("res://assets/materials/crossgate_body.gdshader")
const SHADOW_SHADER=preload("res://assets/materials/crossgate_shadow.gdshader")
const OUT="res://build/Other Files/Asset Toolkit/Shin Skin Fix/"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL "+label_)
func colored(color:Color)->StandardMaterial3D:
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;return material
func capture(label_:String)->int:
 await process_frame;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 image.save_png(OUT+label_+".png")
 var count=0
 for y in image.get_height():
  for x in image.get_width():
   var color=image.get_pixel(x,y)
   if color.r>.7 and color.g<.1 and color.b<.1:count+=1
 return count
func run():
 root.size=Vector2i(320,240);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var scene=Node3D.new();root.add_child(scene);current_scene=scene
 var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,3,6);camera.look_at(Vector3(0,1,0));camera.current=true
 var floor_=MeshInstance3D.new();floor_.mesh=PlaneMesh.new();floor_.mesh.size=Vector2(20,20);floor_.material_override=colored(Color.GREEN);scene.add_child(floor_)
 var image=Image.create(64,128,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);image.fill_rect(Rect2i(0,96,64,32),Color.RED)
 var sprite=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(image);sprite.pixel_size=.03;sprite.offset=Vector2(0,32)
 var material=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter("sprite_texture",sprite.texture);sprite.material_override=material;scene.add_child(sprite)
 sprite.set_instance_shader_parameter("grounded",false)
 var clipped=await capture("ground-probe-unprojected")
 sprite.set_instance_shader_parameter("grounded",true)
 var grounded=await capture("ground-probe-complete")
 check(grounded>clipped+200,"Below-foot effect pixels remain visible on the floor")
 material.shader=SHADOW_SHADER;sprite.modulate.a=.5
 await capture("ground-probe-translucent")
 var translucent=0
 var shadow_image=root.get_texture().get_image()
 for y in shadow_image.get_height():
  for x in shadow_image.get_width():
   var color=shadow_image.get_pixel(x,y)
   if color.r>.2 and color.g>.2 and color.b<.1:translucent+=1
 check(translucent>200,"Counter ground effects preserve half-opacity and reveal the floor behind them")
 material.shader=SHADER;sprite.modulate.a=1
 var wall=MeshInstance3D.new();wall.mesh=BoxMesh.new();wall.mesh.size=Vector3(6,6,.2);wall.position=Vector3(0,3,3);wall.material_override=colored(Color.BLUE);scene.add_child(wall)
 var covered=await capture("ground-probe-covered")
 check(covered==0,"A wall in front still occludes the complete sprite and its ground effect")
 print("CROSSGATE_SPRITE_GROUND_RESULT checks=%d failures=%d clipped=%d grounded=%d covered=%d"%[checks,failures,clipped,grounded,covered])
 scene.queue_free();await process_frame;quit(1 if failures else 0)
