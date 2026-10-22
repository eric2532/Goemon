extends SceneTree
var failures=0
var comparisons=0
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Large Army Rebuild/Execution/Bottleneck Isolation"
func _initialize():run.call_deferred()
func capture()->Image:
 await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 if RenderingServer.get_rendering_device()==null:printerr("FAIL: Native rendering required");quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 root.size=Vector2i(640,480);root.use_taa=false;root.msaa_3d=Viewport.MSAA_DISABLED;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=1;root.add_child(environment)
 var owner=Node3D.new();root.add_child(owner)
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer);renderer.configure(owner);renderer.hide()
 var camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=63
 var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.instance_count=1;node.multimesh.set_instance_transform(0,Transform3D.IDENTITY);node.multimesh.custom_aabb=AABB(Vector3(-12,-4,-12),Vector3(24,24,24));root.add_child(node)
 for kind in [11,5,7,8,10]:
  var resource:Resource=renderer.resources[kind];var original:ArrayMesh=renderer.full_detail_meshes[kind];var detail:ArrayMesh=renderer.distance_meshes[kind];var clips:Dictionary=resource.get_meta("clips")
  for pose in ["idle","primary0","walk"]:
   var clip:Dictionary=clips[pose];var motion:Dictionary=clips["walk"]
   node.multimesh.set_instance_custom_data(0,Color(clip.start+minf(12.37,clip.count-1),motion.start+minf(18.29,motion.count-1),.5,0))
   for distance in [18.0,65.0,140.0]:
    camera.position=Vector3(distance*.35,distance*.24,distance);camera.look_at(Vector3(0,1.4,0))
    node.multimesh.mesh=original;var a:Image=await capture()
    node.multimesh.mesh=detail;var b:Image=await capture()
    var pixels=0;var escaped=0;var overlap=0;var colors=0.0
    for y in range(140,340):
     for x in range(220,420):
      var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y);var am=ca.r+ca.g+ca.b>.06;var bm=cb.r+cb.g+cb.b>.06
      if am or bm:pixels+=1
      if am and bm:overlap+=1;colors+=(Vector3(ca.r,ca.g,ca.b)-Vector3(cb.r,cb.g,cb.b)).length()
      if am==bm:continue
      var reference=b if am else a;var close=false
      for dy in range(-1,2):
       for dx in range(-1,2):
        var c=reference.get_pixel(x+dx,y+dy)
        if c.r+c.g+c.b>.06:close=true
      if not close:escaped+=1
    comparisons+=1;var error=colors/maxi(1,overlap)
    if pixels<4 or escaped>0 or error>.06:failures+=1
    print("ARMY_LOD_VISUAL kind=",kind," pose=",pose," distance=",distance," pixels=",pixels," outside_one_pixel=",escaped," color_error=",error)
    if kind==5 and pose=="primary0" and distance==65:
     var sheet=Image.create(400,200,false,Image.FORMAT_RGB8);sheet.blit_rect(a,Rect2i(220,140,200,200),Vector2i.ZERO);sheet.blit_rect(b,Rect2i(220,140,200,200),Vector2i(200,0));sheet.resize(1200,600,Image.INTERPOLATE_NEAREST);sheet.save_png(OUT+"/lod-far-comparison.png")
 renderer.free();node.free();camera.free();owner.free();environment.free()
 print("ARMY_LOD_VISUAL_RESULT comparisons=",comparisons," failures=",failures);quit(1 if failures else 0)
