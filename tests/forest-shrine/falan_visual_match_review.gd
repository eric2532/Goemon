extends "res://tests/forest-shrine/falan_proportion_preview.gd"
## Source-camera comparisons are visual evidence, separate from layout assertions.
const REVIEW="res://build/Other Files/Asset Toolkit/Falan City Reconstruction/Visual Continuation/"
var review_view:SubViewport

func _initialize():
 root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true)
 root.grab_focus()
 create_timer(600).timeout.connect(func():printerr("FALAN_VISUAL_REVIEW_TIMEOUT");quit(1))
 super._initialize()

func capture(model:Node3D,key:String,points:Array[Vector3]):
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--only=") and key!=argument.trim_prefix("--only="):
   model.queue_free();await process_frame;return
 var expected:Rect2=Fit.References.RECTS[key]
 var measured=Fit.projected_bounds(points,Transform3D(model.basis,Vector3.ZERO))
 if measured.position.distance_to(expected.position)>.05 or measured.size.distance_to(expected.size)>.05:
  failures+=1;printerr("PROPORTION_FAIL ",key," ",measured," != ",expected)
 if review_view==null:
  # A covered desktop window must not stall source-art capture at frame_post_draw.
  review_view=SubViewport.new();review_view.size=root.size
  review_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  review_view.msaa_3d=root.msaa_3d;review_view.own_world_3d=true;root.add_child(review_view)
  root.remove_child(stage);review_view.add_child(stage)
 var phase="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 var directory=REVIEW+phase+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 var rect:Rect2=Fit.References.RECTS[key]
 var center=rect.get_center()
 var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)
 camera.position=at+Vector3(100,100*sqrt(2.0)*tan(asin(.75)),100);camera.look_at(at)
 for i in 4:await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var image=review_view.get_texture().get_image()
  var crop=Rect2i((Vector2(image.get_size())-rect.size)*.5-Vector2.ONE*8,rect.size+Vector2.ONE*16)
  image.get_region(crop).save_png(directory+key+".png")
 print("FALAN_VISUAL_REVIEW ",phase," ",key)
 if phase=="after" and DisplayServer.get_name()!="headless":
  var bounds=AABB(model.basis*points[0],Vector3.ZERO)
  for p:Vector3 in points:bounds=bounds.expand(model.basis*p)
  var target=bounds.get_center()
  var source_size=camera.size
  camera.size=maxf(bounds.size.x+bounds.size.z,bounds.size.y*1.7)*1.05
  for view in [["side",Vector3(-65,35,65)],["rear",Vector3(-65,35,-65)]]:
   camera.position=target+view[1];camera.look_at(target)
   for i in 4:await process_frame
   await RenderingServer.frame_post_draw
   var full=review_view.get_texture().get_image()
   full.resize(960,600,Image.INTERPOLATE_LANCZOS)
   full.save_png(directory+key+"-"+view[0]+".png")
  camera.size=source_size
 model.queue_free();await process_frame
