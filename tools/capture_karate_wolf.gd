extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Both original enemies use the real shared native GPU presentation.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const OUT="res://build/Other Files/Asset Toolkit/Gorilla and Wolf/"
func capture(label_:String):
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Saved "+label_)
func run():
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.explorer_helpers.set_process(false);game.player.set_physics_process(false);game.player.hide();game.training_dummy.hide()
 var runtime=game.army_runtime;var renderer=game.crowd.army
 runtime.clear();renderer.clear();runtime.set_navigation(1200,{"width":0})
 var point=ORIGIN+Vector3(-2,0,-4)
 var handle:int=runtime.spawn(1,0,Roles.HAYA_WOLF,point,640,Roles.footprint_radius(Roles.HAYA_WOLF));runtime.set_pose(handle,point,PI)
 point=ORIGIN+Vector3(2,0,-4)
 handle=runtime.spawn(2,0,Roles.SLOW_GUY,point,640,Roles.footprint_radius(Roles.SLOW_GUY));runtime.set_pose(handle,point,PI)
 for i in 2:
  var label_=Label3D.new();label_.text=["Haya Wolf","Slow Guy · Gorilla"][i];label_.font_size=48;label_.pixel_size=.006;label_.billboard=BaseMaterial3D.BILLBOARD_ENABLED;game.add_child(label_);label_.position=ORIGIN+Vector3(-2 if i==0 else 2,4,-4)
 game.camera_rig.camera.global_position=ORIGIN+Vector3(4,4,8);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1.7,-4));game.camera_rig.camera.fov=42
 var snapshot:Dictionary=runtime.render_snapshot();renderer.present(snapshot,[]);await capture("wolf_and_gorilla")
 check(snapshot.kinds.size()==2 and snapshot.kinds.has(Roles.HAYA_WOLF) and snapshot.kinds.has(Roles.SLOW_GUY),"Both enemies own independent native slots")
 for tick in [15,20,30]:
  for index in snapshot.kinds.size():
   var resource:Resource=Visual.data(snapshot.kinds[index]);var clips:Dictionary=resource.get_meta("clips");var clip:String=resource.get_meta("semantics").attack[0]
   snapshot.pose_rows[index]=clips[clip].rows[tick]
  renderer.present(snapshot,[]);await capture("original_attacks_%d"%tick)
 game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();game=null;current_scene=null;await frames(3);quit(1 if failures else 0)
