extends "res://tests/forest-shrine/sokia_crown_shapes_test.gd"
const FROND_REVIEW="res://build/Other Files/Asset Toolkit/Sokia Native Fronds/"
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true;game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 var folder=FROND_REVIEW+("before/" if "--frond-before" in OS.get_cmdline_user_args() else "after/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 check(root.get_texture().get_image().save_png(folder+label_+".png")==OK,"Captured "+label_)
 game.set_process(true);game.ui.show();paused=before
func check_east_il_road():
 await super.check_east_il_road()
 if not "--frond-before" in OS.get_cmdline_user_args():
  var crown=Sokia.Details.crown_point(11204)
  check(crown.distance_to(Vector3(0,5.983,0))<.001,"Fruit-palm crown follows its recorded source origin and attachment pixel")
  check(Sokia.Details.Data.PALM_FRONDS[11204].size()==9,"The source palm retains its nine traced crown ribs")
  var up=false;var down=false
  for curve in Sokia.Details.Data.PALM_FRONDS[11204]:
   check(Sokia.Details.source_frond_point(curve,0.0,crown).distance_to(crown)<.001,"Every traced frond meets the same solid trunk crown")
   for point:Vector4 in curve:
    up=up or point.y>1.5;down=down or point.y< -1.5
  check(up and down,"Native upright and hanging leaves replace the uniformly drooping crown")
  var bounds=Sokia.Details.palm(11204).get_aabb()
  check(bounds.end.y>7.8 and bounds.end.y<8.6 and bounds.size.z>1.0,"Source palm height and solid crown depth match its calibrated art scale")
 print("SOKIA_NATIVE_FRONDS_RESULT checks=",checks," failures=",errors)
func open_area(area:String):
 await super.open_area(area)
 if area=="kili" and not "--frond-before" in OS.get_cmdline_user_args():
  var count_=0
  for batch in game.world.find_children("SokiaNativeProp_*","MultiMeshInstance3D",true,false):
   count_+=batch.multimesh.instance_count
   check(batch.material_override==Sokia.material,"Kili low plants reuse the original-art atlas and existing batches")
  check(count_==84,"All 84 recorded Kili low plants replace generic shrub and ivory-flower dressing")
