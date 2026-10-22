extends SceneTree
var crowd
var checks=0
var failures=0
var output=OS.get_environment("ENEMY_EYES_OUTPUT_DIR")
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func image_():
 for i in 8:await process_frame
 RenderingServer.force_draw()
 return root.get_texture().get_image()
func whites(img:Image,kind:int)->int:
 var count=0
 var begin=int(img.get_width()*(.5+(-4.5+kind*3.0-1.05)/14.0))
 var end=int(img.get_width()*(.5+(-4.5+kind*3.0+1.05)/14.0))
 for x in range(begin,end):
  for y in range(img.get_height()):
   var c=img.get_pixel(x,y)
   if c.r>.85 and c.g>.85 and c.b>.78:count+=1
 return count
func run():
 if DisplayServer.get_name()=="headless":
  printerr("This pixel regression requires a rendering display.");quit(1);return
 if output.is_empty():output=OS.get_user_data_dir()+"/enemy-eyes"
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1200,500)
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("242c36");world.add_child(env)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=14;world.add_child(camera);camera.position=Vector3(0,0,15);camera.look_at(Vector3.ZERO);camera.current=true
 crowd=load("res://scripts/forest/forest_enemy_crowd.gd").new();world.add_child(crowd)
 # Use the enemy steering convention, which differs from the player's +Z.
 var model=load("res://scripts/forest/forest_model.gd").new()
 var waves=load("res://scripts/forest/forest_waves.gd").new(model)
 var steering={"pos":Vector3.ZERO,"facing":0.0,"variant":0}
 waves.turn(steering,Vector3(0,0,15),10.0)
 var facing=Basis(Vector3.UP,steering.facing)
 for kind in range(4):
  for slot in crowd.primitive_batches[kind]:
   if slot.item.group not in ["body","capsule"]:continue
   var mm=slot.batch.multimesh;var size=slot.item.bounds.size
   mm.set_instance_transform(0,Transform3D(facing*Basis.from_scale(Vector3(2/size.x,3/size.y,1/size.z)),Vector3(-4.5+kind*3,0,0)))
   mm.set_instance_color(0,crowd.PROXY_COLORS[kind]);mm.visible_instance_count=1
 var img=await image_();img.save_png(output+"/eyes-front.png")
 for kind in range(4):check(whites(img,kind)>80,"Two visible ivory eyes on enemy role %d"%kind)
 for kind in range(4):
  for slot in crowd.primitive_batches[kind]:
   var mm=slot.batch.multimesh
   if mm.visible_instance_count==0:continue
   var pose=mm.get_instance_transform(0);pose.basis=Basis(Vector3.UP,PI)*pose.basis;mm.set_instance_transform(0,pose)
 img=await image_();img.save_png(output+"/eyes-back.png")
 for kind in range(4):check(whites(img,kind)==0,"No eyes on the back of enemy role %d"%kind)
 world.queue_free();await process_frame
 print("ENEMY_EYES_VISUAL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
