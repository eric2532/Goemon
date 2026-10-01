extends SceneTree
const PACK="res://asset_packs/cedar_pass/"
var lab
func _initialize():call_deferred("run")
func shot(name):
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(PACK+"previews/interiors/"+name+".png")
 print("CAPTURE ",name)
func travel(target):
 for i in range(700):
  var delta=target-lab.player.global_position;delta.y=0
  if delta.length()<.12:break
  var d=delta.normalized().rotated(Vector3.UP,-lab.camera_rig.yaw)
  lab.player.smoke_move=Vector2(d.x,d.z)*minf(1,delta.length()/.8)
  await physics_frame
 lab.player.smoke_move=Vector2.ZERO
 for i in range(12):await physics_frame
func run():
 lab=load(PACK+"interior_lab/lab.gd").new();root.add_child(lab);root.size=Vector2i(1600,1000);lab.player.smoke_mode=true
 if not "--only-inn" in OS.get_cmdline_user_args():
  Input.action_press("walk_modifier")
  lab.visit("machiya_open");lab.camera_rig.distance=11;lab.camera_rig.yaw=.22
  for i in range(20):await physics_frame
  await shot("goemon_01_exterior")
  await travel(Vector3(0,.36,3.4));await shot("goemon_02_threshold")
  await travel(Vector3(0,.36,.4));lab.camera_rig.yaw=.52;await shot("goemon_03_shop_interior")
  await travel(Vector3(0,0,6.3));await shot("goemon_04_exit")
  Input.action_release("walk_modifier")
 if not "--checkpoint" in OS.get_cmdline_user_args():
  for id in lab.rooms:
   if id=="machiya_open":continue
   if "--only-inn" in OS.get_cmdline_user_args() and id!="inn":continue
   var r=lab.rooms[id];lab.player.position=r.root.position+Vector3(0,.42,.5);lab.player.velocity=Vector3.ZERO;lab.camera_rig.yaw=.45;lab.camera_rig.reset_follow()
   for i in range(24):await physics_frame
   await shot("goemon_"+id+"_interior")
   if id=="inn":
    lab.player.position=r.root.position+Vector3(1.9,3.72,-2.5);lab.player.velocity=Vector3.ZERO;lab.camera_rig.reset_follow()
    for i in range(24):await physics_frame
    await shot("goemon_inn_upstairs")
 print("INTERIOR_CAPTURE_COMPLETE")
 quit()
